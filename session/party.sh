#!/usr/bin/env bash
# party.sh — Launch a tmux session with Claude (Paladin) and Codex (Wizard)
# Usage: party.sh [--raw] [TITLE] | --stop [name] | --list | --install-tpm
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/party-lib.sh"

party_install_tpm() {
  local tpm_path="${TMUX_PLUGIN_MANAGER_PATH:-$HOME/.tmux/plugins/tpm}"
  local tpm_repo="${TPM_REPO:-https://github.com/tmux-plugins/tpm}"

  if ! command -v git >/dev/null 2>&1; then
    echo "Error: git is required to install TPM." >&2
    return 1
  fi

  if [[ -d "$tpm_path/.git" ]]; then
    echo "TPM already installed at: $tpm_path"
    return 0
  fi

  if [[ -e "$tpm_path" ]]; then
    echo "Error: path exists but is not a TPM git clone: $tpm_path" >&2
    return 1
  fi

  mkdir -p "$(dirname "$tpm_path")"
  git clone "$tpm_repo" "$tpm_path" >/dev/null

  echo "TPM installed at: $tpm_path"
  echo "In tmux, press Prefix + I to install plugins."
}

configure_party_theme() {
  local session="${1:?Usage: configure_party_theme SESSION_NAME}"

  # Role labels based on pane index, with session ID suffix when available.
  # IDs appear after agents register (Claude on SessionStart, Codex on first message).
  tmux set-option -t "$session" pane-border-status top
  tmux set-option -t "$session" pane-border-format \
    ' #{?#{==:#{pane_index},0},The Paladin#{?#{CLAUDE_SESSION_ID}, (#{=8:CLAUDE_SESSION_ID}),},The Wizard#{?#{CODEX_THREAD_ID}, (#{=8:CODEX_THREAD_ID}),}} '
}

party_start() {
  local title="${1:-}"
  local session="party-$(date +%s)"
  local state_dir="/tmp/$session"

  mkdir -p "$state_dir"
  echo "$session" > "$state_dir/session-name"

  # Detect iTerm2 for control mode
  local use_cc=false
  if [[ "${TERM_PROGRAM:-}" == "iTerm.app" && "${PARTY_RAW:-}" != "1" ]]; then
    use_cc=true
  fi

  # Create detached session — launch agents via login shell for PATH.
  local window_name="work"
  if [[ -n "$title" ]]; then
    window_name="party ($title)"
  fi
  tmux new-session -d -s "$session" -n "$window_name"

  # Purge CLAUDECODE from tmux environment at every level.
  # The tmux server inherits this if it was started from a Claude Code session.
  # Global unset needed because session-level unset alone doesn't affect pane
  # processes — they inherit from the server's global environment.
  tmux set-environment -g -u CLAUDECODE 2>/dev/null || true
  tmux set-environment -t "$session" -u CLAUDECODE 2>/dev/null || true

  # Launch agents with full paths and explicit PATH.
  # Tmux panes use non-interactive shells which don't source .zshrc.
  local claude_bin="${CLAUDE_BIN:-$(command -v claude 2>/dev/null || echo "$HOME/.local/bin/claude")}"
  local codex_bin="${CODEX_BIN:-$(command -v codex 2>/dev/null || echo "/opt/homebrew/bin/codex")}"
  local agent_path="$HOME/.local/bin:/opt/homebrew/bin:${PATH:-/usr/bin:/bin}"

  tmux respawn-pane -k -t "$session:0.0" \
    "export PATH='$agent_path'; unset CLAUDECODE; exec '$claude_bin' --dangerously-skip-permissions"
  tmux split-window -h -t "$session:0" \
    "export PATH='$agent_path'; exec '$codex_bin' --dangerously-bypass-approvals-and-sandbox"

  # Label panes (title-lock options are global in .tmux.conf)
  tmux select-pane -t "$session:0.0" -T "The Paladin"
  tmux select-pane -t "$session:0.1" -T "The Wizard"

  configure_party_theme "$session"

  # Auto-cleanup state dir when session ends (kill-session, Prefix+Q, etc.)
  tmux set-hook -t "$session" session-closed \
    "run-shell 'rm -rf /tmp/$session'"

  # Focus Claude pane
  tmux select-pane -t "$session:0.0"

  echo "Party session '$session' started."
  echo "State dir: $state_dir"

  # Attach
  if [[ "$use_cc" == true ]]; then
    exec tmux -CC attach -t "$session"
  else
    exec tmux attach -t "$session"
  fi
}

party_stop() {
  local target="${1:-}"

  if [[ -n "$target" ]]; then
    # Validate prefix to prevent path traversal (rm -rf "/tmp/$target")
    if [[ ! "$target" =~ ^party- ]]; then
      echo "Error: invalid session name '$target' (must start with party-)" >&2
      return 1
    fi
    tmux kill-session -t "$target" 2>/dev/null || true
    rm -rf "/tmp/$target"
    echo "Party session '$target' stopped."
    return 0
  fi

  # Stop all party sessions
  local sessions
  sessions=$(tmux ls -F '#{session_name}' 2>/dev/null | grep '^party-' || true)

  if [[ -z "$sessions" ]]; then
    echo "No active party sessions."
    return 0
  fi

  while IFS= read -r name; do
    tmux kill-session -t "$name" 2>/dev/null || true
    rm -rf "/tmp/$name"
    echo "Stopped: $name"
  done <<< "$sessions"
}

party_list() {
  local sessions
  sessions=$(tmux ls -F '#{session_name}' 2>/dev/null | grep '^party-' || true)

  if [[ -z "$sessions" ]]; then
    echo "No active party sessions."
    return 0
  fi

  echo "Active party sessions:"
  while IFS= read -r name; do
    echo "  $name"
  done <<< "$sessions"
}

case "${1:-}" in
  --install-tpm) party_install_tpm ;;
  --stop) party_stop "${2:-}" ;;
  --list) party_list ;;
  --raw)  PARTY_RAW=1 party_start "${2:-}" ;;
  --*)    echo "Usage: party.sh [--raw] [TITLE] | --stop [name] | --list | --install-tpm" >&2; exit 1 ;;
  *)      party_start "${1:-}" ;;
esac
