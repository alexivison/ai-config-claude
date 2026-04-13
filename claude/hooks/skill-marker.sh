#!/usr/bin/env bash
# Skill Marker Hook
# Creates evidence when critical skills complete (for PR gate)
#
# Triggered: PostToolUse on Skill tool

source "$(dirname "$0")/lib/evidence.sh"

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
SKILL=$(echo "$INPUT" | jq -r '.tool_input.skill // empty' 2>/dev/null)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)

# Fail silently if we can't parse
if [ -z "$SESSION_ID" ]; then
  echo '{}'
  exit 0
fi

# Only process Skill tool
if [ "$TOOL" != "Skill" ]; then
  echo '{}'
  exit 0
fi

# --- Tier assignment (convention: only this hook writes execution-tier) ---
# Workflow skills set the PR gate tier. Utility skills (pre-pr-verification,
# write-tests, etc.) are not listed and leave the current tier unchanged.
declare -A SKILL_TIERS=(
  ["openspec-workflow"]="ci-gate"
  ["task-workflow"]="full"
  ["bugfix-workflow"]="full"
  ["quick-fix-workflow"]="full"
)

tier="${SKILL_TIERS[$SKILL]:-}"
if [ -n "$tier" ]; then
  append_evidence "$SESSION_ID" "execution-tier" "$tier" "$CWD"
  hook_log "skill-marker" "$SESSION_ID" "tier" "skill=$SKILL tier=$tier"
fi

# --- Evidence creation for enforced skills ---
case "$SKILL" in
  pre-pr-verification)
    append_evidence "$SESSION_ID" "pr-verified" "PASS" "$CWD"
    ;;
esac

echo '{}'
