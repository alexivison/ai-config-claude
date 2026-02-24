#!/usr/bin/env bash
# Tests for tmux_send input guard (party-lib.sh: tmux_pane_idle, _tmux_send_spool)
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

SESSION="party-test-guard-$$"
STATE_DIR="/tmp/$SESSION"
export PARTY_SESSION="$SESSION"
PHANTOM_PID=""

cleanup() {
  [[ -n "$PHANTOM_PID" ]] && kill "$PHANTOM_PID" 2>/dev/null || true
  tmux kill-session -t "$SESSION" 2>/dev/null || true
  rm -rf "$STATE_DIR"
}
trap cleanup EXIT

mkdir -p "$STATE_DIR"
echo "$SESSION" > "$STATE_DIR/session-name"

tmux new-session -d -s "$SESSION" -n work
tmux split-window -h -t "$SESSION:work"
tmux select-pane -t "$SESSION:work.0"

TARGET="$SESSION:work.0"

echo "--- test-tmux-send-guard.sh ---"

# --- tmux_pane_idle ---

assert "pane_idle: detached session returns 0 (idle)" \
  'tmux_pane_idle "$TARGET"'

# Attach phantom client focused on pane 0
tmux -C attach -t "$SESSION" < <(sleep 999) &
PHANTOM_PID=$!
sleep 0.5

assert "pane_idle: client focused on target returns 1 (busy)" \
  '! tmux_pane_idle "$TARGET"'

assert "pane_idle: non-focused pane returns 0 (idle)" \
  'tmux_pane_idle "$SESSION:work.1"'

# Kill phantom for copy-mode test
kill "$PHANTOM_PID" 2>/dev/null || true
wait "$PHANTOM_PID" 2>/dev/null || true
PHANTOM_PID=""
sleep 0.3

tmux copy-mode -t "$TARGET"
sleep 0.1
assert "pane_idle: copy mode returns 1 (busy)" \
  '! tmux_pane_idle "$TARGET"'
tmux send-keys -t "$TARGET" q
sleep 0.1

# --- TMUX_SEND_FORCE bypass ---

# Re-attach phantom to make pane busy
tmux -C attach -t "$SESSION" < <(sleep 999) &
PHANTOM_PID=$!
sleep 0.5

export TMUX_SEND_FORCE=1
RC=0
tmux_send "$TARGET" "forced delivery" || RC=$?
assert "TMUX_SEND_FORCE bypasses guard (rc=0)" \
  '[[ $RC -eq 0 ]]'

sleep 0.3
PANE_CONTENT=$(tmux capture-pane -t "$TARGET" -p)
assert "forced message appears in pane" \
  'echo "$PANE_CONTENT" | grep -q "forced delivery"'

# --- Spool on timeout ---

unset TMUX_SEND_FORCE
export TMUX_SEND_TIMEOUT=0

RC=0
tmux_send "$TARGET" "spool me" "test-caller" 2>"$STATE_DIR/spool-stderr" || RC=$?

assert "tmux_send returns 75 on timeout" \
  '[[ $RC -eq 75 ]]'

SPOOL_STDERR=$(cat "$STATE_DIR/spool-stderr" 2>/dev/null || echo "")
assert "stderr contains TMUX_SEND_BUSY" \
  'echo "$SPOOL_STDERR" | grep -q "TMUX_SEND_BUSY"'

SPOOL_FILE=$(ls -t "$STATE_DIR/pending/"*.msg 2>/dev/null | head -1 || echo "")
assert "spool file created in pending/" \
  '[[ -n "$SPOOL_FILE" && -f "$SPOOL_FILE" ]]'

if [[ -n "${SPOOL_FILE:-}" && -f "${SPOOL_FILE:-/dev/null}" ]]; then
  assert "spool header has target and caller" \
    'head -1 "$SPOOL_FILE" | grep -q "^#target=.*caller=test-caller"'
  assert "spool body has message text" \
    'tail -n +2 "$SPOOL_FILE" | grep -q "spool me"'
else
  assert "spool header has target and caller" 'false'
  assert "spool body has message text" 'false'
fi

unset TMUX_SEND_TIMEOUT

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
