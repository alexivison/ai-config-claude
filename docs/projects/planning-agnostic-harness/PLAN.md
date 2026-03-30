# Planning-Agnostic Harness Implementation Plan

> **Goal:** Extract a truly minimal planning-provider interface so the harness can govern execution the same way regardless of where work was planned.
>
> **Architecture:** The execution engine consumes a provider-produced `work_packet` with only four fields: `scope.in_scope`, `scope.out_of_scope`, `requirements`, and `goal`. `classic-task` becomes the baseline provider that preserves today's TASK-based planning inputs, and `openspec` becomes the first non-classic provider that proves the engine no longer cares about planning format. Critics, Codex, sentinel, dispute resolution, evidence freshness, and PR gating remain the harness spine; provider-side human-readable status updates, if any, live outside the engine.
>
> **Tech Stack:** Markdown skills, Bash hooks, `jq`, `git`, JSONL evidence, provider-backed planning sources
>
> **Specification:** [SPEC.md](./SPEC.md) | **Design:** [DESIGN.md](./DESIGN.md)

## Scope

This plan extracts the execution contract from TASK-specific assumptions in `claude/skills/task-workflow/SKILL.md`, `claude/agents/scribe.md`, `claude/rules/execution-core.md`, and `claude/skills/plan-workflow/SKILL.md`, while keeping `claude/hooks/pr-gate.sh` and `claude/hooks/lib/evidence.sh` as the unchanged enforcement spine.

What this plan covers:
- Define a generic provider contract and minimal `work_packet`
- Refactor `task-workflow` to consume `scope`, `requirements`, and `goal` instead of TASK/PLAN files
- Refactor `scribe` to receive pre-extracted requirements text in its prompt
- Recast classic TASK semantics as the baseline provider
- Implement OpenSpec as the first non-classic provider
- Add OpenSpec-specific archive gating and supported-path guidance
- Finalize provider-owned evidence policy and workflow docs

Out of scope:
- rewriting the critic/Codex/sentinel/evidence/PR-gate execution spine
- auto-detecting planning systems or threading provider conditionals through every skill
- adding providers beyond classic TASK and OpenSpec in this landing
- rewriting OpenSpec itself or inventing a new OpenSpec schema
- making human-readable completion tracking a required field or gate of the engine
- universal worker-dispatch support for every provider in this landing

## Task Granularity

- [x] **Standard** - each task owns one engine seam, provider seam, or policy seam and should fit a normal PR
- [ ] **Atomic** - not used; the main risk is contract extraction, not minute-by-minute edits

## Tasks

### Core Engine

- [ ] [Task 1](./tasks/TASK1-define-work-packet-interface.md) - Define the generic provider contract and minimal `work_packet` (`scope`, `requirements`, `goal`) with classic TASK semantics mapped as the baseline provider (deps: none)
- [ ] [Task 2](./tasks/TASK2-refactor-task-workflow-to-consume-work-packet.md) - Refactor `task-workflow` to consume `work_packet`, remove engine-owned checkbox/completion behavior, and build review context from scope plus goal (deps: Task 1)
- [ ] [Task 3](./tasks/TASK3-refactor-scribe-to-audit-requirements-text.md) - Refactor `scribe` to audit pre-extracted requirements text plus scope text instead of reading planning files itself (deps: Task 1)

### Providers And Delivery

- [ ] [Task 4](./tasks/TASK4-build-openspec-provider.md) - Implement the OpenSpec provider as the first non-classic resolver that extracts plain-text scope, requirements, and goal for the unchanged execution engine (deps: Task 1, Task 2, Task 3)
- [ ] [Task 5](./tasks/TASK5-gate-openspec-archive-and-supported-path.md) - Add OpenSpec-specific archive gating and blessed-path guidance on top of the provider model (deps: Task 4)
- [ ] [Task 6](./tasks/TASK6-finalize-evidence-policy-and-provider-docs.md) - Finalize provider-owned evidence policy and workflow docs so the harness remains planning-agnostic in operator guidance (deps: Task 5)

## Coverage Matrix

