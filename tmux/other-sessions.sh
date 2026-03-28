#!/bin/bash
# Show active party sessions in the tmux status bar.
# Displays other party-* sessions (not the current one) with titles
# from manifests when available, falling back to short IDs.
# Output: nothing if no other sessions, otherwise styled session list.

current=$(tmux display-message -p '#{session_name}' 2>/dev/null)
others=$(tmux list-sessions -F '#{session_name}' 2>/dev/null \
    | grep '^party-' | grep -v "^${current}$")

[[ -z "$others" ]] && exit 0

state_root="${PARTY_STATE_ROOT:-$HOME/.party-state}"
parts=()
while IFS= read -r sid; do
    [[ -z "$sid" ]] && continue
    label=""
    manifest="$state_root/$sid.json"
    if [[ -f "$manifest" ]] && command -v jq >/dev/null 2>&1; then
        title=$(jq -r '.title // empty' "$manifest" 2>/dev/null)
        stype=$(jq -r '.session_type // empty' "$manifest" 2>/dev/null)
        if [[ -n "$title" ]]; then
            label="$title"
        else
            label="${sid##party-}"
            # Truncate long timestamps to last 6 chars
            [[ ${#label} -gt 6 ]] && label="${label: -6}"
        fi
        [[ "$stype" == "master" ]] && label="$label*"
    else
        label="${sid##party-}"
        [[ ${#label} -gt 6 ]] && label="${label: -6}"
    fi
    parts+=("$label")
done <<< "$others"

[[ ${#parts[@]} -eq 0 ]] && exit 0

# Count includes current session if it's a party session
total=${#parts[@]}
[[ "$current" == party-* ]] && total=$((total + 1))

list=$(IFS='·'; echo "${parts[*]}")
printf '#[fg=#444c56] | #[fg=#768390]⚔ %d  %s ' "$total" "$list"
