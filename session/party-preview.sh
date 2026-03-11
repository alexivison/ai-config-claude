#!/usr/bin/env bash
# party-preview.sh — fzf preview script for party switcher
set -euo pipefail

sid="$1"
manifest_root="$2"
home="$3"
f="$manifest_root/${sid}.json"

blue=$'\033[38;2;83;155;245m'
green=$'\033[38;2;87;171;90m'
dim=$'\033[38;2;99;110;123m'
fg=$'\033[38;2;173;186;199m'
reset=$'\033[0m'

if [[ ! -f "$f" ]]; then
  echo "No manifest found."
  exit 0
fi

# Session info
session_type="$(jq -r '.session_type // empty' "$f" 2>/dev/null || true)"
if tmux has-session -t "$sid" 2>/dev/null; then
  if [[ "$session_type" == "master" ]]; then
    worker_count="$(jq -r '.workers // [] | length' "$f" 2>/dev/null || echo 0)"
    echo "${blue}master${reset} ${dim}($worker_count workers)${reset}"
  else
    echo "${green}active${reset}"
  fi
else
  echo "${dim}resumable${reset}"
fi

cwd="$(jq -r '.cwd // "-"' "$f" | sed "s|$home|~|")"
echo "${dim}$cwd${reset}"
echo "${dim}$(jq -r '.last_started_at // .created_at // "-"' "$f")${reset}"

prompt="$(jq -r '.initial_prompt // empty' "$f")"
[[ -n "$prompt" ]] && echo "${green}prompt: $prompt${reset}"

cid="$(jq -r '.claude_session_id // empty' "$f")"
[[ -n "$cid" ]] && echo "${dim}claude: $cid${reset}"

tid="$(jq -r '.codex_thread_id // empty' "$f")"
[[ -n "$tid" ]] && echo "${dim}codex: $tid${reset}"

# Show last lines of Claude's pane if session is live
if tmux has-session -t "$sid" 2>/dev/null; then
  cp="$(tmux list-panes -t "$sid:0" -F '#{pane_index} #{@party_role}' 2>/dev/null | grep claude | cut -d' ' -f1)"
  if [[ -n "$cp" ]]; then
    echo ""
    echo "${blue}--- Paladin ---${reset}"
    tmux capture-pane -t "$sid:0.$cp" -p -S -500 2>/dev/null \
      | { grep -E '^[❯⏺]' || true; } \
      | { grep -vE '^[❯⏺][[:space:]]*$' || true; } \
      | tail -8 \
      | while IFS= read -r line; do
          if [[ "$line" == ❯* ]]; then
            echo "${green}${line}${reset}"
          else
            echo "${blue}${line}${reset}"
          fi
        done
  fi
fi
