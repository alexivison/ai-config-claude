#!/usr/bin/env bash
# party-relay.sh — Send messages to worker sessions from a master session.
# Usage:
#   party-relay.sh <worker-id> "message"          # relay to one worker
#   party-relay.sh --broadcast "message"           # broadcast to all workers
#   party-relay.sh --list                          # list workers + status
#   party-relay.sh --stop <worker-id>              # stop a worker
#   party-relay.sh --spawn [--prompt "..."] "title" # spawn a new worker
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/party-lib.sh"

relay_usage() {
  cat <<'EOF'
Usage:
  party-relay.sh <worker-id> "message"
  party-relay.sh --broadcast "message"
  party-relay.sh --list
  party-relay.sh --stop <worker-id>
  party-relay.sh --spawn [--prompt "text"] "title"
EOF
}

# Discover master session. Requires running inside a master party session
# or PARTY_SESSION being set to a master session.
relay_discover_master() {
  discover_session || {
    echo "Error: party-relay.sh must be run inside a party session or with PARTY_SESSION set." >&2
    return 1
  }
  if ! party_is_master "$SESSION_NAME"; then
    echo "Error: session '$SESSION_NAME' is not a master session." >&2
    return 1
  fi
}

relay_to_worker() {
  local worker="${1:?Missing worker ID}"
  local message="${2:?Missing message}"

  if ! tmux has-session -t "$worker" 2>/dev/null; then
    echo "Error: worker session '$worker' is not running." >&2
    return 1
  fi

  local target
  target="$(party_role_pane_target "$worker" "claude" 2>/dev/null)" || {
    echo "Error: cannot find Claude pane in worker '$worker'." >&2
    return 1
  }

  tmux_send "$target" "$message" "relay"
}

relay_broadcast() {
  local message="${1:?Missing message}"
  local workers
  workers="$(party_state_get_workers "$SESSION_NAME")"

  if [[ -z "$workers" ]]; then
    echo "No workers to broadcast to."
    return 0
  fi

  local count=0
  while IFS= read -r wid; do
    if tmux has-session -t "$wid" 2>/dev/null; then
      local target
      target="$(party_role_pane_target "$wid" "claude" 2>/dev/null)" || continue
      tmux_send "$target" "$message" "broadcast" || true
      count=$((count + 1))
    fi
  done <<< "$workers"

  echo "Broadcast sent to $count worker(s)."
}

relay_list() {
  local workers
  workers="$(party_state_get_workers "$SESSION_NAME")"

  if [[ -z "$workers" ]]; then
    echo "No workers registered."
    return 0
  fi

  printf '%-25s %-8s %s\n' "SESSION" "STATUS" "TITLE"
  while IFS= read -r wid; do
    local status title
    if tmux has-session -t "$wid" 2>/dev/null; then
      status="active"
    else
      status="stopped"
    fi
    title="$(party_state_get_field "$wid" "title" 2>/dev/null || true)"
    printf '%-25s %-8s %s\n' "$wid" "$status" "${title:--}"
  done <<< "$workers"
}

relay_spawn() {
  local prompt=""
  local title=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --prompt) prompt="${2:?--prompt requires a message}"; shift 2 ;;
      *) title="$1"; shift ;;
    esac
  done

  local args=("$SCRIPT_DIR/party.sh" "--detached" "--master-id" "$SESSION_NAME")
  [[ -n "$prompt" ]] && args+=("--prompt" "$prompt")
  [[ -n "$title" ]] && args+=("$title")

  bash "${args[@]}"
}

# --- Main ---

if [[ $# -eq 0 ]]; then
  relay_usage
  exit 1
fi

case "$1" in
  --broadcast)
    relay_discover_master
    relay_broadcast "${2:?--broadcast requires a message}"
    ;;
  --list)
    relay_discover_master
    relay_list
    ;;
  --stop)
    relay_discover_master
    bash "$SCRIPT_DIR/party.sh" --stop "${2:?--stop requires a worker ID}"
    ;;
  --spawn)
    relay_discover_master
    shift
    relay_spawn "$@"
    ;;
  --help|-h)
    relay_usage
    ;;
  *)
    # Direct relay: party-relay.sh <worker-id> "message"
    if [[ $# -lt 2 ]]; then
      relay_usage >&2
      exit 1
    fi
    relay_to_worker "$1" "$2"
    ;;
esac
