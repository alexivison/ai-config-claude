# Task 4 — Sync Execution Core And Verify

**Dependencies:** Task 1, Task 2, Task 3 | **Issue:** N/A (phase-simplification)

---

## Goal

Bring `claude/rules/execution-core.md` into alignment with the simplified hook behavior and prove the combined hook stack still passes its integrated regression suite once the phase language is gone.

## Scope Boundary (REQUIRED)

**In scope:**
- `claude/rules/execution-core.md` updates for single-phase enforcement
- Removal of phase-1/phase-2 language from evidence, governance, and violation sections
- Explicit statement that workflow skills, not hooks, enforce critic-to-Codex sequencing
- Addition of cross-hash oscillation language alongside the existing same-hash rule
- Skill doc updates to remove phase references: `claude/skills/codex-transport/SKILL.md`, `claude/skills/task-workflow/SKILL.md`, `claude/skills/tmux-handler/SKILL.md`
- Final integrated hook verification commands

**Out of scope (handled by other tasks):**
- Hook code changes themselves
- New workflow-skill implementation work beyond the documentation contract
- Changes to `claude/hooks/lib/evidence.sh`

**Cross-task consistency check:**
- This task must be the last one because the rule doc should describe the landed hook behavior, not the old model or a hypothetical future state.
- If Tasks 1-3 change header comments or naming, the rule doc wording should match those final terms exactly to avoid policy drift.

## Reference

Files to study before implementing:

- `claude/rules/execution-core.md:5-13` — core sequence already shows critics before Codex
- `claude/rules/execution-core.md:44-50` — phase-based evidence description to replace
- `claude/rules/execution-core.md:69-76` — review-governance caps that still name phases
- `claude/rules/execution-core.md:81-98` — decision-matrix rows that still rely on phase 2
- `claude/rules/execution-core.md:135-157` — PR gate and violation patterns that still mention `codex-ran` and first-review blocking
- `claude/hooks/codex-gate.sh:33-54` — target Codex gate behavior after Task 1
- `claude/hooks/pr-gate.sh:54-105` — target PR gate behavior after Task 2
- `claude/hooks/agent-trace-stop.sh:119-148` — oscillation behavior to document after Task 3
- `claude/hooks/tests/run-all.sh:1-24` — integrated hook test runner to use for final verification

## Design References (REQUIRED for UI/component tasks)

N/A (non-UI task)

## Data Transformation Checklist (REQUIRED for shape changes)

N/A (documentation and verification task)

## Files to Create/Modify

| File | Action |
|------|--------|
| `claude/rules/execution-core.md` | Modify |
| `claude/skills/codex-transport/SKILL.md` | Modify — remove phase 1/2 language, `codex-ran` references (lines 51, 76-78, 109-112) |
| `claude/skills/task-workflow/SKILL.md` | Modify — remove "phase 2 gate" reference (line 59) |
| `claude/skills/tmux-handler/SKILL.md` | Modify — remove "re-run critics" instruction for REQUEST_CHANGES (line 75) |

## Requirements

**Functionality:**
- Remove all phase-1/phase-2 language from `execution-core.md`.
- Update the Evidence System section to describe hooks as evidence recorders plus final PR enforcement, with workflow skills owning sequencing.
- Update the Codex gate description to "only blocks `--approve`".
- Update Review Governance caps and Decision Matrix rows so they no longer talk about phase-specific critic or Codex rounds.
- Remove the violation pattern that says first Codex review without critic evidence is hook-blocked.
- Add cross-hash oscillation detection beside the existing same-hash oscillation description.
- Run the integrated hook suite after the doc sync so the written contract and live behavior are proven together.

**Key gotchas:**
- The core sequence at the top of the file already encodes critic-before-Codex ordering; the rewrite should preserve that sequencing while making clear that hooks trust the workflow.
- Remove phase references in one sweep or the document will contradict itself across sections.
- The final regression step matters because code edits in Tasks 1-3 invalidate any earlier verification evidence.

## Tests

Test cases:
- The rule doc contains no stale phase-1/phase-2 instructions for hooks
- Hook suite still passes after all simplifications
- Search for removed terms does not leave live policy contradictions

Verification commands:
- `bash claude/hooks/tests/run-all.sh`
- `rg -n 'phase 1|phase 2|codex-ran|first codex review without critic evidence' claude/hooks claude/rules/execution-core.md claude/skills/codex-transport/SKILL.md claude/skills/task-workflow/SKILL.md claude/skills/tmux-handler/SKILL.md`

## Acceptance Criteria

- [ ] `claude/rules/execution-core.md` describes a single-phase evidence model
- [ ] Sequencing responsibility is explicitly assigned to workflow skills
- [ ] Cross-hash oscillation is documented alongside same-hash oscillation
- [ ] No stale phase language remains in the rule doc, live hook comments, or workflow skill docs
- [ ] All Task 4 verification commands pass
