#!/usr/bin/env bash
# Tests for pr-gate.sh
# Covers: opt-in default (no preset), preset-driven requirements (task / bugfix /
# quick / spec), config override, docs-only bypass, stale evidence.
#
# Usage: bash ~/.claude/hooks/tests/test-pr-gate.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SCRIPT_DIR/../pr-gate.sh"
source "$SCRIPT_DIR/../lib/evidence.sh"

# Ensure the gate uses THIS worktree's party-cli source via go run, not any
# pre-installed (possibly stale) binary on PATH. Prepending a dummy dir that
# does not contain `party-cli` would still fall through to the original PATH;
# instead, shadow it with a stub that always fails so party_cli_query falls
# back to go run from the repo.
_PARTY_STUB_DIR=$(mktemp -d)
cat > "$_PARTY_STUB_DIR/party-cli" <<'STUB'
#!/usr/bin/env bash
exit 1
STUB
chmod +x "$_PARTY_STUB_DIR/party-cli"
export PATH="$_PARTY_STUB_DIR:$PATH"
_stub_cleanup() { rm -rf "$_PARTY_STUB_DIR"; }

PASS=0
FAIL=0
SESSION_ID="test-pr-gate-$$"
TMPDIR_BASE=""

assert() {
  local desc="$1"
  if eval "$2"; then
    PASS=$((PASS + 1))
    echo "  [PASS] $desc"
  else
    FAIL=$((FAIL + 1))
    echo "  [FAIL] $desc"
  fi
}

setup_repo() {
  TMPDIR_BASE=$(mktemp -d)
  export XDG_CONFIG_HOME="$TMPDIR_BASE/.config"
  cd "$TMPDIR_BASE"
  git init -q
  git checkout -q -b main
  echo "#!/bin/bash" > file.sh
  git add file.sh
  git commit -q -m "initial commit"
  git checkout -q -b feature
}

config_path() {
  printf '%s\n' "$XDG_CONFIG_HOME/party-cli/config.toml"
}

clean_evidence() {
  rm -f "$(evidence_file "$SESSION_ID")"
  rm -f "/tmp/claude-evidence-${SESSION_ID}.lock"
  rmdir "/tmp/claude-evidence-${SESSION_ID}.lock.d" 2>/dev/null || true
  rm -f "$(config_path)" 2>/dev/null || true
}

full_cleanup() {
  clean_evidence
  _stub_cleanup
  unset XDG_CONFIG_HOME
  if [ -n "$TMPDIR_BASE" ] && [ -d "$TMPDIR_BASE" ]; then
    rm -rf "$TMPDIR_BASE"
  fi
}
trap full_cleanup EXIT

gate_input() {
  jq -cn \
    --arg sid "$SESSION_ID" \
    --arg cwd "$TMPDIR_BASE" \
    '{tool_input:{command:"gh pr create --title test"},session_id:$sid,cwd:$cwd}'
}

set_preset() {
  append_evidence "$SESSION_ID" "execution-preset" "$1" "$TMPDIR_BASE"
}

# party-cli's default config resolves companion-name to "codex", so the task
# and bugfix presets require a `codex` evidence entry unless the test
# overrides the config to remove the companion role. Helpers include codex
# for convenience; the "with configured companion" tests below exercise the
# resolution path explicitly via `write_companion_config`.
add_all_evidence_for_task() {
  for type in pr-verified code-critic minimizer requirements-auditor codex test-runner check-runner; do
    append_evidence "$SESSION_ID" "$type" "PASS" "$TMPDIR_BASE"
  done
}

add_all_evidence_for_bugfix() {
  for type in pr-verified code-critic minimizer codex test-runner check-runner; do
    append_evidence "$SESSION_ID" "$type" "PASS" "$TMPDIR_BASE"
  done
}

add_all_evidence_for_quick() {
  for type in pr-verified code-critic test-runner check-runner; do
    append_evidence "$SESSION_ID" "$type" "PASS" "$TMPDIR_BASE"
  done
}

