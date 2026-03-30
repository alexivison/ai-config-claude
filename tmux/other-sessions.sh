#!/bin/bash
# Show session counts in the tmux status bar.
# Party sessions: count of all party-* sessions (including current).
# Other sessions: count of non-party sessions (excluding current).
# Output: nothing if only the current session exists.

current=$(tmux display-message -p '#{session_name}' 2>/dev/null)
all_sessions=$(tmux list-sessions -F '#{session_name}' 2>/dev/null)

party_count=0
other_count=0
while IFS= read -r sid; do
    [[ -z "$sid" ]] && continue
    if [[ "$sid" == party-* ]]; then
        party_count=$((party_count + 1))
    elif [[ "$sid" != "$current" ]]; then
        other_count=$((other_count + 1))
    fi
done <<< "$all_sessions"

[[ $party_count -eq 0 && $other_count -eq 0 ]] && exit 0

output=""
[[ $party_count -gt 0 ]] && output="#[fg=#768390]⚔ ${party_count}"
[[ $other_count -gt 0 ]] && output="${output:+$output  }#[fg=#768390]◈ ${other_count}"

[[ -z "$output" ]] && exit 0
printf '#[fg=#444c56] | %s ' "$output"
