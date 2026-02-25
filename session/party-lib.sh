#!/usr/bin/env bash
# party-lib.sh — Shared helpers for party session discovery
# Sourced by party.sh, tmux-codex.sh, and tmux-claude.sh

# Discovers the party session this script is running inside.
# Uses $TMUX env var to self-discover — no global pointer file needed.
# Sets SESSION_NAME and STATE_DIR. Returns 1 if not inside a party session.
discover_session() {
  local name

  # PARTY_SESSION override for testing (scripts run outside tmux)
  if [[ -n "${PARTY_SESSION:-}" ]]; then
    name="$PARTY_SESSION"
  elif [[ -n "${TMUX:-}" ]]; then
    name=$(tmux display-message -p '#{session_name}' 2>/dev/null)
  else
    # Not inside tmux — scan for a running party session
    local matches
    matches=$(tmux ls -F '#{session_name}' 2>/dev/null | grep '^party-' || true)
    local count
    count=$(echo "$matches" | grep -c . 2>/dev/null || echo 0)

    if [[ "$count" -eq 1 ]]; then
      name="$matches"
    elif [[ "$count" -gt 1 ]]; then
      echo "Error: Multiple party sessions found — set PARTY_SESSION to disambiguate:" >&2
      echo "$matches" >&2
      return 1
    else
      echo "Error: No party session found and not inside tmux" >&2
      return 1
    fi
  fi

  if [[ ! "$name" =~ ^party- ]]; then
    echo "Error: Current tmux session '$name' is not a party session" >&2
    return 1
  fi

  local state_dir="/tmp/$name"
  if [[ ! -d "$state_dir" || ! -f "$state_dir/session-name" ]]; then
    echo "Error: State directory missing for session '$name'" >&2
    return 1
  fi

  SESSION_NAME="$name"
  STATE_DIR="$state_dir"
}

# Returns 0 if the target pane is idle (safe to send), 1 if busy.
# Busy = pane is in copy mode (user is reading scrollback).
# Fails closed: tmux command failure → return 1 (uncertain = busy).
tmux_pane_idle() {
  local target="$1"
  local pane_in_mode

  pane_in_mode=$(tmux display-message -t "$target" -p '#{pane_in_mode}' 2>/dev/null) || return 1
  [[ "$pane_in_mode" -gt 0 ]] && return 1

  return 0
}

# Spools a message to disk when the target pane is busy.
_tmux_send_spool() {
  local target="$1"
  local text="$2"
  local caller="${3:-unknown}"

  local pending_dir="${STATE_DIR:?STATE_DIR unset — call discover_session first}/pending"
  mkdir -p "$pending_dir"

  local ts iso_ts
  ts="$(date +%s)_$$_${RANDOM}"
  iso_ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local msg_file="$pending_dir/${ts}.msg"

  {
    echo "#target=$target caller=$caller created_at=$iso_ts"
    printf '%s\n' "$text"
  } > "$msg_file"

  echo "TMUX_SEND_BUSY pending=$msg_file target=$target" >&2
}

# Sends text to a tmux pane running a TUI agent (Claude Code / Codex CLI).
# Uses -l flag + delay + separate Enter to avoid paste-mode newline issue.
# Guards against injecting text while a human has the pane focused.
# Returns 75 (EX_TEMPFAIL) and spools to disk on timeout.
tmux_send() {
  local target="$1"
  local text="$2"
  local caller="${3:-}"

  # Force bypass for tests and explicit override
  if [[ "${TMUX_SEND_FORCE:-}" == "1" ]]; then
    tmux send-keys -t "$target" -l "$text"
    sleep 0.1
    tmux send-keys -t "$target" Enter
    return 0
  fi

  # Try immediate send
  if tmux_pane_idle "$target"; then
    tmux send-keys -t "$target" -l "$text"
    sleep 0.1
    tmux send-keys -t "$target" Enter
    return 0
  fi

  # Poll until idle or timeout
  local timeout_s="${TMUX_SEND_TIMEOUT:-1.5}"
  local timeout_ms
  timeout_ms=$(awk -v s="$timeout_s" 'BEGIN { printf "%d", s * 1000 }')
  local elapsed_ms=0

  while (( elapsed_ms < timeout_ms )); do
    sleep 0.1
    elapsed_ms=$(( elapsed_ms + 100 ))
    if tmux_pane_idle "$target"; then
      tmux send-keys -t "$target" -l "$text"
      sleep 0.1
      tmux send-keys -t "$target" Enter
      return 0
    fi
  done

  # Timeout — spool to disk
  _tmux_send_spool "$target" "$text" "${caller:-unknown}"
  return 75
}