add_companion_evidence() {
  append_evidence "$SESSION_ID" "$1" "APPROVED" "$TMPDIR_BASE"
}

write_custom_evidence_config() {
  mkdir -p "$(dirname "$(config_path)")"
  cat > "$(config_path)" <<'EOF'
[evidence]
required = ["pr-verified", "test-runner", "check-runner"]
EOF
}

write_companion_config() {
  mkdir -p "$(dirname "$(config_path)")"
  cat > "$(config_path)" <<'EOF'
[roles.primary]
agent = "claude"
[roles.companion]
agent = "codex"
EOF
}

echo "--- test-pr-gate.sh ---"

# ═══ Docs-only bypass ═══════════════════════════════════════════════════════

echo "=== Docs-only bypass ==="
setup_repo
clean_evidence
echo "docs" > readme.md
git add readme.md && git commit -q -m "add docs"
OUTPUT=$(echo "$(gate_input)" | bash "$GATE")
assert "Docs-only PR allowed without evidence" \
  '! echo "$OUTPUT" | grep -q "deny"'

echo "=== Docs-only bypass: .md + .svg files ==="
setup_repo
clean_evidence
echo "docs" > readme.md
echo '<svg></svg>' > diagram.svg
git add readme.md diagram.svg && git commit -q -m "add docs with svg"
OUTPUT=$(echo "$(gate_input)" | bash "$GATE")
assert "Docs PR with .svg allowed without evidence" \
  '! echo "$OUTPUT" | grep -q "deny"'

echo "=== Docs-only bypass: .sh file still requires evidence when preset set ==="
setup_repo
clean_evidence
echo "docs" > readme.md
echo "#!/bin/bash" > script.sh
git add readme.md script.sh && git commit -q -m "add docs and script"
set_preset task
OUTPUT=$(echo "$(gate_input)" | bash "$GATE")
assert "PR with .sh file + preset requires evidence" \
  'echo "$OUTPUT" | grep -q "deny"'

echo "=== Docs-only bypass: Dockerfile requires evidence when preset set ==="
setup_repo
clean_evidence
echo "FROM alpine" > Dockerfile
git add Dockerfile && git commit -q -m "add Dockerfile"
set_preset task
OUTPUT=$(echo "$(gate_input)" | bash "$GATE")
assert "PR with Dockerfile + preset requires evidence" \
  'echo "$OUTPUT" | grep -q "deny"'

# ═══ Opt-in default: no preset → allow ════════════════════════════════════

echo "=== Opt-in default: code PR with no preset is allowed ==="
setup_repo
clean_evidence
echo "change" >> file.sh
git add file.sh && git commit -q -m "code change"
OUTPUT=$(echo "$(gate_input)" | bash "$GATE")
assert "No preset evidence → code PR allowed" \
  '! echo "$OUTPUT" | grep -q "deny"'

# ═══ task preset ══════════════════════════════════════════════════════════

echo "=== task preset: blocks when evidence missing ==="
setup_repo
clean_evidence
echo "change" >> file.sh
git add file.sh && git commit -q -m "code change"
set_preset task
OUTPUT=$(echo "$(gate_input)" | bash "$GATE")
assert "task preset + no evidence → blocked" \
  'echo "$OUTPUT" | grep -q "deny"'

echo "=== task preset: allows when full task evidence present ==="
clean_evidence
set_preset task
add_all_evidence_for_task
OUTPUT=$(echo "$(gate_input)" | bash "$GATE")
assert "task preset + full evidence → allowed" \
  '! echo "$OUTPUT" | grep -q "deny"'

echo "=== task preset: missing requirements-auditor still blocks ==="
clean_evidence
set_preset task
for type in pr-verified code-critic minimizer codex test-runner check-runner; do
  append_evidence "$SESSION_ID" "$type" "PASS" "$TMPDIR_BASE"
