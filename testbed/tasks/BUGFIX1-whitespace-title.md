# Task 3 — Fix Whitespace-Only Title Validation Bypass

**Dependencies:** none | **Issue:** BUGFIX-001

---

## Goal

Fix validation so that whitespace-only strings are rejected as task titles. Currently, strings like `"   "` or `"\t\n"` pass the "title is required" check, creating tasks that appear blank in listings.

## Scope Boundary (REQUIRED)

**In scope:**
- Fix `validateCreateInput()` in `src/validators.ts` to reject whitespace-only titles
- Fix `validateUpdateInput()` in `src/validators.ts` to reject whitespace-only titles on update
- Regression tests proving the fix

**Out of scope (handled by other tasks):**
- Description validation (whitespace-only descriptions are acceptable)
- Priority filtering (Task 1)
- Search (Task 2)
- Changes to store logic or types

**Cross-task consistency check:**
- No other tasks depend on or interact with title validation

## Reference

Files to study before implementing:

- `src/validators.ts:10-12` — current `validateCreateInput` title check (the bug)
- `src/validators.ts:37-39` — current `validateUpdateInput` title check (same bug)
- `tests/validators.test.ts` — existing test coverage

## Files to Create/Modify

| File | Action |
|------|--------|
| `src/validators.ts` | Modify — fix title validation in both functions |
| `tests/validators.test.ts` | Modify — add regression tests |

## Requirements

**Functionality:**
- `validateCreateInput({ title: '   ' })` must return `['Title is required']`
- `validateUpdateInput({ title: '   ' })` must return a title validation error
- `validateCreateInput({ title: '\t\n' })` must return `['Title is required']`
- Titles with leading/trailing whitespace but non-whitespace content (e.g., `' hello '`) remain valid

**Key gotchas:**
- The current check `!input.title` catches `""`, `null`, `undefined` but NOT `"   "` (whitespace-only)
- The fix should use `.trim()` to normalize before checking
- `validateUpdateInput` has a different pattern — it checks `title !== undefined` to allow partial updates. The fix must not break partial updates (omitting title entirely must still be valid)

## Tests

Test cases:
- `createTask({ title: '   ' })` throws validation error
- `createTask({ title: '\t\t' })` throws validation error
- `createTask({ title: ' \n ' })` throws validation error
- `createTask({ title: ' hello ' })` succeeds (has non-whitespace content)
- `updateTask(id, { title: '   ' })` throws validation error
- `updateTask(id, {})` still succeeds (title omitted = no change)
- All existing tests still pass

## Acceptance Criteria

- [ ] `createTask({ title: '   ' })` throws "Title is required" validation error
- [ ] `createTask({ title: '\t\n' })` throws "Title is required" validation error
- [ ] `createTask({ title: ' valid ' })` succeeds (has content after trim)
- [ ] `updateTask(id, { title: '   ' })` throws validation error
- [ ] `updateTask(id, {})` still succeeds (partial update without title)
- [ ] Regression tests cover all whitespace variants
- [ ] All existing tests still pass
