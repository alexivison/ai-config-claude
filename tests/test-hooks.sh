#!/usr/bin/env bash
# Tests for hook updates (codex-gate.sh, codex-trace.sh)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

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

SESSION_ID="test-hooks-$$"

cleanup() {
  rm -f "/tmp/claude-code-critic-$SESSION_ID"
  rm -f "/tmp/claude-minimizer-$SESSION_ID"
  rm -f "/tmp/claude-codex-ran-$SESSION_ID"
  rm -f "/tmp/claude-codex-$SESSION_ID"
}
trap cleanup EXIT

echo "--- test-hooks.sh ---"

# ── codex-gate.sh tests ──

GATE="$REPO_ROOT/claude/hooks/codex-gate.sh"

# Test: gate allows non-tmux-codex commands
OUTPUT=$(echo '{"tool_input":{"command":"ls -la"},"session_id":"'"$SESSION_ID"'"}' | bash "$GATE")
assert "gate allows non-tmux-codex commands" \
  'echo "$OUTPUT" | jq -e ".hookSpecificOutput" 2>/dev/null; [ $? -ne 0 ]'

# Test: gate blocks --review without critic markers
OUTPUT=$(echo '{"tool_input":{"command":"tmux-codex.sh --review main \"test\""},"session_id":"'"$SESSION_ID"'"}' | bash "$GATE")
assert "gate blocks --review without critic markers" \
  'echo "$OUTPUT" | grep -q "deny"'

# Test: gate allows --review with both critic markers
touch "/tmp/claude-code-critic-$SESSION_ID"
touch "/tmp/claude-minimizer-$SESSION_ID"
OUTPUT=$(echo '{"tool_input":{"command":"~/.claude/skills/codex-transport/scripts/tmux-codex.sh --review main \"test\""},"session_id":"'"$SESSION_ID"'"}' | bash "$GATE")
assert "gate allows --review with both critic markers" \
  '! echo "$OUTPUT" | grep -q "deny"'

# Test: gate blocks --approve without codex-ran marker
OUTPUT=$(echo '{"tool_input":{"command":"tmux-codex.sh --approve"},"session_id":"'"$SESSION_ID"'"}' | bash "$GATE")
assert "gate blocks --approve without codex-ran marker" \
  'echo "$OUTPUT" | grep -q "deny"'

# Test: gate allows --approve with codex-ran marker
touch "/tmp/claude-codex-ran-$SESSION_ID"
OUTPUT=$(echo '{"tool_input":{"command":"tmux-codex.sh --approve"},"session_id":"'"$SESSION_ID"'"}' | bash "$GATE")
assert "gate allows --approve with codex-ran marker" \
  '! echo "$OUTPUT" | grep -q "deny"'

# Test: gate allows --prompt without any markers (debugging/architecture)
rm -f "/tmp/claude-code-critic-$SESSION_ID" "/tmp/claude-minimizer-$SESSION_ID" "/tmp/claude-codex-ran-$SESSION_ID"
OUTPUT=$(echo '{"tool_input":{"command":"tmux-codex.sh --prompt \"debug this\""},"session_id":"'"$SESSION_ID"'"}' | bash "$GATE")
assert "gate allows --prompt without markers" \
  '! echo "$OUTPUT" | grep -q "deny"'

# Test: gate allows --plan-review without any markers (advisory, ungated)
rm -f "/tmp/claude-code-critic-$SESSION_ID" "/tmp/claude-minimizer-$SESSION_ID" "/tmp/claude-codex-ran-$SESSION_ID"
OUTPUT=$(echo '{"tool_input":{"command":"tmux-codex.sh --plan-review PLAN.md /tmp/work"},"session_id":"'"$SESSION_ID"'"}' | bash "$GATE")
assert "gate allows --plan-review without markers" \
  '! echo "$OUTPUT" | grep -q "deny"'

# ── codex-trace.sh tests ──

TRACE="$REPO_ROOT/claude/hooks/codex-trace.sh"

# Test: trace ignores non-tmux-codex commands
echo '{"tool_input":{"command":"ls -la"},"tool_response":"ok","tool_exit_code":"0","session_id":"'"$SESSION_ID"'"}' | bash "$TRACE"
assert "trace ignores non-tmux-codex commands" \
  '[ ! -f "/tmp/claude-codex-ran-$SESSION_ID" ]'

# Test: trace creates codex-ran marker on CODEX_REVIEW_RAN
cleanup
echo '{"tool_input":{"command":"tmux-codex.sh --review-complete /tmp/f.toon"},"tool_response":"CODEX_REVIEW_RAN","tool_exit_code":"0","session_id":"'"$SESSION_ID"'"}' | bash "$TRACE"
assert "trace creates codex-ran marker on CODEX_REVIEW_RAN" \
  '[ -f "/tmp/claude-codex-ran-$SESSION_ID" ]'