done
OUTPUT=$(echo "$(gate_input)" | bash "$GATE")
assert "task preset without requirements-auditor blocked" \
  'echo "$OUTPUT" | grep -q "deny"'

echo "=== task preset: blocks on stale diff_hash ==="
setup_repo
clean_evidence
echo "change" >> file.sh
git add file.sh && git commit -q -m "code change"
set_preset task
add_all_evidence_for_task
echo "stale" >> file.sh
git add file.sh && git commit -q -m "stale edit"
OUTPUT=$(echo "$(gate_input)" | bash "$GATE")
assert "task preset stale evidence → blocked" \
  'echo "$OUTPUT" | grep -q "deny"'

# ═══ bugfix preset ════════════════════════════════════════════════════════

echo "=== bugfix preset: allows without requirements-auditor ==="
setup_repo
clean_evidence
echo "fix" >> file.sh
git add file.sh && git commit -q -m "bug fix"
set_preset bugfix
add_all_evidence_for_bugfix
OUTPUT=$(echo "$(gate_input)" | bash "$GATE")
assert "bugfix preset + full bugfix evidence → allowed" \
  '! echo "$OUTPUT" | grep -q "deny"'

echo "=== bugfix preset: missing minimizer blocks ==="
clean_evidence
set_preset bugfix
for type in pr-verified code-critic codex test-runner check-runner; do
  append_evidence "$SESSION_ID" "$type" "PASS" "$TMPDIR_BASE"
done
OUTPUT=$(echo "$(gate_input)" | bash "$GATE")
assert "bugfix preset without minimizer blocked" \
  'echo "$OUTPUT" | grep -q "deny"'

# ═══ Companion inclusion path ═════════════════════════════════════════════
# When a companion role is configured, the gate must require the configured
# companion's name as an additional evidence type for task and bugfix presets.

echo "=== task preset with configured companion: requires companion evidence ==="
setup_repo
clean_evidence
write_companion_config
echo "with companion" >> file.sh
git add file.sh && git commit -q -m "configured companion"
set_preset task
for type in pr-verified code-critic minimizer requirements-auditor test-runner check-runner; do
  append_evidence "$SESSION_ID" "$type" "PASS" "$TMPDIR_BASE"
done
OUTPUT=$(echo "$(gate_input)" | bash "$GATE")
assert "task preset with companion configured but no companion evidence → blocked" \
  'echo "$OUTPUT" | grep -q "deny"'

echo "=== task preset with configured companion + companion evidence → allowed ==="
add_companion_evidence codex
OUTPUT=$(echo "$(gate_input)" | bash "$GATE")
assert "task preset with companion evidence → allowed" \
  '! echo "$OUTPUT" | grep -q "deny"'

echo "=== bugfix preset with configured companion: requires companion evidence ==="
setup_repo
clean_evidence
write_companion_config
echo "bug fix with companion" >> file.sh
git add file.sh && git commit -q -m "bugfix with companion"
set_preset bugfix
for type in pr-verified code-critic minimizer test-runner check-runner; do
  append_evidence "$SESSION_ID" "$type" "PASS" "$TMPDIR_BASE"
done
OUTPUT=$(echo "$(gate_input)" | bash "$GATE")
assert "bugfix preset with companion configured but no companion evidence → blocked" \
  'echo "$OUTPUT" | grep -q "deny"'

echo "=== bugfix preset with companion + companion evidence → allowed ==="
add_companion_evidence codex
OUTPUT=$(echo "$(gate_input)" | bash "$GATE")
assert "bugfix preset with companion evidence → allowed" \
  '! echo "$OUTPUT" | grep -q "deny"'

# ═══ quick preset ═════════════════════════════════════════════════════════

echo "=== quick preset: code-critic + runners + pr-verified → allowed ==="
setup_repo
clean_evidence
echo "quick change" >> file.sh
git add file.sh && git commit -q -m "quick fix"
set_preset quick
add_all_evidence_for_quick
OUTPUT=$(echo "$(gate_input)" | bash "$GATE")
assert "quick preset + quick evidence → allowed" \
  '! echo "$OUTPUT" | grep -q "deny"'

