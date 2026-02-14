---
name: plan-workflow
description: Create implementation plans before coding substantial features.
user-invocable: true
---

# Plan Workflow

Use for substantial feature work before implementation. This workflow creates planning docs only.

## Invocation Requirements

Use this workflow when any of the following is true:

1. The user explicitly asks for a plan/spec/design before coding.
2. The user explicitly requests planning docs (`SPEC.md`, `DESIGN.md`, `PLAN.md`, `TASK*.md`) and the expected output is docs, not implementation changes.
3. Scope is broad or ambiguous enough that implementation targets are not yet concrete.

If not:

- Use `task-workflow` for clear implementation requests.
- Use `bugfix-workflow` for concrete defect/regression fixes.
- Use `code-review` for review-only requests.

## Setup

1. Create dedicated planning branch/worktree using `<ISSUE-ID>-<kebab-case-description>-plan`.
2. Create project folder: `doc/projects/<feature-name>/`.

## Output Location

`doc/projects/<feature-name>/`

## Process

1. Confirm scope, constraints, and non-goals.
2. Explore existing code patterns and integration points.
3. Create docs by adapting the template examples:
   - `SPEC.md`
   - `DESIGN.md`
   - `PLAN.md`
   - `tasks/TASK*.md`
4. Ensure tasks are small and independently executable (target about 200 LOC of implementation per task).
5. Go back and evaluate your plan against the Required Planning Checks and Review Checklist, including source reconciliation against the planning inputs used to draft the plan and a whole-architecture coherence pass across all planned tasks.
6. If evaluation finds gaps, source mismatches, or whole-architecture coherence issues, refine docs and repeat evaluation until it passes.
7. Link docs together and verify cross-references.
8. Stop after planning delivery; do not start `task-workflow` unless the user explicitly requests implementation.

## Outputs

- `SPEC.md`
- `DESIGN.md`
- `PLAN.md`
- `tasks/TASK*.md`

## Execution Flow

`clarify requirements -> generate planning docs -> go back and evaluate your plan -> refine docs + reevaluate until pass -> pre-pr-verification -> commit -> draft docs-only PR -> stop`

## When to Create Which Docs

| Scenario | Files Created |
|----------|---------------|
| Small change | SPEC.md only |
| New feature | SPEC.md + DESIGN.md |
| Migration | LEGACY_DESIGN.md + DESIGN.md + SPEC.md |
| Ready to implement | Add PLAN.md + tasks/TASK*.md |

**Don't use for**: Bug fixes, quick refactors, or changes under ~50 lines.

## Deep Exploration (CRITICAL)

**Before writing DESIGN.md**, conduct thorough codebase exploration:

1. **Find existing standards** — Search for similar patterns in the codebase
   - How is similar data already handled?
   - Are there existing abstractions to extend (e.g., DataSource pattern)?
   - What naming conventions are used?

2. **Map data transformation points** — Identify ALL places where data changes shape
   - Proto -> Domain converters
   - Params conversion functions (e.g., `convertToParams`, `adaptRequest`)
   - Adapter patterns between layers

3. **List integration points** — Where will new code touch existing code?
   - Entry points (handlers, routes)
   - Layer boundaries (handler -> usecase -> domain)
   - Shared utilities or helpers

**Why this matters:** Shallow exploration leads to:
- Missing existing patterns (reimplementing what exists)
- Forgetting transformation points (fields silently dropped)
- Scope mismatches between tasks

## Documentation

| Document | Purpose | Template |
|----------|---------|----------|
| SPEC.md | Requirements, acceptance criteria | [spec.md](./templates/spec.md) |
| DESIGN.md | Architecture, file structure, APIs | [design.md](./templates/design.md) |
| LEGACY_DESIGN.md | Current system (migrations only) | [legacy-design.md](./templates/legacy-design.md) |
| PLAN.md | Task order, dependencies | [plan.md](./templates/plan.md) |
| tasks/TASK*.md | Step-by-step implementation | [task.md](./templates/task.md) |

## Plan Header (Required)

Every PLAN.md must start with:

```markdown
# <Feature Name> Implementation Plan

> **Goal:** [One sentence — what this achieves]
>
> **Architecture:** [2-3 sentences — key technical approach]
>
> **Tech Stack:** [Relevant technologies]
>
> **Specification:** [SPEC.md](./SPEC.md) | **Design:** [DESIGN.md](./DESIGN.md)
```

This ensures any agent (or human) can understand the plan without reading other docs first.

## Task Granularity

Choose based on complexity:

### Standard Mode (default)

- ~200 lines of implementation code (tests excluded from count)
- Each task fits in single agent context window
- If task touches >5 files, split it

### Atomic Mode (for complex/risky changes)

Break tasks into 2-5 minute steps:

