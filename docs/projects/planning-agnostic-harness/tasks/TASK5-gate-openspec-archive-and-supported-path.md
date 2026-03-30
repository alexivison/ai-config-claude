# Task 5 - Gate OpenSpec Archive And Supported Path

**Dependencies:** Task 4 | **Issue:** TBD

---

## Goal

Add the OpenSpec-specific post-execution behavior on top of the generic provider model. OpenSpec is not special inside the engine, but it does have an archive step, so this task must gate that step honestly and document the blessed execution path without pretending the current hook surface can block every unsupported slash command in existence.

## Scope Boundary (REQUIRED)

**In scope:**
- Add an OpenSpec archive gate that requires fresh harness evidence plus merged-PR proof
- Document the blessed OpenSpec execution path through provider resolution into `task-workflow`
- Mark stock `/opsx:apply` as unsupported for harnessed execution and state the residual bypass risk honestly
- Keep archive behavior provider-specific instead of leaking it into the generic engine
- Make clear that archive decisions do not depend on checkbox state or planning-file completion markers

**Out of scope (handled by other tasks):**
- Generic archive behavior for every future provider
- Provider-owned planning-file evidence policy
- Rewriting PR-gate semantics

**Cross-task consistency check:**
- Task 5 must use the OpenSpec provider from Task 4 rather than introducing a second OpenSpec execution path
- Task 6 may adjust provider-owned planning-file policy, but must not weaken archive proof requirements

## Reference

Files to study before implementing:

- `claude/hooks/pr-gate.sh:30` - current PR-create interception logic
- `claude/hooks/lib/evidence.sh:185` - evidence append/check helpers
- `claude/settings.json:84` - current hook surface
- `claude/skills/task-workflow/providers/openspec.md` - OpenSpec provider contract from Task 4
- `gh pr view --help` - merged PR state lookup contract

## Design References (REQUIRED for UI/component tasks)

N/A (non-UI task)

## Data Transformation Checklist (REQUIRED for shape changes)

- [ ] Proto definition (N/A)
- [ ] Proto -> Domain converter (N/A)
- [ ] Domain model struct for OpenSpec archive decision inputs
- [ ] Params struct(s) for archive attempts and OpenSpec change/PR refs
- [ ] Params conversion functions from archive request to merged-proof/evidence checks
- [ ] Any adapters between OpenSpec change ids and the harness session/evidence model

## Files to Create/Modify

| File | Action |
|------|--------|
| `claude/hooks/archive-gate.sh` | Create |
| `claude/hooks/tests/test-archive-gate.sh` | Create |
| `claude/settings.json` | Modify |
| `claude/skills/task-workflow/providers/openspec.md` | Modify |
| `claude/skills/task-workflow/SKILL.md` | Modify |

## Requirements

**Functionality:**
- OpenSpec archive is denied unless fresh harness evidence exists and the associated PR is merged
- The deny path reports concrete missing markers or missing merged-PR proof
- The blessed OpenSpec path routes through provider resolution into generic `task-workflow`
- Stock `/opsx:apply` is documented as unsupported, and the residual bypass risk is explicit
- Archive gating does not depend on checkbox state or provider-side human-readable status

**Key gotchas:**
- Do not claim impossible hard-blocking for arbitrary third-party slash commands
- Do not make archive semantics generic when only OpenSpec needs them in this landing

## Tests

Test cases:
- Archive denied when required evidence is missing
- Archive denied when evidence is fresh but the associated PR is not merged
- Archive allowed when evidence is fresh and the associated PR is merged
- Guidance text routes execution through the provider model rather than around it

Verification commands:
- `bash claude/hooks/tests/test-archive-gate.sh`
- `bash claude/hooks/tests/test-pr-gate.sh`
- `gh pr view --json state,mergedAt`
- `rg -n "archive|opsx:apply|merged|provider|work_packet|checkbox" claude/hooks/archive-gate.sh claude/skills/task-workflow/providers/openspec.md claude/skills/task-workflow/SKILL.md`

## Acceptance Criteria

- [ ] OpenSpec archive is gated by fresh evidence plus merged-PR proof
- [ ] The blessed OpenSpec path is documented through the provider model
- [ ] Unsupported-path risk is stated honestly instead of hidden behind fiction
- [ ] Archive gating is independent of checkbox state
