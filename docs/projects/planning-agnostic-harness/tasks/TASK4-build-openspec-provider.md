# Task 4 - Build OpenSpec Provider

**Dependencies:** Task 1, Task 2, Task 3 | **Issue:** TBD

---

## Goal

Implement OpenSpec as the first non-classic planning provider. This task should prove the architecture is real rather than decorative: OpenSpec resolves into the same `work_packet` the engine already expects, and the engine remains indifferent to the planning format once that packet exists. Any OpenSpec task-state updates remain provider-side behavior outside the engine contract.

## Scope Boundary (REQUIRED)

**In scope:**
- Define how OpenSpec provider input resolves into `work_packet.scope`, `work_packet.requirements`, and `work_packet.goal`
- Map OpenSpec artifacts (`proposal.md`, `specs/`, `design.md`, `tasks.md`) into the generic provider contract
- Extract plain-text requirements and one-line goal text before the engine invokes `scribe`
- Wire the OpenSpec provider into the generic `task-workflow` entry path without changing the execution spine
- Add provider-specific regression coverage proving OpenSpec resolves the same packet shape as the classic baseline

**Out of scope (handled by other tasks):**
- OpenSpec archive gating and post-merge archive behavior
- Provider-owned planning-file evidence policy
- Adding providers beyond OpenSpec
- Engine-owned OpenSpec task-state sync

**Cross-task consistency check:**
- Task 4 must not add new engine-native fields beyond Task 1's `work_packet`
- Task 5 may add OpenSpec-specific archive handling, but must not reintroduce planning-format logic into the engine core

## Reference

Files to study before implementing:

- `claude/skills/task-workflow/provider-interface.md` - generic provider contract from Task 1
- `claude/skills/task-workflow/providers/classic-task.md` - baseline provider behavior from Task 2
- `claude/agents/scribe.md:11` - format-blind `scribe` contract after Task 3
- `claude/skills/task-workflow/SKILL.md:20` - generic engine preflight after Task 2

## Design References (REQUIRED for UI/component tasks)

N/A (non-UI task)

## Data Transformation Checklist (REQUIRED for shape changes)

- [ ] Proto definition (N/A)
- [ ] Proto -> Domain converter (N/A)
- [ ] Domain model struct for OpenSpec provider input
- [ ] Params struct(s) for `change_dir + task_id`
- [ ] Params conversion functions from OpenSpec artifacts to `work_packet`
- [ ] Any adapters between OpenSpec artifacts and plain-text requirement extraction

## Files to Create/Modify

| File | Action |
|------|--------|
| `claude/skills/task-workflow/providers/openspec.md` | Create |
| `claude/skills/task-workflow/SKILL.md` | Modify |
| `claude/hooks/tests/test-provider-routing.sh` | Modify |

## Requirements

**Functionality:**
- OpenSpec provider accepts `change_dir + task_id`
- OpenSpec provider resolves `scope`, `requirements`, and `goal` without inventing extra engine-native fields
- Requirements handed to the engine are already plain text; `scribe` does not need to know OpenSpec exists
- The resolved packet is consumable by the generic `task-workflow` and generic `scribe` contracts from Tasks 2 and 3
- Missing required OpenSpec artifacts fail closed before implementation starts

**Key gotchas:**
- Do not let OpenSpec-specific prose leak into generic engine contracts
- Do not weaken the provider contract just because OpenSpec tasks are lighter than classic TASK files
- Do not sneak provider-side task-state sync back into the engine contract

## Tests

Test cases:
- OpenSpec provider resolves a complete `work_packet`
- Missing OpenSpec artifact fails loudly instead of producing a partial packet
- OpenSpec requirements are handed off as plain text, not file refs
- Generic engine path is unchanged after provider resolution

Verification commands:
- `bash claude/hooks/tests/test-provider-routing.sh`
- `rg -n "work_packet|change_dir|task_id|proposal.md|specs/|design.md|tasks.md|requirements|goal" claude/skills/task-workflow/providers/openspec.md claude/skills/task-workflow/SKILL.md`

## Acceptance Criteria

- [ ] OpenSpec provider emits a valid `work_packet`
- [ ] Generic engine and `scribe` contracts consume the packet without new planning-format branches
- [ ] Missing OpenSpec inputs fail closed rather than degrading into partial execution
