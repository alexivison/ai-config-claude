# Task 2 - Refactor Task Workflow To Consume Work Packet

**Dependencies:** Task 1 | **Issue:** TBD

---

## Goal

Refactor `task-workflow` into a true execution engine. After this task, it should consume `work_packet` and build all review context from scope, requirements, and goal instead of reading TASK/PLAN files directly. Human-readable status updates are no longer engine behavior; if a provider wants them, that happens outside the engine after the governed execution path completes.

## Scope Boundary (REQUIRED)

**In scope:**
- Replace TASK-native preflight reads with `work_packet` validation
- Replace TASK-native minimality/review prompt inputs with `work_packet.scope` and `work_packet.goal`
- Pass `work_packet.requirements` and generic scope text to `scribe`
- Remove engine-owned checkbox/completion behavior from workflow and execution-core wording
- Preserve the existing review, evidence, and PR-gate spine

**Out of scope (handled by other tasks):**
- Refactoring `scribe` itself beyond the inputs `task-workflow` passes
- Implementing the OpenSpec provider
- Archive gating and evidence-policy changes

**Cross-task consistency check:**
- Task 2 must consume Task 1's contract without adding provider-specific fields
- Task 4 must plug OpenSpec in by emitting the same packet, not by adding a second engine path
- Task 6 may change provider-owned planning-file policy, but must not reintroduce engine-owned checkbox logic

## Reference

Files to study before implementing:

- `claude/skills/task-workflow/SKILL.md:20` - current preflight contract
- `claude/skills/task-workflow/SKILL.md:39` - current checkbox and scribe assumptions
- `claude/rules/execution-core.md:9` - canonical execution sequence
- `claude/rules/execution-core.md:122` - current TASK-native scope enforcement

## Design References (REQUIRED for UI/component tasks)

N/A (non-UI task)

## Data Transformation Checklist (REQUIRED for shape changes)

- [ ] Proto definition (N/A)
- [ ] Proto -> Domain converter (N/A)
- [ ] Domain model struct for engine-consumable `work_packet`
- [ ] Params struct(s) for baseline provider input
- [ ] Params conversion functions from baseline provider input to `work_packet`
- [ ] Any adapters between `work_packet.goal` and review/PR context prompts

## Files to Create/Modify

| File | Action |
|------|--------|
| `claude/skills/task-workflow/SKILL.md` | Modify |
| `claude/skills/task-workflow/providers/classic-task.md` | Create |
| `claude/rules/execution-core.md` | Modify |
| `claude/hooks/tests/test-provider-routing.sh` | Modify |

## Requirements

**Functionality:**
- `task-workflow` consumes `work_packet` instead of TASK-native sections
- Minimality and review prompts use `work_packet.scope`
- Review and PR context use `work_packet.goal`
- `scribe` receives `work_packet.requirements` and generic scope text
- The engine no longer owns checkbox/completion behavior
- The review/evidence/PR spine remains unchanged in principle

**Key gotchas:**
- Do not fork the execution flow by provider
- Do not keep hidden TASK-native reads in side notes or examples
- Do not reintroduce completion tracking through optional engine steps

## Tests

Test cases:
- Classic provider emits a packet that preserves today's scope/requirements behavior
- Missing `work_packet` fields fail before implementation
- Review prompts use generic scope and goal wording
- Engine docs no longer require checkbox sync

Verification commands:
- `bash claude/hooks/tests/test-provider-routing.sh`
- `rg -n "work_packet|requirements|goal|checkbox|PLAN\\.md|TASK\\*\\.md" claude/skills/task-workflow/SKILL.md claude/skills/task-workflow/providers/classic-task.md claude/rules/execution-core.md`

## Acceptance Criteria

- [ ] `task-workflow` consumes `work_packet` and generic review context
- [ ] The engine no longer owns checkbox/completion behavior
- [ ] No second execution path is introduced for non-classic providers
