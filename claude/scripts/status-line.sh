#!/usr/bin/env bash

# Color codes
C_RESET='\033[0m'
C_GRAY='\033[38;5;245m'
C_YELLOW='\033[38;5;178m'
C_RED='\033[38;5;167m'
C_GREEN='\033[38;5;71m'

input=$(cat)

IFS=$'\t' read -r model pct < <(echo "$input" | jq -r '[
    .model.display_name // .model.id // "?",
    .context_window.remaining_percentage // 100
] | @tsv')
pct=${pct%.*}
[[ -z "$pct" || "$pct" == "null" ]] && pct=100

if [[ $pct -le 5 ]]; then
    C=$C_RED
elif [[ $pct -le 15 ]]; then
    C=$C_YELLOW
else
    C=$C_GREEN
fi

C_BLUE='\033[38;5;74m'
printf '%b\n' "${C_BLUE}${model}${C_GRAY} | ${C}${pct}%${C_GRAY} context remaining${C_RESET}"
