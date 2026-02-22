# workflow-testbed

Testbed for iterating on Claude Code task and bugfix workflows. Run a task, create a PR, tweak the workflow, reset, repeat. Compare PRs across runs to measure improvement.

## Prerequisites

- [ai-config](https://github.com/alexivison/ai-config) installed (`./install.sh` creates `~/.claude` symlinks)
- Node.js 20+
- Claude Code CLI

## Setup

```bash
git clone git@github.com:alexivison/workflow-testbed.git
cd workflow-testbed
npm install
npm test          # verify baseline passes
```

## Available Tasks

All tasks are independent — run them in parallel across separate Claude sessions.

| Task | Workflow | What It Tests |
|------|----------|---------------|
| [TASK1](tasks/TASK1-add-priority-filter.md) | `/task-workflow` | Simple feature addition — filter by priority |
| [TASK2](tasks/TASK2-add-search.md) | `/task-workflow` | Medium feature — full-text search with options |
| [BUGFIX1](tasks/BUGFIX1-whitespace-title.md) | `/bugfix-workflow` | Bug investigation + regression test + fix |

## Test-Compare Workflow

### Run N

1. Start on `main` (clean state)
2. Open Claude Code in the repo
3. Tell Claude to execute a task:
   ```
   Execute /task-workflow on tasks/TASK1-add-priority-filter.md
   ```
   or for the bugfix:
   ```
   Execute /bugfix-workflow on tasks/BUGFIX1-whitespace-title.md
   ```
4. Claude creates a worktree, implements, reviews, and opens a PR
5. Export the session for review

### Between Runs

1. Review the PR diff and session transcript
2. Identify what to improve (workflow, CLAUDE.md, skills, agents, rules)
3. Make changes in `ai-config`
4. Merge or close the PR
5. Reset any worktrees: `git worktree prune`

### Run N+1

1. Back to `main` — same starting point
2. Run the same task again
3. Compare the new PR to the previous one

### What to Compare

| Dimension | What to Look For |
|-----------|-----------------|
| **Diff quality** | Clean, minimal, does exactly what's asked |
| **Test quality** | Meaningful tests, edge cases covered |
| **Workflow adherence** | Followed steps? Updated PLAN.md checkboxes? |
| **Review efficiency** | How many critic/codex loops? Correct triage? |
| **Minimalism** | No over-engineering, no unasked-for changes |
| **Context usage** | Stayed within scope boundaries? |

## Project Structure

```
src/
  types.ts       — Type definitions
  validators.ts  — Input validation (has a planted bug)
  store.ts       — In-memory CRUD store
  formatters.ts  — Text formatting
  index.ts       — Public API
tests/
  *.test.ts      — Unit tests (baseline passing)
tasks/
  TASK*.md       — Feature tasks
  BUGFIX*.md     — Bug reports
```

## Commands

```bash
npm test          # run tests (vitest)
npm run lint      # lint (eslint)
npm run typecheck # type check (tsc --noEmit)
npm run build     # compile (tsc)
```
