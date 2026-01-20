#!/bin/bash

# Claude Code worktree guard hook
# Blocks branch switching/creation in main worktree, suggests git worktree instead

INPUT=$(cat)
if ! COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null); then
    exit 0
fi

[ -z "$COMMAND" ] && exit 0

# Check for branch switching/creation commands
if ! echo "$COMMAND" | grep -qE 'git\s+(checkout|switch)'; then
    exit 0
fi

# Allow file checkouts (git checkout -- file, git checkout HEAD file)
if echo "$COMMAND" | grep -qE 'git\s+checkout\s+(--\s+|HEAD\s+|[^-][^ ]*\.[a-zA-Z])'; then
    exit 0
fi

# Allow switching to main/master
if echo "$COMMAND" | grep -qE 'git\s+(checkout|switch)\s+(main|master)\s*$'; then
    exit 0
fi

# Get working directory
WORKING_DIR=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$WORKING_DIR" ] && WORKING_DIR=$(pwd)

# Allow if already in a worktree (not the main worktree)
cd "$WORKING_DIR" 2>/dev/null || exit 0
if git rev-parse --is-inside-work-tree &>/dev/null; then
    MAIN_WORKTREE=$(git worktree list --porcelain | grep -m1 '^worktree ' | cut -d' ' -f2)
    GIT_ROOT=$(git rev-parse --show-toplevel)

    # If current dir is not the main worktree, allow the operation
    if [ "$GIT_ROOT" != "$MAIN_WORKTREE" ]; then
        exit 0
    fi
fi

# Block with helpful message
REPO_NAME=$(basename "$GIT_ROOT" 2>/dev/null || echo "repo")
cat >&2 << EOF
BLOCKED: Branch switching in main worktree.

Use git worktree instead:
  git worktree add ../${REPO_NAME}-<branch-name> -b <branch-name>
  cd ../${REPO_NAME}-<branch-name>

This prevents conflicts when multiple agents work on the same repo.
EOF

exit 2
