# Task 2 — Add Task Search

**Dependencies:** none | **Issue:** —

---

## Goal

Add case-insensitive full-text search across task titles and descriptions, with an optional tag filter. This lets consumers find tasks by keyword without scanning the entire list.

## Scope Boundary (REQUIRED)

**In scope:**
- New `searchTasks(query, options?)` function in `src/store.ts`
- Case-insensitive substring matching against `title` and `description`
- Optional `tags` filter parameter
- Re-export from `src/index.ts`
- Unit tests

**Out of scope (handled by other tasks):**
- Priority filtering (Task 1)
- Fuzzy matching or relevance scoring
- Pagination or result limiting
- Regex support
- Changes to existing functions

**Cross-task consistency check:**
- Search does not depend on priority filtering — both tasks are independent

## Reference

Files to study before implementing:

- `src/store.ts:35-37` — `getTasksByStatus()` as the filter pattern to follow
- `src/types.ts:5-13` — `Task` interface (fields to search against)
- `src/types.ts:15-20` — `CreateTaskInput` (to understand `tags` shape)

## Files to Create/Modify

| File | Action |
|------|--------|
| `src/store.ts` | Modify — add `searchTasks` function |
| `src/index.ts` | Modify — re-export `searchTasks` |
| `tests/store.test.ts` | Modify — add search test cases |

## Requirements

**Functionality:**
- `searchTasks(query)` searches `title` and `description` fields
- Matching is case-insensitive substring (not word-boundary)
- Empty query (`""`) matches all tasks
- Optional `options.tags` parameter: when provided, results must include at least one of the specified tags
- Returns `Task[]`

**Key gotchas:**
- Case-insensitive: use `toLowerCase()` on both query and target, not regex
- Tag filter is AND with text search, OR within tags (task needs at least one matching tag)
- `searchTasks('')` must return ALL tasks, not empty array

## Tests

Test cases:
- `searchTasks('deploy')` finds tasks with "deploy" in title
- `searchTasks('deploy')` finds tasks with "deploy" in description
- `searchTasks('DEPLOY')` returns same results (case-insensitive)
- `searchTasks('xyz')` returns empty array
- `searchTasks('test', { tags: ['backend'] })` filters by both text and tag
- `searchTasks('', { tags: ['frontend'] })` returns all tasks with the tag
- `searchTasks('')` returns all tasks
- Works correctly with empty store

## Acceptance Criteria

- [ ] `searchTasks('deploy')` finds tasks with "deploy" in title or description (case-insensitive)
- [ ] `searchTasks('DEPLOY')` returns same results as `searchTasks('deploy')`
- [ ] `searchTasks('xyz')` returns empty array when nothing matches
- [ ] `searchTasks('test', { tags: ['backend'] })` only returns matching tasks that also have the 'backend' tag
- [ ] `searchTasks('')` returns all tasks (empty query matches everything)
- [ ] Function is exported from `src/index.ts`
- [ ] All new code has unit tests
- [ ] All existing tests still pass
