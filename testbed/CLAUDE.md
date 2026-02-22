# workflow-testbed

A TypeScript task-management library used to test and iterate on Claude Code workflows.

## Commands

- **Tests:** `npm test` (vitest)
- **Lint:** `npm run lint` (eslint)
- **Typecheck:** `npm run typecheck` (tsc --noEmit)
- **Build:** `npm run build` (tsc)

## Project Structure

```
src/
  types.ts       — Type definitions (Task, Priority, Status, input types)
  validators.ts  — Input validation for create/update operations
  store.ts       — In-memory task store with CRUD operations
  formatters.ts  — Text formatting for task display
  index.ts       — Public API re-exports
tests/
  *.test.ts      — Unit tests (vitest)
tasks/
  TASK-*.md      — Feature task definitions
  BUGFIX-*.md    — Bug report definitions
```

## Conventions

- All new public functions must be exported from `src/index.ts`
- Tests go in `tests/` with `.test.ts` suffix
- Validation logic lives in `src/validators.ts`, not in store functions
- Store functions call validators and throw on validation errors
