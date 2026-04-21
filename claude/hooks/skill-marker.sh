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

# --- Preset assignment (convention: only this hook writes execution-preset) ---
# Workflow skills opt a session into a preset, which drives the PR gate
# evidence requirements. Without a preset the gate allows PR creation — the
# default is direct editing with no enforcement.
#
# Append semantics are replace-only: get_session_preset reads the last entry,
# so later workflow invocations override earlier ones without explicit merge.
declare -A SKILL_PRESETS=(
  ["task-workflow"]="task"
  ["bugfix-workflow"]="bugfix"
  ["quick-fix-workflow"]="quick"
  ["openspec-workflow"]="spec"
)

preset="${SKILL_PRESETS[$SKILL]:-}"
if [ -n "$preset" ]; then
  append_evidence "$SESSION_ID" "execution-preset" "$preset" "$CWD"
  hook_log "skill-marker" "$SESSION_ID" "preset" "skill=$SKILL preset=$preset"
fi

# --- Evidence creation for enforced skills ---
case "$SKILL" in
  pre-pr-verification)
    append_evidence "$SESSION_ID" "pr-verified" "PASS" "$CWD"
    ;;
esac

echo '{}'
