#!/usr/bin/env bash
# Context window widget for tmux status bar.
# Displays Claude and Codex context-remaining percentages.
#
# Usage (in tmux.conf):
#   #(~/Code/ai-config/tmux/context-status.sh)
#
# Data sources:
#   Claude — cache file written by status-line.sh (/tmp/ai-context-cache/claude-<pane>)
#   Codex  — scraped from the Codex TUI footer via tmux capture-pane

CACHE_DIR="/tmp/ai-context-cache"
ICON_CLAUDE=$(printf '\U000F0510')   # nf-md-shield_sword (paladin)
ICON_CODEX=$(printf '\U000F0D02')    # nf-md-wizard_hat

# Color thresholds (tmux #[fg=...] style)
color_for_pct() {
    local pct="$1"
    if [[ $pct -le 5 ]]; then
        echo "#e5534b"   # red
    elif [[ $pct -le 15 ]]; then
        echo "#daaa3f"   # yellow
    else
        echo "#57ab5a"   # green
    fi
}

# ── Claude ──────────────────────────────────────────────────────────────────
claude_context() {
    # Find the Claude pane in the current window via @party_role metadata.
    local pane_id
    pane_id=$(tmux list-panes -F '#{pane_id} #{@party_role}' 2>/dev/null \
        | awk '$2 == "claude" { print $1; exit }')
    [[ -z "$pane_id" ]] && return

    local cache_file="$CACHE_DIR/claude-${pane_id#%}"
    [[ -f "$cache_file" ]] || return

    # Stale check: ignore if older than 60s
    local now file_age
    now=$(date +%s)
    file_age=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null) || return
    (( now - file_age > 60 )) && return

    local model pct
    IFS=$'\t' read -r model pct < "$cache_file"
    [[ -z "$pct" ]] && return

    local c
    c=$(color_for_pct "$pct")
    printf '#[fg=#539bf5,bold]%s #[fg=#768390,nobold]%s #[fg=%s,bold]%s%%#[fg=#636e7b,nobold]' \
        "$ICON_CLAUDE" "$model" "$c" "$pct"
}

# ── Codex ───────────────────────────────────────────────────────────────────
codex_context() {
    # Find the Codex pane in the current window.
    local pane_id
    pane_id=$(tmux list-panes -F '#{pane_id} #{@party_role}' 2>/dev/null \
        | awk '$2 == "codex" { print $1; exit }')
    [[ -z "$pane_id" ]] && return

    # Capture the last 5 lines of the Codex pane (footer lives at the bottom).
    local captured
    captured=$(tmux capture-pane -t "$pane_id" -p -S -5 2>/dev/null) || return

    # The Codex status line contains a percentage like "85%" for context remaining.
    # Match patterns: "XX% context", "XX% remaining", or bare "XX%" near known items.
    local pct
    pct=$(echo "$captured" | grep -oE '[0-9]+%' | tail -1)
    pct="${pct%\%}"
    [[ -z "$pct" || "$pct" -gt 100 ]] 2>/dev/null && return

    local c
    c=$(color_for_pct "$pct")
    printf '#[fg=#daaa3f,bold]%s #[fg=%s,bold]%s%%#[fg=#636e7b,nobold]' \
        "$ICON_CODEX" "$c" "$pct"
}

# ── Assemble ────────────────────────────────────────────────────────────────
parts=()

claude_out=$(claude_context)
[[ -n "$claude_out" ]] && parts+=("$claude_out")

codex_out=$(codex_context)
[[ -n "$codex_out" ]] && parts+=("$codex_out")

# Nothing to show outside party sessions
[[ ${#parts[@]} -eq 0 ]] && exit 0

# Join with dim separator
sep="#[fg=#636e7b] · "
result=""
for i in "${!parts[@]}"; do
    [[ $i -gt 0 ]] && result+="$sep"
    result+="${parts[$i]}"
done

printf '%s ' "$result"
