#!/usr/bin/env bash
# Register Claude's session ID with the party session state.
# Triggered: SessionStart
# Writes to: $STATE_DIR/claude-session-id + tmux environment
set -e

hook_input=$(cat)

session_id=$(echo "$hook_input" | jq -r '.session_id // empty' 2>/dev/null)
if [[ -z "$session_id" ]]; then
  echo '{}'
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../session/party-lib.sh"

if ! discover_session 2>/dev/null; then
  echo '{}'
  exit 0
fi

# Write once — skip if already registered with this ID
id_file="$STATE_DIR/claude-session-id"
if [[ -f "$id_file" ]] && [[ "$(cat "$id_file")" == "$session_id" ]]; then
  echo '{}'
  exit 0
fi

printf '%s\n' "$session_id" > "$id_file"
tmux set-environment -t "$SESSION_NAME" CLAUDE_SESSION_ID "$session_id" 2>/dev/null || true

echo '{}'
