#!/bin/bash
# PreToolUse hook: remind to run verification sub-agents before pushing.
# Non-blocking (exit 0) — serves as a nudge, not a gate.

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

[[ "$command" != *"git push"* ]] && exit 0

cat <<'MSG'
Reminder: have you run the check-runner and test-runner sub-agents for the affected service? If the changes warrant it, run them before pushing.
MSG
exit 0
