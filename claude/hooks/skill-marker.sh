#!/usr/bin/env bash
# Skill Marker Hook
# Creates markers when critical skills complete (for PR gate)
#
# Triggered: PostToolUse on Skill tool

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
SKILL=$(echo "$INPUT" | jq -r '.tool_input.skill // empty' 2>/dev/null)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)

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

# --- Marker Creation for enforced skills ---
case "$SKILL" in
  pre-pr-verification)
    touch "/tmp/claude-pr-verified-$SESSION_ID"
    ;;
esac

echo '{}'
