# Task 2 — Simplify PR Gate

**Dependencies:** Task 1 | **Issue:** N/A (phase-simplification)

---

## Goal

Make `claude/hooks/pr-gate.sh` the one hard enforcement point for the full review workflow by requiring the current-hash evidence set every time, with no phase-2 exception and no `codex-ran` fallback logic.

## Scope Boundary (REQUIRED)

**In scope:**
- Full-tier requirement calculation in `claude/hooks/pr-gate.sh`
- Preservation of docs-only bypass behavior
- Preservation of quick-tier authorization and size limits
- Preservation of stale-evidence diagnostics from `check_all_evidence()`
- `claude/hooks/tests/test-pr-gate.sh` updates for the simplified rule

**Out of scope (handled by other tasks):**
- Codex hook simplification and `codex-ran` retirement mechanics
- Cross-hash critic oscillation detection
- Rule-doc wording changes

**Cross-task consistency check:**
- This task assumes Task 1 has already removed `codex-ran`; do not leave dead reads of that type behind in the PR gate.
- Task 4 must update `execution-core.md` so the documented PR gate matches the new full-tier behavior.

## Reference

Files to study before implementing:

- `claude/hooks/pr-gate.sh:31-52` — docs-only bypass to preserve
- `claude/hooks/pr-gate.sh:54-68` — quick-tier logic to preserve
- `claude/hooks/pr-gate.sh:69-89` — phase-2 relaxation path to remove
- `claude/hooks/lib/evidence.sh:276-320` — current-hash evidence checks and stale diagnostics
- `claude/hooks/tests/test-pr-gate.sh:157-271` — full-gate and phase-2 tests to simplify

## Design References (REQUIRED for UI/component tasks)

N/A (non-UI task)

## Data Transformation Checklist (REQUIRED for shape changes)

This task changes internal gate requirements, not external request/response shapes.

- [ ] Full tier always resolves to `pr-verified code-critic minimizer codex test-runner check-runner`
- [ ] Quick tier still requires explicit `quick-tier` evidence plus size limits
- [ ] Docs-only detection remains a complete bypass for non-implementation diffs
- [ ] Missing-evidence diagnostics still report stale current-hash evidence when applicable
- [ ] No branch of the PR gate checks `codex-ran` or any phase state

## Files to Create/Modify

| File | Action |
|------|--------|
| `claude/hooks/pr-gate.sh` | Modify |
| `claude/hooks/tests/test-pr-gate.sh` | Modify |

## Requirements

**Functionality:**
- Replace the phase-2 branch with a single full-tier requirement set whenever quick tier is not explicitly authorized.
- Keep quick tier behavior exactly as-is: explicit `quick-tier` evidence, size-gated at `<=30` lines, `<=3` files, `0` new files.
- Keep docs-only bypass exactly as-is for non-implementation diffs.
- Continue surfacing stale-evidence diagnostics from `check_all_evidence()`.
- Update tests to remove the old "critics at old hash + codex at current hash" success case and assert that full tier always requires current-hash critic evidence.

**Key gotchas:**
- Do not accidentally let small diffs skip full review without `quick-tier` evidence.
- The PR gate is only for `gh pr create`; do not widen the command matcher while simplifying the logic.
- The simplification is meant to reduce code, not to replace the removed phase block with a new abstraction layer.

## Tests

Test cases:
- Docs-only PR still bypasses evidence requirements
- Quick tier still passes only with explicit `quick-tier` evidence and size-compliant diff
- Small diffs without `quick-tier` evidence still require the full evidence set
- Full gate passes only when all evidence exists at the current hash
- Full gate rejects stale evidence after a new commit
- Old phase-2 success path is gone

Verification commands:
- `bash claude/hooks/tests/test-pr-gate.sh`

## Acceptance Criteria

- [ ] `claude/hooks/pr-gate.sh` no longer reads or reasons about `codex-ran`
- [ ] Full tier always requires all six evidence types at the current hash
- [ ] Quick tier and docs-only bypass remain unchanged
- [ ] `claude/hooks/tests/test-pr-gate.sh` has no phase-2 allowance case
- [ ] All Task 2 verification commands pass
