#!/usr/bin/env bash
# Tests for worktree-track.sh
# Covers: path extraction, empty-path guard, normalization
#
# Usage: bash ~/.claude/hooks/tests/test-worktree-track.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../worktree-track.sh"

PASS=0
FAIL=0
SESSION_ID="test-worktree-track-$$"
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

cleanup() {
  rm -f "/tmp/claude-worktree-${SESSION_ID}"
  if [ -n "$TMPDIR_BASE" ] && [ -d "$TMPDIR_BASE" ]; then
    rm -rf "$TMPDIR_BASE"
  fi
}
trap cleanup EXIT

echo "--- test-worktree-track.sh ---"

# ═══ Empty path guard ═══════════════════════════════════════════════════════

echo "=== Empty path: normalization failure must not write empty override ==="
TMPDIR_BASE=$(mktemp -d)
rm -f "/tmp/claude-worktree-${SESSION_ID}"

# Simulate: cwd is valid but the resolved worktree path doesn't exist as a directory.
# The hook should NOT write an empty/newline-only override file.
HOOK_INPUT=$(jq -cn \
  --arg sid "$SESSION_ID" \
  --arg cwd "$TMPDIR_BASE" \
  '{tool_input:{command:"git worktree add ../nonexistent-worktree -b test-branch"},session_id:$sid,cwd:$cwd,tool_exit_code:0}')
echo "$HOOK_INPUT" | bash "$HOOK" >/dev/null

if [ -f "/tmp/claude-worktree-${SESSION_ID}" ]; then
  CONTENT=$(cat "/tmp/claude-worktree-${SESSION_ID}")
  assert "Override file not written with empty content" \
    '[ -n "$CONTENT" ] && [ -d "$CONTENT" ]'
else
  # File not created at all — also correct behavior
  assert "Override file not written with empty content" 'true'
fi

echo "=== Empty path: missing cwd field must not write empty override ==="
rm -f "/tmp/claude-worktree-${SESSION_ID}"

# Simulate: hook input has no cwd field, relative path can't be resolved
HOOK_INPUT=$(jq -cn \
  --arg sid "$SESSION_ID" \
  '{tool_input:{command:"git worktree add ../some-worktree -b branch"},session_id:$sid,tool_exit_code:0}')
echo "$HOOK_INPUT" | bash "$HOOK" >/dev/null

if [ -f "/tmp/claude-worktree-${SESSION_ID}" ]; then
  CONTENT=$(cat "/tmp/claude-worktree-${SESSION_ID}")
  assert "No override file when cwd missing" \
    '[ -n "$CONTENT" ] && [ -d "$CONTENT" ]'
else
  assert "No override file when cwd missing" 'true'
fi

# ═══ Happy path ═══════════════════════════════════════════════════════════

echo "=== Happy path: valid worktree path is written ==="
TMPDIR_BASE=$(mktemp -d)
WORKTREE_DIR="$TMPDIR_BASE/my-worktree"
mkdir -p "$WORKTREE_DIR"
rm -f "/tmp/claude-worktree-${SESSION_ID}"

HOOK_INPUT=$(jq -cn \
  --arg sid "$SESSION_ID" \
  --arg cwd "$TMPDIR_BASE" \
  --arg cmd "git worktree add $WORKTREE_DIR -b test-branch" \
  '{tool_input:{command:$cmd},session_id:$sid,cwd:$cwd,tool_exit_code:0}')
echo "$HOOK_INPUT" | bash "$HOOK" >/dev/null

assert "Override file written with valid absolute path" \
  '[ -f "/tmp/claude-worktree-${SESSION_ID}" ] && [ "$(cat /tmp/claude-worktree-${SESSION_ID})" = "'"$WORKTREE_DIR"'" ]'

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
