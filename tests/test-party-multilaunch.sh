#!/usr/bin/env bash
# Tests for multi-party launch: --detached, --prompt, --switch, and party_attach tmux-awareness.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/session/party-lib.sh"

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

SESSION="party-test-multilaunch-$$"
export PARTY_SESSION="$SESSION"

cleanup() {
  rm -rf "/tmp/$SESSION"
}
trap cleanup EXIT

echo "--- test-party-multilaunch.sh ---"

# === Prompt quoting safety ===

# Simple text
printf -v q '%q' "Work on TASK-42.md"
assert "prompt quoting: simple text preserved" \
  '[ "$(eval echo "$q")" = "Work on TASK-42.md" ]'

# Text with spaces and quotes
printf -v q '%q' "Fix the \"auth\" bug"
assert "prompt quoting: double quotes preserved" \
  '[ "$(eval echo "$q")" = "Fix the \"auth\" bug" ]'

# Text starting with dash (the Codex-caught bug)
printf -v q '%q' "-p flag test"
assert "prompt quoting: dash prefix preserved" \
  '[ "$(eval echo "$q")" = "-p flag test" ]'

# Text with single quotes
printf -v q '%q' "Don't break"
assert "prompt quoting: single quotes preserved" \
  '[ "$(eval echo "$q")" = "Don'\''t break" ]'

# Text with special shell chars
printf -v q '%q' 'echo $HOME && rm -rf /'
assert "prompt quoting: shell metacharacters preserved" \
  '[ "$(eval echo "$q")" = "echo \$HOME && rm -rf /" ]'

# NOTE: Prompt persistence to manifest tests removed —
# manifest CRUD now lives in party-cli (Go). See internal/state/ for tests.

# === party_attach tmux-awareness ===

# Inside tmux: should use switch-client
ATTACH_CMD=""
tmux() { ATTACH_CMD="$*"; return 0; }
TMUX="/tmp/tmux-1000/default,12345,0"
export TMUX
party_attach "party-test-session" 2>/dev/null || true
assert "party_attach: inside tmux uses switch-client" \
  '[[ "$ATTACH_CMD" == *"switch-client"* ]]'
assert "party_attach: targets correct session" \
  '[[ "$ATTACH_CMD" == *"party-test-session"* ]]'
unset TMUX

# Outside tmux: should use attach (mock binary because exec bypasses functions)
_mock_bin="$(mktemp -d)"
printf '#!/bin/bash\necho "$@"\n' > "$_mock_bin/tmux"
chmod +x "$_mock_bin/tmux"
ATTACH_CMD="$(
  export PATH="$_mock_bin:$PATH"
  unset TMUX
  party_attach "party-test-session" 2>/dev/null
)" || true
rm -rf "$_mock_bin"
assert "party_attach: outside tmux uses attach" \
  '[[ "$ATTACH_CMD" == *"attach"* ]]'

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
