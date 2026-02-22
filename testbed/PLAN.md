# Workflow Testbed Implementation Plan

> **Goal:** Extend a TypeScript task-management library with priority filtering, search, and validation fixes.
>
> **Architecture:** In-memory store (`Map<string, Task>`) with validation layer. All new functions follow the existing filter pattern (`getTasksByStatus`). Validation fixes go in `validators.ts`.
>
> **Tech Stack:** TypeScript, Vitest, ESLint

## Scope

Three independent changes to the task-management library. No cross-task dependencies — each task produces one PR, independently mergeable.

## Task Granularity

- [x] **Standard** — ~200 lines of implementation (tests excluded), split if >5 files (default)
- [ ] **Atomic** — 2-5 minute steps with checkpoints (for high-risk: auth, payments, migrations)

## Tasks

- [ ] [Task 1](./tasks/TASK1-add-priority-filter.md) — Add priority filtering functions (deps: none)
- [ ] [Task 2](./tasks/TASK2-add-search.md) — Add full-text search with optional tag filter (deps: none)
- [ ] [Task 3](./tasks/BUGFIX1-whitespace-title.md) — Fix whitespace-only title validation bypass (deps: none)

## Dependency Graph

```
Task 1 (priority filter)     independent
Task 2 (search)              independent
Task 3 (bugfix)              independent
```

All tasks are independent — no ordering constraints.

## Task Handoff State

| After Task | State |
|------------|-------|
| Task 1 | Priority filtering works, tests pass |
| Task 2 | Search works, tests pass |
| Task 3 | Validation bug fixed, regression tests pass |

## External Dependencies

None — self-contained library with no external services.

## Definition of Done

- [ ] All task checkboxes complete
- [ ] `npm test` passes
- [ ] `npm run typecheck` passes
- [ ] `npm run lint` passes
