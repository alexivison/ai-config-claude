# Task 13 — Build Master Tracker View

**Dependencies:** Task 7, Task 10, Task 11 | **Issue:** TBD

---

## Goal

Finish the master-side tracker view inside `party-cli`. The old tracker functionality should now live in the unified binary, backed by shared lifecycle and messaging services rather than shelling out to Bash scripts.

## Scope Boundary (REQUIRED)

**In scope:**
- Implement worker list and snippet rendering for master mode
- Add attach, relay, spawn, and manifest-inspect actions
- Reuse shared lifecycle and messaging services from prior tasks
- Preserve the tracker’s width-adaptive rendering and keyboard flow where sensible

**Out of scope (handled by other tasks):**
- Worker sidebar widgets
- Picker flow cutover
- Final shell-wrapper retirement

**Cross-task consistency check:**
- Tracker actions must call the lifecycle and messaging services created in Task 10 and Task 11
- This task should leave no master-only behavior stranded in `tools/party-tracker/`

## Reference

Files to study before implementing:

- `tools/party-tracker/main.go` — current master UI and input flow
- `tools/party-tracker/workers.go` — worker list and snippet behavior
- `tools/party-tracker/actions.go` — attach/relay/stop/delete action precedent
- `tools/party-cli/internal/session/*` — lifecycle services
- `tools/party-cli/internal/message/*` — messaging services

## Design References (REQUIRED for UI/component tasks)

- `../diagrams/session-layouts.svg`
- `../diagrams/end-state-architecture.svg`

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
| `tools/party-cli/internal/tui/tracker.go` | Create |
| `tools/party-cli/internal/tui/tracker_actions.go` | Create |
| `tools/party-cli/internal/tui/*_test.go` | Modify or create |
| `tools/party-tracker/main.go` | Modify later only if a compatibility wrapper is retained temporarily |

## Requirements

**Functionality:**
- Master mode renders worker rows, snippets, and state clearly
- Tracker actions reuse Go lifecycle and messaging services rather than shelling out
- Manifest inspection is available without leaving the TUI
- Existing tracker ergonomics survive where they still buy clarity

**Key gotchas:**
- Avoid copying `exec.Command` wrapper behavior from the old tracker; this task is the point of convergence
- Keep attach/relay/spawn semantics aligned with CLI commands so the two surfaces do not drift

## Tests

Test cases:
- Worker list render with multiple worker states
- Attach, relay, and spawn action wiring
- Manifest inspect view or popup behavior
- Narrow-width tracker render

## Acceptance Criteria

- [x] Master tracker view is implemented inside `party-cli`
- [x] Tracker actions call shared Go services, not Bash scripts
- [x] Attach action switches tmux client to the selected worker session
- [x] Relay action sends a message to the selected worker's Claude pane via delivery-confirmed tmux service
- [x] Spawn action creates a new worker session under the master using Go lifecycle service
- [x] Manifest inspect shows the selected worker's (or master's) manifest in a scrollable overlay
- [x] Worker list renders active/stopped states, titles, and pane snippets
- [x] Narrow-width rendering degrades gracefully (compact status, hidden snippets)
- [x] Core tracker interactions are covered by tests
- [x] Legacy `tools/party-tracker/` is no longer the primary implementation
