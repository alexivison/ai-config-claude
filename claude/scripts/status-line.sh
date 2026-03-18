#!/usr/bin/env bash
# Write context data to a cache file for the tmux status bar widget.
# The statusLine config must remain in settings.json so Claude Code
# continues to invoke this script — it just produces no visible output.

input=$(cat)

IFS=$'\t' read -r model pct < <(echo "$input" | jq -r '[
    .model.display_name // .model.id // "?",
    .context_window.remaining_percentage // 100
] | @tsv')
pct=${pct%.*}
[[ -z "$pct" || "$pct" == "null" ]] && pct=100

# Write cache file keyed by TMUX_PANE for the tmux widget.
if [[ -n "${TMUX_PANE:-}" ]]; then
    cache_dir="/tmp/ai-context-cache"
    mkdir -p "$cache_dir" 2>/dev/null
    pane_id="${TMUX_PANE#%}"
    printf '%s\t%s\n' "$model" "$pct" > "$cache_dir/claude-$pane_id"
fi