```markdown
## Steps

1. [ ] Write failing test for [specific behavior]
2. [ ] Run test, verify it fails
3. [ ] Implement minimal code to pass
4. [ ] Run test, verify it passes
5. [ ] Commit: "[type]: [description]"
```

Use atomic mode when:
- High-risk changes (auth, payments, data migrations)
- Unfamiliar codebase or technology
- Complex state management
- User explicitly requests granular breakdown

## Agent-Optimized Guidelines

### Testing in Tasks

- Include tests in the same task/PR as implementation
- Each task should have its own test requirements
- Reference `@write-tests` skill for methodology

### Every Task Must Include

- **Issue:** Link to issue tracker (e.g., `ENG-123`) or descriptive slug
- **Required context**: Files agent reads first
- **Files to modify**: Exact paths with actions
- **Verification commands**: Type check, tests, lint
- **Acceptance criteria**: Machine-verifiable
- **Scope boundary**: What IS and ISN'T in scope (prevents cross-task mismatch)

### Explicit Over Implicit

- Exact file paths, not patterns
- Before/after code, not descriptions
- Line numbers when modifying existing code

### Context Independence

- Each task independently executable
- Don't assume agent remembers previous tasks
- List all dependencies explicitly

### Documentation Verbosity

- **SPEC.md / PLAN.md / DESIGN.md**: High-level requirements only. Avoid implementation code examples.
- **TASK files**: Include implementation details needed for execution (function signatures, type definitions, patterns). Keep focused on *what* to build, not full consumer integration examples.
- Link between documents rather than duplicating content (e.g., "See TASK6.md for details")

### Requirements Over Implementation

- Focus on requirements, references, and key gotchas
- Reference existing implementations rather than duplicating code
- Don't provide near-complete code implementations in tasks
- List test cases as bullet points, not detailed test code
- Trust implementer agents to handle detailed implementation decisions

## Required Planning Checks

1. Existing standards are referenced with concrete paths.
2. Data transformation points are explicitly mapped for schema/field changes.
3. Tasks contain explicit scope boundaries (in scope / out of scope).
4. Dependencies and verification commands are listed per task.
5. Requirements and tasks are reconciled against source inputs (local docs and external planning inputs such as Notion/Linear/Figma), and any unresolved mismatches are documented.
6. Whole-architecture coherence is evaluated across the full task sequence (combined end state, hotspot files, cross-task invariants, and cleanup/convergence path).

## Plan Evaluation Output Contract (Required)

Record evaluation evidence in `PLAN.md` under `## Plan Evaluation Record` before `pre-pr-verification`:

1. Explicit verdict marker: `PLAN_EVALUATION_VERDICT: PASS` or `PLAN_EVALUATION_VERDICT: FAIL`.
2. Checklist evidence covering all items in:
   - Required Planning Checks
   - Review Checklist
3. Source reconciliation evidence with references and mismatch notes (or explicit "None").
4. If verdict is `FAIL`: blocking gaps are listed and docs are revised before rerunning evaluation.

## Required Gates

1. Requirements gate: requirements and non-goals are explicit.
2. Design gate: architecture, integration points, and transformation points are explicit.
3. Scope gate: tasks are small, ordered, and independently testable.
4. Architecture coherence gate: the plan defines and validates the intended end-state architecture across all tasks, not only per-task changes.
5. Plan evaluation gate: the "go back and evaluate your plan" step passes against required planning checks and this skill's review checklist.
6. Automated gate: `pre-pr-verification` is required before PR creation and must complete with command evidence.
7. Delivery gate: commit plan docs and create draft docs-only PR.

## Review Checklist

1. Requirements are measurable.
2. Existing code patterns are referenced with concrete file paths.
3. Data transformation points are mapped for new/changed fields.
4. Task boundaries are clear and include in-scope/out-of-scope notes.
5. Risks and dependencies are called out.
6. Plan requirements and task scopes are traceable to source inputs, and source conflicts are called out explicitly.
7. Combined end-state architecture is coherent: hotspot files have target shapes, invariants are preserved through task order, and temporary structures have a cleanup/convergence path.

## Skill References

Reference other skills inline using `@skill-name`:

| Reference | Meaning |
|-----------|---------|
| `@write-tests` | Use Testing Trophy methodology |
| `@code-review` | Run code review before PR |
| `@minimize` | Check for bloat before finalizing |
| `@brainstorm` | Use if requirements unclear |

Example in task: "Write tests following `@write-tests` methodology."

## Post-Planning Handoff

After plan is complete, offer:

1. **Implement now** — Start with Task 1
2. **Review first** — User reviews plan before implementation
3. **Parallel tasks** — Identify which tasks can run concurrently

Always wait for user confirmation before starting implementation.

## Templates

Use the existing scaffolds:

- `./templates/spec.md`
- `./templates/design.md`
- `./templates/plan.md`
- `./templates/task.md`

## Core Reference

See `../../rules/execution-core.md`.
