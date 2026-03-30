# Planning-Agnostic Harness Specification

## Problem Statement

- `task-workflow` still treats TASK artifacts as native engine input. Its pre-implementation gate locates `PLAN.md` and reads scope from the TASK file before any work begins (`claude/skills/task-workflow/SKILL.md:20-25`).
- The same skill assumes TASK-native completion and audit semantics: it updates TASK/PLAN checkboxes, compares the diff against TASK scope, and passes `task_file` directly to `scribe` (`claude/skills/task-workflow/SKILL.md:39-46`, `claude/skills/task-workflow/SKILL.md:84-94`).
- `scribe` is hard-coded to `task_file` and extracts requirements by reading TASK sections itself (`claude/agents/scribe.md:11-27`, `claude/agents/scribe.md:29-52`).
- `execution-core` uses TASK-native language for scope and optional scribe activation even though its real strength is elsewhere: review ordering, evidence freshness, dispute resolution, and PR enforcement (`claude/rules/execution-core.md:9-10`, `claude/rules/execution-core.md:40`, `claude/rules/execution-core.md:97-98`, `claude/rules/execution-core.md:122`).
- `plan-workflow` only knows how to create classic artifacts and still describes `task-workflow` as executing TASK files directly (`claude/skills/plan-workflow/SKILL.md:59-74`, `claude/skills/plan-workflow/SKILL.md:196-208`, `claude/skills/plan-workflow/SKILL.md:229-233`).
- The true harness strengths are already planning-agnostic. `pr-gate.sh` and `evidence.sh` gate code changes by diff, evidence, and workflow completion, not by planning format (`claude/hooks/pr-gate.sh:30-89`, `claude/hooks/lib/evidence.sh:99-123`).

## Goal

The harness shall become a planning-agnostic execution engine that consumes a minimal provider-produced `work_packet` and preserves its existing review, evidence, and PR-gate protections regardless of planning source.

## User Experience

| Scenario | User Action | Expected Result |
|----------|-------------|-----------------|
| Classic provider | Invoke work using a TASK file through the classic provider | The provider emits `scope`, `requirements`, and `goal`, and the unchanged execution spine runs without treating TASK files as engine-native |
| OpenSpec provider | Invoke work using `change_dir=<openspec/changes/<slug>>` and `task_id=<n.m>` through the OpenSpec provider | The provider extracts the same `work_packet`, and `task-workflow`/`scribe` run without caring that the source was OpenSpec |
| Future provider | Add a new planning source that can emit the minimal `work_packet` | The engine can reuse the same execution governance without new TASK-specific logic |
| Invalid provider payload | Provider omits scope, requirements, or goal | The engine fails closed before implementation rather than guessing |
| OpenSpec archive attempt | Try to archive before work has actually landed | Archive is denied unless fresh harness evidence exists and the associated PR is merged |

## Acceptance Criteria

- [ ] The harness defines a minimal `work_packet` contract with `scope`, `requirements`, and `goal`
- [ ] `task-workflow` consumes `work_packet` and no longer reads TASK/PLAN files directly for execution gating or completion tracking
- [ ] `scribe` consumes pre-extracted requirements text plus scope text instead of `task_file`
- [ ] Classic TASK semantics are preserved by a baseline provider rather than by engine-native assumptions
- [ ] OpenSpec is implemented as the first non-classic provider that emits the same `work_packet`
- [ ] `execution-core`, critic ordering, dispute resolution, evidence freshness, and PR gating remain the same enforcement spine
- [ ] Providers missing any required `work_packet` field fail closed before implementation begins
- [ ] The engine does not mandate checkbox/completion sync as part of its contract
- [ ] OpenSpec archive is gated behind fresh harness evidence plus merged-PR completion proof
- [ ] The evidence policy for provider-owned planning files is explicit and regression-tested

## Non-Goals

- Rewriting the critic/Codex/sentinel/evidence/PR-gate spine.
- Auto-detecting provider type from repo contents or threading provider conditionals through every workflow.
- Adding providers beyond classic TASK and OpenSpec in this landing.
- Rewriting OpenSpec's own proposal/spec/design/task formats.
- Making human-readable completion tracking a required field or gate of the engine.
- Universal worker-dispatch support for every provider in this landing.

## Technical Reference

Implementation details, provider contracts, and task breakdown live in [DESIGN.md](./DESIGN.md).
