#!/usr/bin/env bash
# tmux-claude.sh — Codex's direct interface to Claude via tmux
# Replaces call_claude.sh
set -euo pipefail

MESSAGE="${1:?Usage: tmux-claude.sh \"message for Claude\"}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../../session/party-lib.sh"
discover_session

# Register Codex's thread ID with the party session (write-once)
if [[ -n "${CODEX_THREAD_ID:-}" && ! -s "$STATE_DIR/codex-thread-id" ]]; then
  printf '%s\n' "$CODEX_THREAD_ID" > "$STATE_DIR/codex-thread-id"
  tmux set-environment -t "$SESSION_NAME" CODEX_THREAD_ID "$CODEX_THREAD_ID" 2>/dev/null || true
fi

CLAUDE_PANE="$SESSION_NAME:0.0"

if tmux_send "$CLAUDE_PANE" "[CODEX] $MESSAGE" "tmux-claude.sh"; then
  echo "CLAUDE_MESSAGE_SENT"
else
  echo "CLAUDE_MESSAGE_QUEUED"
fi
