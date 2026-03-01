#!/usr/bin/env bash
# party.sh — Launch or resume a tmux session with Claude (Paladin) and Codex (Wizard)
# Usage: party.sh [--raw] [--resume-claude ID] [--resume-codex ID] [TITLE]
#        party.sh --continue <party-id> | --stop [name] | --list | --install-tpm
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/party-lib.sh"

party_usage() {
  cat <<'EOF'
Usage:
  party.sh [--raw] [--resume-claude ID] [--resume-codex ID] [TITLE]
  party.sh --continue <party-id>
  party.sh continue <party-id>
  party.sh --stop [name]
  party.sh --list
  party.sh --install-tpm
EOF
}

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

party_use_cc() {
  if [[ "${TERM_PROGRAM:-}" == "iTerm.app" && "${PARTY_RAW:-}" != "1" ]]; then
    return 0
  fi
  return 1
}

party_attach() {
  local session="${1:?Usage: party_attach SESSION_NAME}"
  if party_use_cc; then
    exec tmux -CC attach -t "$session"
  fi
  exec tmux attach -t "$session"
}

party_window_name() {
  local title="${1:-}"
  if [[ -n "$title" ]]; then
    printf 'party (%s)\n' "$title"
  else
    printf 'work\n'
  fi
}

configure_party_theme() {
  local session="${1:?Usage: configure_party_theme SESSION_NAME}"

  # Role labels driven by @party_role metadata, with session ID suffix when available.
  # IDs appear after agents register (Claude on SessionStart, Codex on first message).
  tmux set-option -t "$session" pane-border-status top
  tmux set-option -t "$session" pane-border-format \
    ' #{?#{==:#{@party_role},claude},The Paladin#{?#{CLAUDE_SESSION_ID}, (#{CLAUDE_SESSION_ID}),},#{?#{==:#{@party_role},codex},The Wizard#{?#{CODEX_THREAD_ID}, (#{CODEX_THREAD_ID}),},#{?#{==:#{@party_role},shell},Shell,}}} '
}

party_set_cleanup_hook() {
  local session="${1:?Usage: party_set_cleanup_hook SESSION_NAME}"
  tmux set-hook -t "$session" session-closed \
    "run-shell 'rm -rf /tmp/$session'"
}

party_launch_agents() {
  local session="${1:?Usage: party_launch_agents SESSION CWD CLAUDE_BIN CODEX_BIN AGENT_PATH [CLAUDE_RESUME_ID] [CODEX_RESUME_ID]}"
  local session_cwd="${2:?Missing session_cwd}"
  local claude_bin="${3:?Missing claude_bin}"
  local codex_bin="${4:?Missing codex_bin}"
  local agent_path="${5:?Missing agent_path}"
  local claude_resume_id="${6:-}"
  local codex_resume_id="${7:-}"
  local state_dir

  state_dir="$(ensure_party_state_dir "$session")"

  tmux set-environment -g -u CLAUDECODE 2>/dev/null || true
  tmux set-environment -t "$session" -u CLAUDECODE 2>/dev/null || true

  local q_agent_path q_claude_bin q_codex_bin
  local q_claude_resume_id q_codex_resume_id
  printf -v q_agent_path '%q' "$agent_path"
  printf -v q_claude_bin '%q' "$claude_bin"
  printf -v q_codex_bin '%q' "$codex_bin"

  local claude_cmd codex_cmd
  claude_cmd="export PATH=$q_agent_path; unset CLAUDECODE; exec $q_claude_bin --dangerously-skip-permissions"
  if [[ -n "$claude_resume_id" ]]; then
    printf -v q_claude_resume_id '%q' "$claude_resume_id"
    claude_cmd="$claude_cmd --resume $q_claude_resume_id"
    printf '%s\n' "$claude_resume_id" > "$state_dir/claude-session-id"
    tmux set-environment -t "$session" CLAUDE_SESSION_ID "$claude_resume_id" 2>/dev/null || true
  fi

  codex_cmd="export PATH=$q_agent_path; exec $q_codex_bin --dangerously-bypass-approvals-and-sandbox"
  if [[ -n "$codex_resume_id" ]]; then
    printf -v q_codex_resume_id '%q' "$codex_resume_id"
    codex_cmd="$codex_cmd resume $q_codex_resume_id"
    printf '%s\n' "$codex_resume_id" > "$state_dir/codex-thread-id"
    tmux set-environment -t "$session" CODEX_THREAD_ID "$codex_resume_id" 2>/dev/null || true
  fi

  # Pane 0: Codex (The Wizard)
  tmux respawn-pane -k -t "$session:0.0" -c "$session_cwd" "$codex_cmd"
  tmux set-option -p -t "$session:0.0" @party_role codex

  # Pane 1: Claude (The Paladin)
  tmux split-window -h -t "$session:0.0" -c "$session_cwd" "$claude_cmd"
  tmux set-option -p -t "$session:0.1" @party_role claude

  # Pane 2: Shell (operator terminal)
  tmux split-window -h -t "$session:0.1" -c "$session_cwd"
  tmux set-option -p -t "$session:0.2" @party_role shell

  tmux select-pane -t "$session:0.0" -T "The Wizard"
  tmux select-pane -t "$session:0.1" -T "The Paladin"
  tmux select-pane -t "$session:0.2" -T "Shell"
  configure_party_theme "$session"
  party_set_cleanup_hook "$session"
  tmux select-pane -t "$session:0.1"
}

party_create_session() {
  local session="${1:?Usage: party_create_session SESSION WINDOW_NAME CWD}"
  local window_name="${2:?Missing window_name}"
  local session_cwd="${3:?Missing session_cwd}"

  tmux new-session -d -s "$session" -n "$window_name" -c "$session_cwd"
}

