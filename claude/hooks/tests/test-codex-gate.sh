#!/usr/bin/env bash
# Tests for codex-gate.sh
# Single-phase model: only blocks --approve, all else passes through.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SCRIPT_DIR/../codex-gate.sh"
source "$SCRIPT_DIR/../lib/evidence.sh"

PASS=0
FAIL=0
SESSION_ID="test-codex-gate-$$"
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
  cd "$TMPDIR_BASE"
  git init -q
  git checkout -q -b main
  echo "initial" > file.txt
  git add file.txt
  git commit -q -m "initial commit"
  git checkout -q -b feature
  echo "impl" > impl.sh
  git add impl.sh
  git commit -q -m "add impl"
}

clean_evidence() {
  rm -f "$(evidence_file "$SESSION_ID")"
  rm -f "/tmp/claude-evidence-${SESSION_ID}.lock"
  rmdir "/tmp/claude-evidence-${SESSION_ID}.lock.d" 2>/dev/null || true
}

full_cleanup() {
  clean_evidence
  if [ -n "$TMPDIR_BASE" ] && [ -d "$TMPDIR_BASE" ]; then
    rm -rf "$TMPDIR_BASE"
  fi
}
trap full_cleanup EXIT

gate_input() {
  local cmd="$1"
  jq -cn \
    --arg cmd "$cmd" \
    --arg sid "$SESSION_ID" \
    --arg cwd "$TMPDIR_BASE" \
    '{tool_input:{command:$cmd},session_id:$sid,cwd:$cwd}'
}

setup_repo

echo "--- test-codex-gate.sh ---"

# Test: gate allows non-transport commands
OUTPUT=$(echo "$(gate_input 'ls -la')" | bash "$GATE")
assert "gate allows non-transport commands" \
  '! echo "$OUTPUT" | grep -q "deny"'

# Test: review without any evidence is allowed (no phase gate)
clean_evidence
OUTPUT=$(echo "$(gate_input 'party-cli transport review main "test"')" | bash "$GATE")
assert "transport review without evidence is allowed" \
  '! echo "$OUTPUT" | grep -q "deny"'

# Test: review with critic evidence is also allowed
clean_evidence
append_evidence "$SESSION_ID" "code-critic" "APPROVED" "$TMPDIR_BASE"
append_evidence "$SESSION_ID" "minimizer" "APPROVED" "$TMPDIR_BASE"
OUTPUT=$(echo "$(gate_input 'party-cli transport review main "test"')" | bash "$GATE")
assert "transport review with critic evidence is allowed" \
  '! echo "$OUTPUT" | grep -q "deny"'

# Test: gate always blocks approve (workers cannot self-approve)
clean_evidence
OUTPUT=$(echo "$(gate_input 'party-cli transport approve')" | bash "$GATE")
assert "transport approve blocked without evidence" \
  'echo "$OUTPUT" | grep -q "deny"'

# Test: approve blocked even with all possible evidence
clean_evidence
append_evidence "$SESSION_ID" "code-critic" "APPROVED" "$TMPDIR_BASE"
append_evidence "$SESSION_ID" "minimizer" "APPROVED" "$TMPDIR_BASE"
append_evidence "$SESSION_ID" "codex" "APPROVED" "$TMPDIR_BASE"
OUTPUT=$(echo "$(gate_input 'party-cli transport approve')" | bash "$GATE")
assert "transport approve blocked even with full evidence" \
  'echo "$OUTPUT" | grep -q "deny"'

# Test: prompt passes through without evidence
clean_evidence
OUTPUT=$(echo "$(gate_input 'party-cli transport prompt "debug this"')" | bash "$GATE")
assert "transport prompt allowed without evidence" \
  '! echo "$OUTPUT" | grep -q "deny"'

# Test: plan-review passes through without evidence
clean_evidence
OUTPUT=$(echo "$(gate_input 'party-cli transport plan-review PLAN.md /tmp/work')" | bash "$GATE")
assert "transport plan-review allowed without evidence" \
  '! echo "$OUTPUT" | grep -q "deny"'

# Test: review-complete passes through
clean_evidence
OUTPUT=$(echo "$(gate_input 'party-cli transport review-complete /tmp/findings.toon')" | bash "$GATE")
assert "transport review-complete allowed" \
  '! echo "$OUTPUT" | grep -q "deny"'

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
