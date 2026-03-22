#!/usr/bin/env bash
# party-master-jump.sh — Switch to the parent master session from a worker
# Used as a tmux keybinding target.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/party-lib.sh"

session=$(tmux display-message -p '#{session_name}' 2>/dev/null)

if [[ ! "$session" =~ ^party- ]]; then
  tmux display-message "Not in a party session"
  exit 0
fi

# If we're already in a master session, say so
if party_is_master "$session"; then
  tmux display-message "Already in master session"
  exit 0
fi

# Look up parent_session from manifest via jq
manifest="$(party_state_file "$session")"
parent=""
if [[ -f "$manifest" ]] && command -v jq >/dev/null 2>&1; then
  parent="$(jq -r '.parent_session // empty' "$manifest" 2>/dev/null || true)"
fi

if [[ -z "$parent" ]]; then
  tmux display-message "No parent master session found"
  exit 0
fi

# Verify the master session is still running
if ! tmux has-session -t "$parent" 2>/dev/null; then
  tmux display-message "Master session '$parent' is not running"
  exit 0
fi

tmux switch-client -t "$parent"
