#!/usr/bin/env bash
# Git status widget for tmux status bar (GitHub Dark Dimmed palette)
cd "$1" 2>/dev/null || exit 0

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || exit 0

[[ ${#BRANCH} -gt 25 ]] && BRANCH="${BRANCH:0:25}…"

ICON_BRANCH=$(printf '\U000F062C')
ICON_PLUS=$(printf '\uf457')
ICON_MINUS=$(printf '\uf458')
ICON_QUESTION=$(printf '\uf128')

CHANGED="" INSERTIONS="" DELETIONS="" UNTRACKED=""

STATUS=$(git status --porcelain 2>/dev/null | grep -cE "^(M| M)")
if [[ $STATUS -ne 0 ]]; then
  read -r C I D <<< "$(git diff --numstat 2>/dev/null | awk 'NF==3 {c+=1; i+=$1; d+=$2} END {printf("%d %d %d", c, i, d)}')"
  [[ $C -gt 0 ]] && CHANGED="#[fg=#daaa3f,bg=#343b45,bold] ${C} "
  [[ $I -gt 0 ]] && INSERTIONS="#[fg=#57ab5a,bg=#343b45,bold] ${ICON_PLUS} ${I} "
  [[ $D -gt 0 ]] && DELETIONS="#[fg=#e5534b,bg=#343b45,bold] ${ICON_MINUS} ${D} "
fi

U=$(git ls-files --other --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
[[ $U -gt 0 ]] && UNTRACKED="#[fg=#636e7b,bg=#343b45,bold] ${ICON_QUESTION} ${U} "

# Pill-shaped segment matching SketchyBar theme
BAR_BG="#22272e"
PILL_BG="#343b45"
echo "#[fg=${PILL_BG},bg=${BAR_BG}]#[fg=#768390,bg=${PILL_BG}] ${ICON_BRANCH} $BRANCH ${CHANGED}${INSERTIONS}${DELETIONS}${UNTRACKED}#[fg=${PILL_BG},bg=${BAR_BG}]"
