# Task 4 — Update Documentation And Complete Verification

**Dependencies:** Task 3 | **Issue:** NOISSUE

---

## Goal

Align user-facing docs with the new 3-pane default and role-based routing model, then run full verification and capture evidence for review.

## Scope Boundary (REQUIRED)

**In scope:**
- Update usage docs to describe pane order and role-driven routing.
- Add operator notes for fallback expectations.
- Execute full test suite and a minimal manual tmux smoke check.

**Out of scope (handled by other tasks):**
- New runtime behavior implementation.
- Hook policy or gate changes.

**Cross-task consistency check:**
- Documentation must match actual launch/routing behavior delivered by Tasks 2 and 3.

## Reference

- `README.md:73` — current two-pane description
- `README.md:79` — current left/right role description
- `tests/run-tests.sh:28` — verification entrypoint (suite registration)

## Data Transformation Checklist (REQUIRED for shape changes)

No new runtime data shapes are introduced in this task. Validation focus is behavioral/documentation parity.

## Files to Create/Modify

| File | Action |
|------|--------|
| `README.md` | Modify |
| `plans/NOISSUE-tmux-pane-role-routing/PLAN.md` | Update checklist statuses if needed |

## Requirements

**Functionality:**
- README describes default pane roles as `0=Codex`, `1=Claude`, `2=Shell`.
- README notes that transport scripts route by role metadata, not fixed pane index.
- Verification evidence includes automated tests and one manual send check.

**Key gotchas:**
- Keep docs faithful to actual script behavior.
- Avoid stale references to “left pane/right pane” assumptions.

## Tests

Test cases:
- Full repository shell test suite passes.
- Manual Claude→Codex and Codex→Claude message send succeeds in a reordered pane scenario.

Verification commands:

```bash
bash tests/run-tests.sh
./session/party.sh --raw
# manual: swap panes, then run both transport scripts and confirm delivery
```

## Acceptance Criteria

- [ ] Docs reflect implemented behavior.
- [ ] Automated verification passes.
- [ ] Manual routing smoke check passes.
