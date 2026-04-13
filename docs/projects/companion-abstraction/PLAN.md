# Companion Abstraction Implementation Plan

> **Goal:** Make the party harness companion-agnostic so any CLI tool can slot into a named role — without changing the execution core, evidence system, or sub-agent architecture.
>
> **Architecture:** Introduce a Go `Companion` interface and registry, a `.party.toml` project config, and companion-parameterized transport — building on the Go `party-cli` binary from [PR #119](https://github.com/alexivison/ai-config/pull/119). Existing Codex logic becomes the first `Companion` implementation.
>
> **Tech Stack:** Go (companion package, transport, manifest, CLI commands), TOML (project config), Bash (hooks — thin wrappers only)
>
> **Specification:** [SPEC.md](./SPEC.md) | **Design:** [DESIGN.md](./DESIGN.md)

## Prerequisite

[PR #119](https://github.com/alexivison/ai-config/pull/119) ("CLI-ify repo") must land first. It consolidates shell scripts into `party-cli`, giving us:
- `transport.Service` with Go dispatch methods (`Review`, `PlanReview`, `Prompt`, etc.)
- `tmux.Client.ResolveRole()` for pane resolution by `@party_role`
- `state.Store` with manifest persistence and `Extra` map
- `party-cli transport <mode>` as the unified CLI entry point
- Go tests for transport (`transport_test.go`)

This plan extends that Go codebase — not the deleted shell scripts.

## Scope

This plan covers the full abstraction from Codex-specific plumbing to companion-agnostic plumbing. It does NOT cover:
- OpenSpec adapter implementation (separate project, builds on this)
- Non-tmux transport backends (designed for, not built)
- Multi-companion orchestration logic (v1 uses explicit `--to <name>` addressing)

**Relationship to `source-agnostic-workflow`:** That project decouples execution from TASK file format. This project decouples from Codex. Both are complementary and can land in any order, but Task 7 below should coordinate with `source-agnostic-workflow` Task 3 if it lands first (to avoid merge conflicts in CLAUDE.md and execution-core.md).

## Task Granularity

- [x] **Standard** — ~200 lines of implementation (tests excluded), split if >5 files

## Tasks

- [ ] [Task 1](./tasks/TASK1-companion-interface-and-registry.md) — Create Go `Companion` interface, registry, `.party.toml` config parser, and Codex implementation (deps: PR #119)
- [ ] [Task 2](./tasks/TASK2-companion-aware-transport.md) — Parameterize `transport.Service` methods with companion name; replace `resolveCodexContext()` with registry-based resolution (deps: Task 1)
- [ ] [Task 3](./tasks/TASK3-generalize-hooks.md) — Rename and parameterize hooks (codex-gate, wizard-guard, codex-trace); make pr-gate config-driven (deps: Task 1)
- [ ] [Task 4](./tasks/TASK4-companion-aware-sessions.md) — Dynamic companion startup in `cmd/start.go`, multi-companion resume in `cmd/continue.go`, `Companions[]` in manifest (deps: Task 1)
- [ ] [Task 5](./tasks/TASK5-update-settings-and-install.md) — Update settings.json hook paths; make `party-cli install` companion-aware (deps: Task 2, Task 3)
- [ ] [Task 6](./tasks/TASK6-extend-tests.md) — Extend Go transport tests for multi-companion; update hook tests for renamed hooks (deps: Task 2, Task 3)
- [ ] [Task 7](./tasks/TASK7-update-docs-and-workflow-skills.md) — Update CLAUDE.md, execution-core.md, and workflow skill prompts to role-based language (deps: Task 2, Task 3, Task 4)
- [ ] [Task 8](./tasks/TASK8-stub-companion.md) — Create a documented stub `Companion` implementation as a reference for adding new companions (deps: Task 1) *(can run in parallel with Tasks 2–4)*

## Dependency Graph

```
PR #119 ──> Task 1 ───┬───> Task 2 ───┬───> Task 5
                      │               │
                      ├───> Task 3 ───┤───> Task 6
                      │               │
                      ├───> Task 4 ───┼───> Task 7
                      │               │
                      └───> Task 8    └───> Task 7
```

## Task Handoff State

| After Task | State |
|------------|-------|
| Task 1 | `Companion` interface, registry, config parser, Codex implementation, `companion_test.go`, and `party-cli companion query` subcommand exist. Nothing uses them yet except hooks (via query). Existing transport still works unchanged. |
| Task 2 | `transport.Service` dispatches via registry. `party-cli transport --to wizard review` works. `resolveCodexContext()` replaced. |
| Task 3 | Hooks are companion-generic. Evidence records companion name instead of "codex". PR gate reads `.party.toml`. |
| Task 4 | `cmd/start.go` creates companion windows dynamically. Manifest tracks N companions. Resume iterates companions. |
| Task 5 | `settings.json` points to new hook paths. `party-cli install` is companion-aware. System fully wired. |
| Task 6 | All Go transport tests pass with companion abstraction. All hook tests pass with new names. |
| Task 7 | All docs and skill prompts use role-based language. "Ask the Wizard" still works. |
| Task 8 | A stub companion exists as onboarding ramp for new companion authors. |

## Coverage Matrix

| New Concept | Added In | Code Paths Affected | Handled By |
|-------------|----------|---------------------|------------|
| `Companion` interface | Task 1 | Transport dispatch, session startup, notify completion | Task 2 (transport), Task 4 (session) |
| `Registry` | Task 1 | Transport resolution, session startup, install | Task 2 (transport), Task 4 (session), Task 5 (install) |
| `.party.toml` config | Task 1 (parser) | Evidence requirements, companion selection, install | Task 3 (pr-gate), Task 4 (session), Task 5 (install) |
| `--to <name>` CLI flag | Task 2 (cmd) | Hook pattern matching | Task 3 (hooks), Task 5 (settings.json) |
| `companion-gate.sh` | Task 3 (hook) | PreToolUse blocking | Task 5 (settings.json), Task 6 (tests) |
| `companion-trace.sh` | Task 3 (hook) | PostToolUse evidence | Task 5 (settings.json), Task 6 (tests) |
| `Companions[]` in manifest | Task 4 (Go) | Session continue/resume, status tracking | Task 4 (continue.go) |

## Definition of Done

- [ ] All task checkboxes complete
- [ ] Running `party-cli start "test"` with NO `.party.toml` works exactly as today (Codex as wizard)
- [ ] Running with `.party.toml` setting a different `companions.wizard.cli` routes to that companion
- [ ] All Go transport tests pass (existing + new companion tests)
- [ ] All hook tests pass (renamed)
- [ ] `pr-gate.sh` reads evidence requirements from config
- [ ] CLAUDE.md never mentions "Codex" in plumbing instructions (only as default companion persona)
- [ ] A stub companion exists demonstrating the interface
- [ ] SPEC.md acceptance criteria satisfied
