# Agent-Skill Separation Implementation Plan

> **Goal:** Separate agent declarative (what) from procedural (how) using skills preloading
>
> **Architecture:** Extract CLI procedures from codex.md and gemini.md into dedicated skills. Agents use `skills:` frontmatter to preload procedural content at startup.
>
> **Tech Stack:** Claude Code agents, skills, markdown
>
> **Specification:** [SPEC.md](./SPEC.md) | **Design:** [DESIGN.md](./DESIGN.md)

## Scope

Refactor two agents (codex, gemini) by extracting procedural content into skills.

## Task Granularity

- [x] **Standard** — ~200 lines of implementation (tests excluded), split if >5 files

## Agent Execution Strategy

- [x] **Sequential** — Tasks in order

After each task: verify behavior, commit, update checkbox here.

## Tasks

- [x] [Task 1](./tasks/TASK1-create-codex-cli-skill.md) — Create codex-cli skill with extracted procedures (deps: none)
- [x] [Task 2](./tasks/TASK2-slim-codex-agent.md) — Slim codex.md to declarative only (deps: Task 1)
- [x] [Task 3](./tasks/TASK3-create-gemini-cli-skill.md) — Create gemini-cli skill with extracted procedures (deps: none)
- [x] [Task 4](./tasks/TASK4-slim-gemini-agent.md) — Slim gemini.md to declarative only (deps: Task 3)

## Coverage Matrix (REQUIRED for new fields/endpoints)

| Content Block | Source | Destination | Task |
|---------------|--------|-------------|------|
| CLI invocation, task types | `codex.md:17-55` | `codex-cli/SKILL.md` | Task 1 |
| Execution, output, cleanup | `codex.md:56-131` | `codex-cli/SKILL.md` | Task 1 |
| Iteration support | `codex.md:133-143` | `codex-cli/SKILL.md` | Task 1 |
| Safety (`-s read-only`) | `codex.md:155-157` | `codex-cli/SKILL.md` | Task 1 |
| Agent frontmatter + boundaries | `codex.md` | `codex.md` (slim) | Task 2 |
| Output contract | `gemini.md:17-24` | `gemini-cli/SKILL.md` | Task 3 |
| Mode detection | `gemini.md:26-69` | `gemini-cli/SKILL.md` | Task 3 |
| CLI resolution, errors | `gemini.md:70-159` | `gemini-cli/SKILL.md` | Task 3 |
| Security & privacy | `gemini.md:161-192` | `gemini-cli/SKILL.md` | Task 3 |
| Log/web modes, output | `gemini.md:193-375` | `gemini-cli/SKILL.md` | Task 3 |
| Agent frontmatter + boundaries | `gemini.md` | `gemini.md` (slim) | Task 4 |

## Dependency Graph

```
Task 1 (codex-cli skill) ───> Task 2 (slim codex agent)

Task 3 (gemini-cli skill) ───> Task 4 (slim gemini agent)
```

Tasks 1 and 3 can run in parallel. Tasks 2 and 4 can run in parallel after their dependencies.

## Task Handoff State

| After Task | State |
|------------|-------|
| Task 1 | codex-cli skill exists with all procedures |
| Task 2 | codex.md slim, references skill, behavior unchanged |
| Task 3 | gemini-cli skill exists with all procedures |
| Task 4 | gemini.md slim, references skill, behavior unchanged |

## Definition of Done

- [x] All task checkboxes complete
- [x] codex.md < 40 lines (37 lines)
- [x] gemini.md < 40 lines (32 lines)
- [x] codex-cli/SKILL.md exists (138 lines)
- [x] gemini-cli/SKILL.md exists (361 lines)
- [ ] Plan-workflow still invokes codex successfully
- [ ] Gemini log analysis still works
