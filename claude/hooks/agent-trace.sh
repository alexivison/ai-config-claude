#!/usr/bin/env bash
# Agent Observability Hook
# Logs sub-agent invocations to ~/.claude/logs/agent-trace.jsonl
#
# Triggered: PostToolUse on Agent tool
# Input: JSON via stdin with tool_name, tool_input, tool_response

set -e

TRACE_FILE="$HOME/.claude/logs/agent-trace.jsonl"
mkdir -p "$(dirname "$TRACE_FILE")"

# Read hook input from stdin
hook_input=$(cat)

# Validate JSON input
if ! echo "$hook_input" | jq -e . >/dev/null 2>&1; then
  echo '{"error": "Invalid JSON input"}' >> "$HOME/.claude/logs/hook-errors.log" 2>/dev/null
  exit 0
fi

# Extract fields with error handling
tool_name=$(echo "$hook_input" | jq -r '.tool_name // empty' 2>/dev/null)
if [ -z "$tool_name" ]; then
  exit 0
fi

# Only process Agent tool (sub-agent invocations)
if [ "$tool_name" != "Agent" ]; then
  exit 0
fi

# Extract agent details from tool_input
agent_type=$(echo "$hook_input" | jq -r '.tool_input.subagent_type // "unknown"')
description=$(echo "$hook_input" | jq -r '.tool_input.description // ""')
model=$(echo "$hook_input" | jq -r '.tool_input.model // "inherit"')

# Extract text from tool_response for verdict detection.
# tool_response may be a plain string OR a JSON array of content blocks:
#   [{"type":"text","text":"...verdict..."},{"type":"text","text":"agentId: ..."}]
# Handle both formats, then strip metadata before scanning.
response_type=$(echo "$hook_input" | jq -r '.tool_response | type' 2>/dev/null)
if [ "$response_type" = "array" ]; then
  # Array of content blocks — extract text from objects and pass strings through.
  # Type-safe: handles mixed arrays (objects, strings, nulls) without failing under set -e.
  full_response=$(echo "$hook_input" | jq -r '[.tool_response[]? | if type=="object" then (.text // empty) elif type=="string" then . else empty end] | join("\n")' 2>/dev/null)
else
  full_response=$(echo "$hook_input" | jq -r '.tool_response // ""' 2>/dev/null)
fi

# Strip trailing metadata (agentId line, <usage> block) that pushes verdicts out of range.
# Use anchored patterns to avoid eating legitimate content mid-response.
cleaned_response=$(echo "$full_response" | sed -E '/^[[:space:]]*agentId:/d' | sed '/<usage>total_tokens:/,/<\/usage>/d')
# Scanning only the last 1000 chars reduces false positives from "APPROVE" in prose.
verdict_region=$(echo "$cleaned_response" | tail -c 1000)
verdict="unknown"
if echo "$verdict_region" | grep -qE '\*\*REQUEST_CHANGES\*\*|^REQUEST_CHANGES'; then
  verdict="REQUEST_CHANGES"
elif echo "$verdict_region" | grep -qE '\*\*NEEDS_DISCUSSION\*\*|^NEEDS_DISCUSSION'; then
  verdict="NEEDS_DISCUSSION"
elif echo "$verdict_region" | grep -qE '\*\*APPROVE\*\*|^APPROVE'; then
  verdict="APPROVED"
elif echo "$verdict_region" | grep -qi "SKIP"; then
  verdict="SKIP"
elif echo "$verdict_region" | grep -qiE '\bCRITICAL\b|\bHIGH\b'; then
  verdict="ISSUES_FOUND"
elif echo "$verdict_region" | grep -qiE '\bFAIL\b'; then
  verdict="FAIL"
elif echo "$verdict_region" | grep -qiE '\bPASS\b'; then
  verdict="PASS"
elif echo "$verdict_region" | grep -qiE '\bCLEAN\b'; then
  verdict="CLEAN"
elif echo "$verdict_region" | grep -qi "complete\|done\|finished"; then
  verdict="COMPLETED"
fi

# Fallback: scan full cleaned response when verdict_region missed it.
# Short agent responses (e.g. minimizer APPROVE with no findings) can be
# lost when content-block extraction produces unexpected output in parallel.
if [ "$verdict" = "unknown" ] && [ -n "$cleaned_response" ]; then
  if echo "$cleaned_response" | grep -qE '\*\*REQUEST_CHANGES\*\*|^REQUEST_CHANGES'; then
    verdict="REQUEST_CHANGES"
  elif echo "$cleaned_response" | grep -qE '\*\*NEEDS_DISCUSSION\*\*|^NEEDS_DISCUSSION'; then
    verdict="NEEDS_DISCUSSION"
  elif echo "$cleaned_response" | grep -qE '\*\*APPROVE\*\*|^APPROVE'; then
    verdict="APPROVED"
  elif echo "$cleaned_response" | grep -qiE '\bFAIL\b'; then
    verdict="FAIL"
  elif echo "$cleaned_response" | grep -qiE '\bPASS\b'; then
    verdict="PASS"
  fi
fi

# Get session info
session_id=$(echo "$hook_input" | jq -r '.session_id // "unknown"')
cwd=$(echo "$hook_input" | jq -r '.cwd // ""')
project=$(basename "$cwd")

# Create trace entry
timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

trace_entry=$(jq -cn \
  --arg ts "$timestamp" \
  --arg session "$session_id" \
  --arg project "$project" \
  --arg agent "$agent_type" \
  --arg desc "$description" \
  --arg model "$model" \
  --arg verdict "$verdict" \
  '{
    timestamp: $ts,
    session: $session,
    project: $project,
    agent: $agent,
    description: $desc,
    model: $model,
    verdict: $verdict
  }')

# Append to trace file
echo "$trace_entry" >> "$TRACE_FILE"

# One-line evidence log for quick grep debugging
echo "$timestamp | $agent_type | $verdict | $session_id" >> "$HOME/.claude/logs/evidence-trace.log"

# Create markers for PR gate enforcement
# Each marker proves a workflow step was completed

# code-critic: only APPROVE creates marker (must pass before PR)
if [ "$agent_type" = "code-critic" ] && [ "$verdict" = "APPROVED" ]; then
  touch "/tmp/claude-code-critic-$session_id"
fi

# minimizer: only APPROVE creates marker (must pass before PR)
if [ "$agent_type" = "minimizer" ] && [ "$verdict" = "APPROVED" ]; then
  touch "/tmp/claude-minimizer-$session_id"
fi

# test-runner: only PASS creates marker
if [ "$agent_type" = "test-runner" ] && [ "$verdict" = "PASS" ]; then
  touch "/tmp/claude-tests-passed-$session_id"
fi

# check-runner: only PASS or CLEAN creates marker
if [ "$agent_type" = "check-runner" ]; then
  if [ "$verdict" = "PASS" ] || [ "$verdict" = "CLEAN" ]; then
    touch "/tmp/claude-checks-passed-$session_id"
  fi
fi

exit 0
