# Task 1 - Define Work-Packet Interface

**Dependencies:** none | **Issue:** TBD

---

## Goal

Define the generic planning-provider contract before touching engine behavior. The execution engine does not need a planning format; it needs a `work_packet` with scope text, requirement text, and a one-line goal. This task makes that contract explicit, removes engine-owned completion tracking from the contract entirely, and recasts classic TASK semantics as the baseline provider instead of the engine's native language.

## Scope Boundary (REQUIRED)

**In scope:**
- Define the minimal `work_packet` contract: `scope`, `requirements`, and `goal`
- Define fail-closed validation when any required field is missing
- Define the provider responsibility as `resolve(provider_input) -> work_packet`
- Map existing classic TASK semantics into baseline provider terms
- State explicitly that provider-side human-readable status updates are optional and outside engine semantics

**Out of scope (handled by other tasks):**
- Refactoring `task-workflow` to consume the new contract
- Refactoring `scribe` to consume plain-text requirements
- Implementing the OpenSpec provider
- Archive gating and evidence-policy changes

**Cross-task consistency check:**
- Tasks 2-6 must consume this contract rather than inventing provider-specific engine fields
- The contract must stay minimal; do not smuggle planning-format details back into the engine
- Missing any required field must fail closed before implementation starts

## Reference

Files to study before implementing:

- `claude/skills/task-workflow/SKILL.md:20` - current TASK-native preflight assumptions
- `claude/skills/task-workflow/SKILL.md:39` - current checkbox/completion assumptions
- `claude/agents/scribe.md:11` - current TASK-file-only audit contract
- `claude/rules/execution-core.md:40` - current TASK-native scope language

## Design References (REQUIRED for UI/component tasks)

N/A (non-UI task)

## Data Transformation Checklist (REQUIRED for shape changes)

- [ ] Proto definition (N/A)
- [ ] Proto -> Domain converter (N/A)
- [ ] Domain model struct for `work_packet`
- [ ] Params struct(s) for provider input
- [ ] Params conversion functions from provider input to `work_packet`
- [ ] Any adapters between provider-native artifacts and plain-text requirement/goal extraction

## Files to Create/Modify

| File | Action |
|------|--------|
| `claude/skills/task-workflow/provider-interface.md` | Create |
| `claude/skills/task-workflow/SKILL.md` | Modify |
| `claude/rules/execution-core.md` | Modify |
| `claude/hooks/tests/test-provider-routing.sh` | Create |

## Requirements

**Functionality:**
- Define a `work_packet` with `scope`, `requirements`, and `goal`
- Define provider responsibility as resolving provider-native input into that packet
- Express current classic TASK semantics as the baseline provider over that contract
- Remove engine-owned completion tracking from the contract

**Key gotchas:**
- Do not let TASK-file vocabulary survive as the engine's canonical language
- Do not make the contract so abstract that the first real provider cannot implement it
- Do not reintroduce completion tracking through a renamed field

## Tests

Test cases:
- Docs state the four required text fields clearly
- Classic TASK semantics are mapped as a provider, not as engine-native behavior
- Missing `scope`, `requirements`, or `goal` is documented as fail-closed
- No repo/provider auto-detection is introduced

Verification commands:
- `bash claude/hooks/tests/test-provider-routing.sh`
- `rg -n "work_packet|scope|requirements|goal|provider" claude/skills/task-workflow/provider-interface.md claude/skills/task-workflow/SKILL.md claude/rules/execution-core.md`

## Acceptance Criteria

- [ ] The harness documents a minimal `work_packet` contract and provider responsibilities
- [ ] Classic TASK semantics are expressed as the baseline provider
- [ ] Completion tracking is explicitly outside the engine contract
- [ ] Missing required packet fields fail closed rather than degrading into guesswork
