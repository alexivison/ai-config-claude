# Task 4 — Scaffold Unified Party CLI

**Dependencies:** Task 2, Task 3 | **Issue:** TBD

---

## Goal

Create the new architectural center: `tools/party-cli/`. This task establishes the command tree, root-mode split between TUI and CLI, shared config/logging seams, and the package boundaries every later task shall build upon.

## Scope Boundary (REQUIRED)

**In scope:**
- Create the `tools/party-cli/` module
- Add a Cobra root command whose no-subcommand path launches a Bubble Tea entrypoint
- Establish package seams for config, state, tmux, session, messaging, picker, and TUI code
- Add baseline logging and test scaffolding

**Out of scope (handled by other tasks):**
- Real state access, tmux access, or lifecycle behavior
- Real tracker/sidebar rendering beyond a placeholder TUI entrypoint
- Shell wrapper cutover

**Cross-task consistency check:**
- The no-arg TUI path created here becomes the only allowed root-mode contract for later tasks
- Package seams chosen here must be broad enough for both absorbed tracker code and CLI subcommands without forcing a second refactor

## Reference

Files to study before implementing:

- `tools/party-tracker/go.mod` — version and dependency precedent
- `tools/party-tracker/main.go` — Bubble Tea entrypoint precedent
- `session/party.sh` — current CLI-like shell surface to map into future subcommands

## Design References (REQUIRED for UI/component tasks)

- `../diagrams/end-state-architecture.svg`
- `../diagrams/before-after.svg`

## Data Transformation Checklist (REQUIRED for shape changes)

- [ ] Proto definition (N/A unless a typed file contract is introduced)
- [ ] Proto -> Domain converter (N/A unless a typed file contract is introduced)
- [ ] Domain model struct
- [ ] Params struct(s) — check ALL variants
- [ ] Params conversion functions
- [ ] Any adapters between param types

## Files to Create/Modify

| File | Action |
|------|--------|
| `tools/party-cli/go.mod` | Create |
| `tools/party-cli/main.go` | Create |
| `tools/party-cli/cmd/root.go` | Create |
| `tools/party-cli/internal/config/*` | Create |
| `tools/party-cli/internal/tui/*` | Create |
| `tools/party-cli/internal/state/*` | Create placeholder files |
| `tools/party-cli/internal/tmux/*` | Create placeholder files |
| `tools/party-cli/internal/session/*` | Create placeholder files |
| `tools/party-cli/internal/message/*` | Create placeholder files |

## Requirements

**Functionality:**
- `party-cli` with no subcommand calls a TUI launcher function
- `party-cli help` and placeholder subcommands build and run cleanly
- Package layout is explicit enough that later tasks can add code without reorganizing the module
- Logging/config loading is centralized rather than scattered across commands

**Key gotchas:**
- Do not hide the TUI behind a separate `tui` subcommand; the root contract is part of the architecture
- Avoid prematurely baking in tracker-only assumptions; worker sidebar mode must fit the same shell
- **Runtime delivery contract:** Define how shell launchers resolve and run `party-cli`. Reuse the existing party-tracker pattern (`session/party-master.sh:46-59`): installed binary first, then `go run $PARTY_REPO_ROOT/tools/party-cli` as fallback. Pass `PARTY_REPO_ROOT` through exactly as the tracker launcher does.

## Tests

Test cases:
- `go test ./...` passes in `tools/party-cli/`
- Root with no subcommand reaches the TUI entrypoint in a controlled test
- Subcommand stubs execute without launching TUI mode

## Acceptance Criteria

- [ ] `tools/party-cli/` exists as a buildable Go module
- [ ] Root no-arg behavior launches TUI mode
- [ ] Subcommand mode is wired separately from TUI mode
- [ ] Shared package seams and test scaffolding are in place
