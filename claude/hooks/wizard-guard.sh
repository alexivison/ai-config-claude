#!/usr/bin/env bash
# wizard-guard.sh — Block direct tmux interaction with the Wizard.
# Forces Claude to use party-cli transport for all Wizard communication.
set -euo pipefail

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[ -n "$CMD" ] || exit 0

DENY_MSG="BLOCKED: Do not interact with the Wizard directly via tmux. Use party-cli transport instead (review, prompt, plan-review). The CLI handles pane/window resolution."

deny() {
  jq -nc --arg reason "$DENY_MSG" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
  exit 0
}

# Check whether any segment of a pipeline references a Wizard/codex target.
has_wizard_ref() {
  [[ "$1" =~ (codex|[Ww]izard) ]]
}

# Check whether a segment contains a dangerous tmux subcommand.
has_tmux_subcmd() {
  [[ "$1" =~ tmux[[:space:]].*(capture-pane|list-panes|send-keys|select-pane|select-window|swap-pane) ]]
}

# Block: tmux subcommand with Wizard/codex in the same segment,
# OR tmux subcommand piped into grep/rg filtering for Wizard/codex.
IFS='|' read -ra SEGMENTS <<< "$CMD"
for i in "${!SEGMENTS[@]}"; do
  seg="${SEGMENTS[$i]}"
  if has_tmux_subcmd "$seg" && has_wizard_ref "$seg"; then
    deny
  fi
  # Catch "tmux list-panes | grep Wizard" patterns: tmux subcmd in
  # segment i, Wizard/codex ref in a later grep/rg segment.
  if has_tmux_subcmd "$seg"; then
    for (( j=i+1; j<${#SEGMENTS[@]}; j++ )); do
      later="${SEGMENTS[$j]}"
      if [[ "$later" =~ (grep|rg) ]] && has_wizard_ref "$later"; then
        deny
      fi
    done
  fi
done

exit 0
