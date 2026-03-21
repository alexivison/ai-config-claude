# Task 7 — Absorb Tracker Runtime Into TUI Foundation

**Dependencies:** Task 5, Task 6 | **Issue:** TBD

---

## Goal

Turn the existing tracker into a reusable TUI foundation inside `party-cli`. This task builds the shared Bubble Tea shell, styling, polling cadence, and mode selection that later worker-sidebar and master-tracker views shall fill in.

## Scope Boundary (REQUIRED)

**In scope:**
- Create the shared Bubble Tea application shell in `internal/tui`
- Reuse `party-tracker` styling, polling cadence, and narrow-width rendering patterns
- Add auto-selection between worker/standalone sidebar mode and master tracker mode
- Support an explicit `--session` override for testability and local operator use

**Out of scope (handled by other tasks):**
- Final worker sidebar widgets such as Codex status and peek popup
- Final master tracker actions
- Session-launch integration in shell wrappers

**Cross-task consistency check:**
- The view-selection contract created here is what Task 9 will launch in pane `0`
- Task 12 and Task 13 must extend this model rather than creating separate TUI programs

## Reference

Files to study before implementing:

- `tools/party-tracker/main.go` — current model/update/view structure
- `tools/party-tracker/workers.go` — worker refresh pattern
- `tools/party-tracker/actions.go` — action wiring style

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
| `tools/party-cli/internal/tui/app.go` | Create |
| `tools/party-cli/internal/tui/model.go` | Create |
| `tools/party-cli/internal/tui/style.go` | Create |
| `tools/party-cli/internal/tui/*_test.go` | Create |
| `tools/party-tracker/main.go` | Reference only, or modify later if a compatibility wrapper is needed |

## Requirements

**Functionality:**
- `party-cli` TUI can boot with a shared model and polling loop
- Width-adaptive rendering and styling reuse the tracker patterns rather than starting over
- The TUI can determine whether the current session should render a worker sidebar or a master tracker shell
- Tests can force a specific session id without requiring live auto-discovery

**Key gotchas:**
- This task should stop at the foundation. Placeholder or skeletal panels are acceptable; final widgets belong to later tasks
- Keep the TUI state model thin enough that CLI commands do not need to import UI concerns

## Tests

Test cases:
- TUI boot path in no-arg mode
- Mode selection for master versus worker/standalone sessions
- Narrow-width rendering behavior
- Poll tick refresh without a live tmux server

## Acceptance Criteria

- [ ] `party-cli` has a shared Bubble Tea foundation inside `internal/tui`
- [ ] Existing tracker styling and width behavior are reused
- [ ] TUI mode selection between worker and master exists
- [ ] TUI foundation tests pass