echo "=== quick preset: skips companion and minimizer ==="
clean_evidence
set_preset quick
append_evidence "$SESSION_ID" "pr-verified" "PASS" "$TMPDIR_BASE"
append_evidence "$SESSION_ID" "code-critic" "APPROVED" "$TMPDIR_BASE"
append_evidence "$SESSION_ID" "test-runner" "PASS" "$TMPDIR_BASE"
append_evidence "$SESSION_ID" "check-runner" "PASS" "$TMPDIR_BASE"
OUTPUT=$(echo "$(gate_input)" | bash "$GATE")
assert "quick preset without companion/minimizer → allowed" \
  '! echo "$OUTPUT" | grep -q "deny"'

echo "=== quick preset: missing code-critic blocks ==="
clean_evidence
set_preset quick
for type in pr-verified test-runner check-runner; do
  append_evidence "$SESSION_ID" "$type" "PASS" "$TMPDIR_BASE"
done
OUTPUT=$(echo "$(gate_input)" | bash "$GATE")
assert "quick preset without code-critic blocked" \
  'echo "$OUTPUT" | grep -q "deny"'

# ═══ spec preset ══════════════════════════════════════════════════════════

echo "=== spec preset: pr-verified alone passes ==="
setup_repo
clean_evidence
echo "spec code" >> file.sh
git add file.sh && git commit -q -m "spec-driven update"
set_preset spec
append_evidence "$SESSION_ID" "pr-verified" "PASS" "$TMPDIR_BASE"
OUTPUT=$(echo "$(gate_input)" | bash "$GATE")
assert "spec preset + pr-verified → allowed" \
  '! echo "$OUTPUT" | grep -q "deny"'

echo "=== spec preset: missing pr-verified blocks ==="
clean_evidence
set_preset spec
OUTPUT=$(echo "$(gate_input)" | bash "$GATE")
assert "spec preset without pr-verified blocked" \
  'echo "$OUTPUT" | grep -q "deny"'

# ═══ Config override ══════════════════════════════════════════════════════

echo "=== Config override: cfg.Evidence.Required overrides preset ==="
setup_repo
clean_evidence
write_custom_evidence_config
echo "configurable" >> file.sh
git add file.sh && git commit -q -m "configurable gate"
# Deliberately no preset set — config override alone should be enough.
append_evidence "$SESSION_ID" "pr-verified" "PASS" "$TMPDIR_BASE"
append_evidence "$SESSION_ID" "test-runner" "PASS" "$TMPDIR_BASE"
append_evidence "$SESSION_ID" "check-runner" "PASS" "$TMPDIR_BASE"
OUTPUT=$(echo "$(gate_input)" | bash "$GATE")
assert "Config override applied with only the three required evidence types" \
  '! echo "$OUTPUT" | grep -q "deny"'

echo "=== Config override: missing one required type blocks ==="
clean_evidence
write_custom_evidence_config
append_evidence "$SESSION_ID" "pr-verified" "PASS" "$TMPDIR_BASE"
append_evidence "$SESSION_ID" "test-runner" "PASS" "$TMPDIR_BASE"
OUTPUT=$(echo "$(gate_input)" | bash "$GATE")
assert "Config override missing check-runner blocks" \
  'echo "$OUTPUT" | grep -q "deny"'

# ═══ Non-PR commands pass through ═══════════════════════════════════════════

echo "=== Non-PR commands allowed ==="
setup_repo
clean_evidence
NON_PR_INPUT=$(jq -cn \
  --arg sid "$SESSION_ID" \
  --arg cwd "$TMPDIR_BASE" \
  '{tool_input:{command:"git push"},session_id:$sid,cwd:$cwd}')
OUTPUT=$(echo "$NON_PR_INPUT" | bash "$GATE")
assert "git push allowed without evidence" \
  '! echo "$OUTPUT" | grep -q "deny"'

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
