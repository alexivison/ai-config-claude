#!/usr/bin/env bash
# Register Claude's session ID with the party session state.
# Triggered: SessionStart
# Delegates to party-cli register for session discovery and manifest writes.
set -e

hook_input=$(cat)

session_id=$(echo "$hook_input" | jq -r '.session_id // empty' 2>/dev/null)
if [[ -z "$session_id" ]]; then
  echo '{}'
  exit 0
fi

# Delegate to party-cli if available.
if command -v party-cli &>/dev/null; then
  party-cli register --claude-session-id "$session_id" 2>/dev/null || true
  echo '{}'
  exit 0
fi

# Fallback: try go run if party-cli not installed.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${PARTY_REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)}"
if command -v go &>/dev/null && [[ -f "$REPO_ROOT/tools/party-cli/main.go" ]]; then
  go -C "$REPO_ROOT/tools/party-cli" run . register --claude-session-id "$session_id" 2>/dev/null || true
fi

echo '{}'
