# Task 1 — Add Priority Filtering

**Dependencies:** none | **Issue:** —

---

## Goal

Add the ability to filter tasks by priority level, including range-based filtering (e.g., "all tasks at high priority or above"). This gives consumers a way to retrieve urgent work without manual iteration.

## Scope Boundary (REQUIRED)

**In scope:**
- New `getTasksByPriority(priority)` function in `src/store.ts`
- New `getTasksByMinPriority(minPriority)` function in `src/store.ts`
- Priority ordering constant: `low` < `medium` < `high` < `critical`
- Re-export both functions from `src/index.ts`
- Unit tests for both functions

**Out of scope (handled by other tasks):**
- Search functionality (Task 2)
- Sorting within results
- Changes to existing functions or the `Priority` type
- UI, API, or CLI

**Cross-task consistency check:**
- Priority ordering constant may be reused by Task 2 for relevance sorting — keep it exported if created as a separate helper

## Reference

Files to study before implementing:

- `src/store.ts:35-37` — `getTasksByStatus()` as the pattern to follow for filter functions
- `src/types.ts:1` — `Priority` type definition
- `src/index.ts` — current exports to extend

## Files to Create/Modify

| File | Action |
|------|--------|
| `src/store.ts` | Modify — add `getTasksByPriority`, `getTasksByMinPriority` |
| `src/index.ts` | Modify — re-export new functions |
| `tests/store.test.ts` | Modify — add test cases |

## Requirements

**Functionality:**
- `getTasksByPriority(priority)` returns tasks matching the exact priority
- `getTasksByMinPriority(minPriority)` returns tasks at or above the given level
- Priority ordering: `low` (0) < `medium` (1) < `high` (2) < `critical` (3)

**Key gotchas:**
- The ordering must be a single source of truth (array or map), not scattered comparisons
- `getTasksByMinPriority('low')` must return ALL tasks (lowest threshold)

## Tests

Test cases:
- `getTasksByPriority('high')` returns only high-priority tasks
- `getTasksByPriority('low')` returns only low-priority tasks
- `getTasksByMinPriority('high')` returns high + critical
- `getTasksByMinPriority('low')` returns all tasks
- `getTasksByMinPriority('critical')` returns only critical tasks
- Both return empty array when no tasks match
- Both work correctly with empty store

## Acceptance Criteria

- [ ] `getTasksByPriority('high')` returns only tasks with `priority === 'high'`
- [ ] `getTasksByMinPriority('high')` returns tasks with priority `high` or `critical`
- [ ] `getTasksByMinPriority('low')` returns all tasks
- [ ] `getTasksByMinPriority('critical')` returns only critical tasks
- [ ] Both functions return empty array when no tasks match
- [ ] Both functions are exported from `src/index.ts`
- [ ] All new code has unit tests
- [ ] All existing tests still pass
