#!/usr/bin/env bash
# review-costs.sh — Aggregate token costs from agent-trace.jsonl
# Usage: review-costs.sh [session_id]
#   session_id: filter to a specific session (default: latest session)
set -euo pipefail

TRACE_FILE="$HOME/.claude/logs/agent-trace.jsonl"

if [[ ! -f "$TRACE_FILE" ]]; then
  echo "No trace file found at $TRACE_FILE" >&2
  exit 1
fi

session_id="${1:-}"

# If no session specified, use the latest session in the trace
if [[ -z "$session_id" ]]; then
  session_id=$(tail -1 "$TRACE_FILE" | jq -r '.session // empty' 2>/dev/null)
  if [[ -z "$session_id" ]]; then
    echo "No sessions found in trace file." >&2
    exit 1
  fi
fi

echo "Review Cost Summary (session: $session_id)"
echo "────────────────────────────────────────"
printf '%-28s %s\n' "Agent" "Tokens"
echo "─────                        ──────"

total=0
# Aggregate tokens by agent type within the session
while IFS=$'\t' read -r agent tokens; do
  [[ -z "$agent" ]] && continue
  tokens=${tokens:-0}
  [[ "$tokens" =~ ^[0-9]+$ ]] || tokens=0
  printf '%-28s %d\n' "$agent" "$tokens"
  total=$((total + tokens))
done < <(jq -sr --arg sid "$session_id" \
  '[.[] | select(.session == $sid)] | group_by(.agent) | map({agent: .[0].agent, tokens: (map(.tokens // 0) | add)}) | sort_by(.agent) | .[] | [.agent, .tokens] | @tsv' \
  "$TRACE_FILE" 2>/dev/null)

echo "────────────────────────────────────────"
printf '%-28s %d\n' "Total" "$total"
echo ""
echo "Codex: tracked separately by Codex CLI"