# Test: trace creates codex-approved marker on CODEX APPROVED (with codex-ran)
echo '{"tool_input":{"command":"tmux-codex.sh --approve"},"tool_response":"CODEX APPROVED","tool_exit_code":"0","session_id":"'"$SESSION_ID"'"}' | bash "$TRACE"
assert "trace creates codex-approved marker on CODEX APPROVED" \
  '[ -f "/tmp/claude-codex-$SESSION_ID" ]'

# Test: trace does NOT create codex-approved without codex-ran
cleanup
echo '{"tool_input":{"command":"tmux-codex.sh --approve"},"tool_response":"CODEX APPROVED","tool_exit_code":"0","session_id":"'"$SESSION_ID"'"}' | bash "$TRACE"
assert "trace blocks approval without codex-ran marker" \
  '[ ! -f "/tmp/claude-codex-$SESSION_ID" ]'

# Test: --re-review deletes codex-ran marker (prevents stale approval)
cleanup
touch "/tmp/claude-codex-ran-$SESSION_ID"
touch "/tmp/claude-codex-$SESSION_ID"
echo '{"tool_input":{"command":"tmux-codex.sh --re-review \"fixed null check\""},"tool_response":"CODEX REQUEST_CHANGES — fixed null check","tool_exit_code":"0","session_id":"'"$SESSION_ID"'"}' | bash "$TRACE"
assert "--re-review deletes codex-ran marker" \
  '[ ! -f "/tmp/claude-codex-ran-$SESSION_ID" ]'
assert "--re-review deletes codex-approved marker" \
  '[ ! -f "/tmp/claude-codex-$SESSION_ID" ]'

# Test: trace ignores failed commands
cleanup
echo '{"tool_input":{"command":"tmux-codex.sh --review-complete /tmp/f.toon"},"tool_response":"CODEX_REVIEW_RAN","tool_exit_code":"1","session_id":"'"$SESSION_ID"'"}' | bash "$TRACE"
assert "trace ignores failed commands (exit code != 0)" \
  '[ ! -f "/tmp/claude-codex-ran-$SESSION_ID" ]'

# Test: --plan-review does not create codex-ran marker (advisory, not approval evidence)
cleanup
echo '{"tool_input":{"command":"tmux-codex.sh --plan-review PLAN.md /tmp/work"},"tool_response":"CODEX_PLAN_REVIEW_REQUESTED","tool_exit_code":"0","session_id":"'"$SESSION_ID"'"}' | bash "$TRACE"
assert "--plan-review does not create codex-ran marker" \
  '[ ! -f "/tmp/claude-codex-ran-$SESSION_ID" ]'
assert "--plan-review does not create codex-approved marker" \
  '[ ! -f "/tmp/claude-codex-$SESSION_ID" ]'

# ── TOON format sanity check ──

TOON_VALID=$(cat <<'TOON_EOF'
findings[2]{id,file,line,severity,category,description,suggestion}:
  F1,src/app.ts,10,blocking,correctness,"Missing null check","Add guard clause"
  F2,src/util.ts,25,non-blocking,style,"Inconsistent naming","Rename to camelCase"
summary: Two findings across two files
stats:
  blocking_count: 1
  non_blocking_count: 1
  files_reviewed: 2
TOON_EOF
)

TOON_BAD_COUNT=$(cat <<'TOON_EOF'
findings[3]{id,file,line,severity,category,description,suggestion}:
  F1,src/app.ts,10,blocking,correctness,"Missing null check","Add guard clause"
  F2,src/util.ts,25,non-blocking,style,"Inconsistent naming","Rename to camelCase"
summary: Row count mismatch
stats:
  blocking_count: 1
  non_blocking_count: 1
  files_reviewed: 2
TOON_EOF
)

# Lightweight TOON sanity check: header fields + row count consistency
toon_validate() {
  local input="$1"
  # Check header format
  local header
  header=$(echo "$input" | head -1)
  if ! echo "$header" | grep -qE '^findings\[[0-9]+\]\{id,file,line,severity,category,description,suggestion\}:$'; then
    return 1
  fi
  # Extract declared count
  local declared
  declared=$(echo "$header" | grep -oE '\[[0-9]+\]' | tr -d '[]')
  # Count data rows (indented lines before summary/stats)
  local actual
  actual=$(echo "$input" | tail -n +2 | grep -cE '^ +F[0-9]+,' || echo 0)
  [ "$declared" -eq "$actual" ]
}

assert "TOON sanity check passes on valid sample" \
  'toon_validate "$TOON_VALID"'

assert "TOON sanity check fails on row-count mismatch" \
  '! toon_validate "$TOON_BAD_COUNT"'

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
