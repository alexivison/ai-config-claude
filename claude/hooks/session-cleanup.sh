#!/usr/bin/env bash
# Session Cleanup Hook - Removes stale marker files
# Cleans up markers older than 24 hours to prevent stale state
#
# Triggered: SessionStart

# Ensure logs dir exists (PreToolUse hooks redirect stderr here)
mkdir -p "$HOME/.claude/logs" 2>/dev/null

# Clean up evidence JSONL logs and lock files (>24h old)
find /tmp -maxdepth 1 -name "claude-evidence-*.jsonl" -mtime +1 -delete 2>/dev/null
find /tmp -maxdepth 1 -name "claude-evidence-*.lock" -mtime +1 -delete 2>/dev/null
find /tmp -maxdepth 1 -name "claude-evidence-*.lock.d" -mtime +1 -type d -exec rmdir {} \; 2>/dev/null
# Clean up stale worktree override files (used by session-id-helper.sh)
find /tmp -maxdepth 1 -name "claude-worktree-*" -mtime +1 -delete 2>/dev/null

echo '{}'
