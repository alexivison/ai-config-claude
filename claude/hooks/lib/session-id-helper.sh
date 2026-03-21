#!/usr/bin/env bash
# session-id-helper.sh — Discover the current Claude Code session ID
#
# The session_id is a runtime UUID injected into hook JSON input. Claude (the agent)
# cannot access it directly. This helper finds it from evidence artifacts.
#
# Strategies (in priority order):
# 1. Party state file (CLAUDE_PARTY_SESSION env var)
# 2. Most recent worktree override matching cwd's git repo root
# 3. Most recent evidence file with worktree override matching cwd's repo root
#
# Usage:
#   source "$(dirname "$0")/lib/session-id-helper.sh"
#   sid=$(discover_session_id)
#   # or from CLI:
#   bash ~/.claude/hooks/lib/session-id-helper.sh [cwd]

discover_session_id() {
  local cwd="${1:-$(pwd)}"

  # Strategy 1: Check party state file (most reliable in party sessions)
  if [ -n "${CLAUDE_PARTY_SESSION:-}" ]; then
    local state_root="${PARTY_STATE_ROOT:-$HOME/.party-state}"
    local state_file="${state_root}/${CLAUDE_PARTY_SESSION}.json"
    if [ -f "$state_file" ]; then
      local sid
      sid=$(jq -r '.claude_session_id // empty' "$state_file" 2>/dev/null)
      if [ -n "$sid" ]; then
        echo "$sid"
        return 0
      fi
    fi
  fi

  # Strategy 2: Find the most recent worktree override whose repo root matches ours
  local cwd_repo_root
  cwd_repo_root=$(cd "$cwd" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) || true

  local newest_override_sid="" newest_override_ts=0
  if [ -n "$cwd_repo_root" ]; then
    for f in /tmp/claude-worktree-*; do
      [ -f "$f" ] || continue
      local override_path
      override_path=$(cat "$f")
      if [ -n "$override_path" ] && [ -d "$override_path" ]; then
        local override_root
        override_root=$(cd "$override_path" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) || continue
        if [ "$override_root" = "$cwd_repo_root" ]; then
          local mtime
          mtime=$(stat -f '%m' "$f" 2>/dev/null || stat -c '%Y' "$f" 2>/dev/null || echo 0)
          if [ "$mtime" -gt "$newest_override_ts" ]; then
            newest_override_sid="${f#/tmp/claude-worktree-}"
            newest_override_ts="$mtime"
          fi
        fi
      fi
    done
  fi

  if [ -n "$newest_override_sid" ]; then
    echo "$newest_override_sid"
    return 0
  fi

  # Strategy 3: Find evidence files and match by repo
  local repo_root
  repo_root=$(cd "$cwd" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) || return 1

  local newest_sid="" newest_ts=0
  for f in /tmp/claude-evidence-*.jsonl; do
    [ -f "$f" ] || continue
    # Check if any entry references our repo (via cwd in _resolve_cwd)
    local sid="${f#/tmp/claude-evidence-}"
    sid="${sid%.jsonl}"
    # Verify this session's worktree override relates to our repo
    local override="/tmp/claude-worktree-${sid}"
    if [ -f "$override" ]; then
      local op
      op=$(cat "$override")
      if [ -n "$op" ] && [ -d "$op" ]; then
        local op_root
        op_root=$(cd "$op" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) || continue
        if [ "$op_root" = "$repo_root" ]; then
          local mtime
          mtime=$(stat -f '%m' "$f" 2>/dev/null || stat -c '%Y' "$f" 2>/dev/null || echo 0)
          if [ "$mtime" -gt "$newest_ts" ]; then
            newest_sid="$sid"
            newest_ts="$mtime"
          fi
        fi
      fi
    fi
  done

  if [ -n "$newest_sid" ]; then
    echo "$newest_sid"
    return 0
  fi

  return 1
}

# CLI mode: print session ID when run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  sid=$(discover_session_id "${1:-}")
  if [ -n "$sid" ]; then
    echo "$sid"
  else
    echo "ERROR: Could not discover session ID for ${1:-$(pwd)}" >&2
    exit 1
  fi
fi