| New Field/Endpoint | Added In | Code Paths Affected | Handled By | Converter Functions |
|--------------------|----------|---------------------|------------|---------------------|
| `work_packet.scope` | Task 1 | task-workflow preflight, minimality gate, critic/Codex/sentinel prompts, execution-core wording | Tasks 2, 3, 4 | provider input -> `work_packet.scope` |
| `work_packet.requirements` | Task 1 | task-workflow -> scribe handoff, audit prompts, coverage matrix output | Tasks 2, 3, 4 | provider input -> `work_packet.requirements` |
| `work_packet.goal` | Task 1 | review context, PR context, operator guidance | Tasks 2, 4, 6 | provider input -> `work_packet.goal` |
| `provider.resolve()` contract | Task 1 | classic provider, OpenSpec provider, future provider docs, plan-workflow guidance | Tasks 2, 4, 6 | provider-native input -> `work_packet` |
| `archive_gate()` | Task 5 | OpenSpec archive wrapper, settings hook wiring, operator feedback | Tasks 5, 6 | archive request + merged-PR lookup + evidence -> allow/deny |
| provider-owned planning diff policy | Task 6 | `evidence.sh`, docs-only PR behavior, provider docs | Task 6 | planning-file diff -> included/excluded evidence hash policy |

**Validation:** Every row must be covered for both the classic baseline provider and the OpenSpec provider, or else be explicitly provider-specific.

## Dependency Graph

```text
Task 1 ───┬───> Task 2 ───┐
          │               ├───> Task 4 ───> Task 5 ───> Task 6
          └───> Task 3 ───┘
```

## Task Handoff State

| After Task | State |
|------------|-------|
| Task 1 | The harness has a documented provider contract and a minimal `work_packet`, with classic TASK semantics expressed as a baseline provider instead of native engine behavior |
| Task 2 | `task-workflow` consumes `work_packet` and no longer owns checkbox/completion behavior; classic planning inputs are preserved through the baseline provider |
| Task 3 | `scribe` receives scope text and requirements text directly, with no file-path or format knowledge |
| Task 4 | OpenSpec resolves into the same `work_packet` the engine already understands, proving the engine is planning-agnostic |
| Task 5 | OpenSpec archive is gated honestly, and the supported execution path is documented without impossible hard-block claims |
| Task 6 | Evidence policy and workflow docs speak in provider terms, not TASK-native terms |

## External Dependencies

| Dependency | Status | Blocking |
|------------|--------|----------|
| Existing TASK semantics in `task-workflow` and `scribe` | Fixed internal baseline | Tasks 1-4 |
| OpenSpec change layout under `openspec/changes/<slug>/` | Fixed upstream contract | Tasks 4-6 |
| Current hook surface in `claude/settings.json` | Fixed constraint | Task 5 |
| GitHub CLI auth for merged-PR lookup in archive-gate | Existing repo/tooling dependency | Task 5 |
| Markdown exclusion in `claude/hooks/lib/evidence.sh:100` | Existing policy, decision pending | Task 6 |

## Plan Evaluation Record

PLAN_EVALUATION_VERDICT: PASS

Evidence:
- [x] Existing standards referenced with concrete paths
- [x] Data transformation points mapped
- [x] Tasks have explicit scope boundaries
- [x] Dependencies and verification commands listed per task
- [x] Requirements reconciled against source inputs
- [x] Whole-architecture coherence evaluated
- [x] UI/component tasks include design references

Source reconciliation:
- The work-packet contract has been simplified again: only scope, requirements, and a goal summary remain.
- Human-readable completion tracking is no longer an engine concern. Providers may update their own state after PR creation if they wish, but the engine does not require or gate it.
- `scribe` is now format-blind in the design: providers extract requirements text, and `scribe` audits that text against the diff and tests.
- OpenSpec remains the first proof-provider, but the architecture is explicitly written so a Linear ticket or any future planner can plug in by producing the same packet.

## Definition of Done

- [ ] All planned deliverables are implemented and verified
- [ ] `task-workflow`, `scribe`, and `execution-core` speak in provider/work-packet terms rather than TASK-native terms
- [ ] The `work_packet` contains only `scope`, `requirements`, and `goal`
- [ ] The engine no longer owns checkbox/completion behavior
- [ ] Classic TASK semantics and OpenSpec both resolve into the same `work_packet` and execute through the unchanged review/evidence spine
- [ ] OpenSpec archive requires fresh harness evidence plus merged-PR completion proof
- [ ] Provider-owned planning-file evidence policy is explicit and regression-tested
- [ ] SPEC.md acceptance criteria are satisfied
