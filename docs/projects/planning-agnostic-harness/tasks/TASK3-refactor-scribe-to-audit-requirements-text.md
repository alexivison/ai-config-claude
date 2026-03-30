# Task 3 - Refactor Scribe To Audit Requirements Text

**Dependencies:** Task 1 | **Issue:** TBD

---

## Goal

Make `scribe` truly format-blind. It should receive plain-text requirements and scope in its prompt, plus the diff and tests. It should not read planning files, infer formats, or know whether the source was a TASK file, OpenSpec, or something yet unborn.

## Scope Boundary (REQUIRED)

**In scope:**
- Replace the `task_file`-only input contract with `scope`, `requirements`, `diff_scope`, and `test_files`
- Remove `scribe`'s requirement-extraction phase from planning files
- Preserve verdict labels, coverage-matrix format, and final verdict contract
- Update the caller contract so `task-workflow` passes pre-extracted requirements text

**Out of scope (handled by other tasks):**
- Refactoring other critics
- Implementing the OpenSpec provider
- Archive gating and provider-owned evidence policy

**Cross-task consistency check:**
- Task 2 must pass packet-derived text inputs, not provider-native raw files
- Task 4 must prove a non-classic provider can satisfy the same `scribe` contract without changing the audit format

## Reference

Files to study before implementing:

- `claude/agents/scribe.md:11` - current TASK-file-only input contract
- `claude/agents/scribe.md:21` - current requirement extraction rules
- `claude/agents/scribe.md:48` - current scope audit rules
- `claude/skills/task-workflow/SKILL.md:45` - current scribe invocation expectations

## Design References (REQUIRED for UI/component tasks)

N/A (non-UI task)

## Data Transformation Checklist (REQUIRED for shape changes)

- [ ] Proto definition (N/A)
- [ ] Proto -> Domain converter (N/A)
- [ ] Domain model struct for `scribe` prompt inputs
- [ ] Params struct(s) for packet-derived text inputs
- [ ] Params conversion functions from `work_packet` to `scribe` prompt text
- [ ] Any adapters between pre-extracted requirement lines and the existing coverage matrix

## Files to Create/Modify

| File | Action |
|------|--------|
| `claude/agents/scribe.md` | Modify |
| `claude/skills/task-workflow/SKILL.md` | Modify |
| `claude/hooks/tests/test-provider-routing.sh` | Modify |

## Requirements

**Functionality:**
- `scribe` accepts `scope`, `requirements`, `diff_scope`, and `test_files`
- `scribe` audits against the requirement text it was given instead of reading planning files
- `scribe` uses generic scope text for out-of-scope findings
- Output remains compatible with the harness's existing review-trace parsing

**Key gotchas:**
- Do not make `scribe` reverse-engineer planning formats from raw docs
- Do not break the exact verdict line contract the hooks rely on

## Tests

Test cases:
- Baseline classic provider still yields the same audit shape
- Pre-extracted requirements text yields a stable numbered requirement list
- Missing requirements fail loudly instead of auditing partial context
- Out-of-scope checks use generic scope text, not TASK-native section names

Verification commands:
- `bash claude/hooks/tests/test-provider-routing.sh`
- `rg -n "requirements|task_file|scope|Out of Scope|coverage matrix" claude/agents/scribe.md claude/skills/task-workflow/SKILL.md`

## Acceptance Criteria

- [ ] `scribe` consumes plain-text requirements and generic scope context
- [ ] Verdict and coverage-matrix output stay stable for the rest of the harness
- [ ] `scribe` has no file-path or format knowledge in its input contract
