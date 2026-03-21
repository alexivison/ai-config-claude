# Task 10 — Port Session Lifecycle And Worker Spawn

**Dependencies:** Task 8, Task 9 | **Issue:** TBD

---

## Goal

Port the mutating session lifecycle to Go: create, continue, stop, delete, promote, and spawn workers. After this task, the main session topology should be controllable through `party-cli`, even if shell wrappers still exist.

## Scope Boundary (REQUIRED)

**In scope:**
- Add `start`, `continue`, `stop`, `delete`, and `promote` subcommands
- Port worker-spawn flow for masters into the unified binary
- Reuse shared state, tmux, and TUI launch contracts
- Keep shell entrypoints working as coexistence wrappers

**Out of scope (handled by other tasks):**
- Relay, broadcast, read, or report-back behavior
- Final worker sidebar widgets and master tracker actions
- Final wrapper retirement

**Cross-task consistency check:**
- Worker spawning here must produce session layouts and companion behavior compatible with Task 9
- Later tracker actions in Task 13 should call the same lifecycle services defined here rather than invent local spawn logic

## Reference

Files to study before implementing:

- `session/party.sh` — start, continue, stop, delete flows
- `session/party-master.sh` — promote and master launch behavior
- `tools/party-cli/internal/state/*` — manifest persistence
- `tools/party-cli/internal/tmux/*` — tmux layout and routing helpers

## Design References (REQUIRED for UI/component tasks)

- `../diagrams/end-state-architecture.svg`
- `../diagrams/session-layouts.svg`

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
| `tools/party-cli/cmd/start.go` | Create |
| `tools/party-cli/cmd/continue.go` | Create |
| `tools/party-cli/cmd/stop.go` | Create |
| `tools/party-cli/cmd/delete.go` | Create |
| `tools/party-cli/cmd/promote.go` | Create |
| `tools/party-cli/cmd/spawn.go` | Create |
| `tools/party-cli/internal/session/*` | Create or modify |
| `tools/party-cli/internal/session/*_test.go` | Create |
| `session/party.sh` | Modify if wrapper delegation is added incrementally |
| `session/party-master.sh` | Modify if wrapper delegation is added incrementally |

## Requirements

**Functionality:**
- Lifecycle commands preserve current master/worker semantics
- Worker spawn creates the same pane/layout contracts expected by sidebar mode
- Commands return explicit failures instead of silent partial work
- Bash entrypoints may delegate, but live behavior must now be owned by Go services

**Key gotchas:**
- Promotion must correctly replace worker or standalone layout with master tracker layout
- Resume/continue behavior should preserve existing Claude and Codex resume semantics

## Tests

Test cases:
- Start/continue flows for standalone, worker, and master sessions
- Stop/delete cleanup with sidebar companions present
- Promote flow from worker or standalone to master
- Worker spawn from a master session

## Acceptance Criteria

- [ ] `party-cli` owns lifecycle commands and worker spawn behavior
- [ ] Session creation and teardown preserve current layout semantics
- [ ] Shell entrypoints can coexist as wrappers without diverging behavior
- [ ] Lifecycle tests pass
