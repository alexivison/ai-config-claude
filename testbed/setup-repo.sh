#!/usr/bin/env bash
# Extract the testbed into a standalone GitHub repo.
#
# Usage:
#   ./setup-repo.sh [target-dir]
#
# Example:
#   ./setup-repo.sh ~/Code/workflow-testbed
#
# This will:
#   1. Copy all testbed files to the target directory
#   2. Initialize a git repo with a main branch
#   3. Install dependencies
#   4. Run tests to verify
#   5. Create the GitHub repo and push (requires gh CLI)

set -euo pipefail

TARGET="${1:-$HOME/Code/workflow-testbed}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -d "$TARGET/.git" ]; then
  echo "Error: $TARGET already exists and is a git repo."
  echo "Remove it first or pick a different target."
  exit 1
fi

echo "==> Creating standalone repo at $TARGET"
mkdir -p "$TARGET"

# Copy everything except this script, node_modules, and dist
rsync -a --exclude=setup-repo.sh --exclude=node_modules --exclude=dist "$SCRIPT_DIR/" "$TARGET/"

cd "$TARGET"

echo "==> Initializing git repo"
git init -b main
git add -A

echo "==> Installing dependencies"
npm install

echo "==> Running verification"
npm test
npm run typecheck
npm run lint

echo "==> Creating initial commit"
git add -A
git commit -m "Initial testbed: TypeScript task library with workflow tasks

A task-management library designed for iterating on Claude Code
task-workflow and bugfix-workflow skills. Includes 3 independent tasks
(2 features, 1 bugfix), full test/lint/type infrastructure."

echo ""
echo "==> Done! Repo ready at $TARGET"
echo ""
echo "To push to GitHub:"
echo "  cd $TARGET"
echo "  gh repo create alexivison/workflow-testbed --public --source=. --push"
echo ""
echo "Then run tasks with:"
echo "  claude 'Execute /task-workflow on tasks/TASK1-add-priority-filter.md'"