party_start() {
  local title="${1:-}"
  local resume_claude="${2:-}"
  local resume_codex="${3:-}"
  local session="party-$(date +%s)"
  local state_dir
  local session_cwd="$PWD"
  local window_name
  local claude_bin codex_bin agent_path

  while tmux has-session -t "$session" 2>/dev/null; do
    session="party-$(date +%s)-$RANDOM"
  done

  window_name="$(party_window_name "$title")"
  claude_bin="${CLAUDE_BIN:-$(command -v claude 2>/dev/null || echo "$HOME/.local/bin/claude")}"
  codex_bin="${CODEX_BIN:-$(command -v codex 2>/dev/null || echo "/opt/homebrew/bin/codex")}"
  agent_path="$HOME/.local/bin:/opt/homebrew/bin:${PATH:-/usr/bin:/bin}"

  state_dir="$(ensure_party_state_dir "$session")"
  party_state_upsert_manifest "$session" "$title" "$session_cwd" "$window_name" "$claude_bin" "$codex_bin" "$agent_path" || true
  party_state_set_field "$session" "last_started_at" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" || true

  party_create_session "$session" "$window_name" "$session_cwd"
  party_launch_agents "$session" "$session_cwd" "$claude_bin" "$codex_bin" "$agent_path" "$resume_claude" "$resume_codex"

  echo "Party session '$session' started."
  echo "State dir: $state_dir"
  echo "Manifest: $(party_state_file "$session")"
  party_attach "$session"
}

party_continue() {
  local session="${1:-}"
  if [[ -z "$session" ]]; then
    echo "Error: --continue requires a party session name (e.g. party-1234567890)." >&2
    return 1
  fi
  if [[ ! "$session" =~ ^party- ]]; then
    echo "Error: invalid session name '$session' (must start with party-)." >&2
    return 1
  fi

  if tmux has-session -t "$session" 2>/dev/null; then
    ensure_party_state_dir "$session" >/dev/null
    echo "Party session '$session' is already running. Re-attaching."
    party_attach "$session"
  fi

  local manifest
  manifest="$(party_state_file "$session")"
  if [[ ! -f "$manifest" ]]; then
    echo "Error: No persisted party manifest for '$session' at $manifest" >&2
    echo "Start a new session with ./session/party.sh first." >&2
    return 1
  fi

  local session_cwd window_name
  local claude_bin codex_bin agent_path
  local title claude_resume_id codex_resume_id

  session_cwd="$(party_state_get_field "$session" "cwd" || true)"
  window_name="$(party_state_get_field "$session" "window_name" || true)"
  title="$(party_state_get_field "$session" "title" || true)"
  claude_bin="$(party_state_get_field "$session" "claude_bin" || true)"
  codex_bin="$(party_state_get_field "$session" "codex_bin" || true)"
  agent_path="$(party_state_get_field "$session" "agent_path" || true)"
  claude_resume_id="$(party_state_get_field "$session" "claude_session_id" || true)"
  codex_resume_id="$(party_state_get_field "$session" "codex_thread_id" || true)"

  [[ -n "$session_cwd" ]] || session_cwd="$PWD"
  if [[ ! -d "$session_cwd" ]]; then
    echo "Note: saved cwd '$session_cwd' no longer exists; using '$PWD'."
    session_cwd="$PWD"
  fi
  [[ -n "$window_name" ]] || window_name="$(party_window_name "$title")"
  [[ -n "$claude_bin" ]] || claude_bin="${CLAUDE_BIN:-$(command -v claude 2>/dev/null || echo "$HOME/.local/bin/claude")}"
  [[ -n "$codex_bin" ]] || codex_bin="${CODEX_BIN:-$(command -v codex 2>/dev/null || echo "/opt/homebrew/bin/codex")}"
  [[ -n "$agent_path" ]] || agent_path="$HOME/.local/bin:/opt/homebrew/bin:${PATH:-/usr/bin:/bin}"

  ensure_party_state_dir "$session" >/dev/null
  party_create_session "$session" "$window_name" "$session_cwd"
  party_launch_agents "$session" "$session_cwd" "$claude_bin" "$codex_bin" "$agent_path" "$claude_resume_id" "$codex_resume_id"

  party_state_upsert_manifest "$session" "$title" "$session_cwd" "$window_name" "$claude_bin" "$codex_bin" "$agent_path" || true
  party_state_set_field "$session" "last_resumed_at" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" || true

  echo "Party session '$session' resumed."
  echo "State dir: $(party_runtime_dir "$session")"
  echo "Manifest: $manifest"
  if [[ -z "$claude_resume_id" ]]; then
    echo "Note: Claude session id missing in manifest; launched fresh Claude session."
  fi
  if [[ -z "$codex_resume_id" ]]; then
    echo "Note: Codex session id missing in manifest; launched fresh Codex session."
  fi
  party_attach "$session"
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

# Parse arguments
_party_raw=""
_party_resume_claude=""
_party_resume_codex=""
_party_title=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-tpm) party_install_tpm; exit ;;
    --stop)  party_stop "${2:-}"; exit ;;
    --list)  party_list; exit ;;
    --continue|continue) party_continue "${2:-}"; exit ;;
    --help|-h) party_usage; exit ;;
    --raw)   _party_raw=1; shift ;;
    --resume-claude) _party_resume_claude="${2:?--resume-claude requires a session ID}"; shift 2 ;;
    --resume-codex)  _party_resume_codex="${2:?--resume-codex requires a session ID}"; shift 2 ;;
    --*)     party_usage >&2; exit 1 ;;
    *)       _party_title="$1"; shift ;;
  esac
done

PARTY_RAW="${_party_raw}" party_start "$_party_title" "$_party_resume_claude" "$_party_resume_codex"
