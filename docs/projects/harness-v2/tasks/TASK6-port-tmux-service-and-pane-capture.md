# Task 6 — Port Tmux Service And Pane Capture

**Dependencies:** Task 4, Task 5 | **Issue:** TBD

---

## Goal

Establish one typed tmux service for session queries, pane lookup, delivery-confirmed sends, capture, popup helpers, and deterministic companion-session helpers. CLI commands and TUI views should both depend on this layer instead of shelling out ad hoc.

## Scope Boundary (REQUIRED)

**In scope:**
- Port tmux session and pane query helpers into `internal/tmux`
- Port role-based pane resolution with strict `@party_role` semantics
- Add delivery-confirmed send behavior with explicit results
- Port pane capture and popup helpers
- Add deterministic companion-session helpers used by sidebar mode

**Out of scope (handled by other tasks):**
- Session lifecycle orchestration
- `tmux-codex.sh` ownership or Codex transport migration
- Final TUI behavior beyond shared service calls

**Cross-task consistency check:**
- The send-result type created here becomes the shared contract for CLI messaging and TUI actions
- Companion-session naming helpers must match discovery filtering from Task 5 and launch behavior from Task 9

## Reference

Files to study before implementing:

- `session/party-lib.sh` — tmux send and pane-routing precedent
- `tools/party-tracker/workers.go` — current snippet capture behavior
- `tools/party-tracker/actions.go` — tmux action wrapper precedent
- `tmux/tmux.conf` — popup/layout assumptions

## Design References (REQUIRED for UI/component tasks)

N/A (non-UI task)

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
| `tools/party-cli/internal/tmux/client.go` | Create |
| `tools/party-cli/internal/tmux/query.go` | Create |
| `tools/party-cli/internal/tmux/send.go` | Create |
| `tools/party-cli/internal/tmux/capture.go` | Create |
| `tools/party-cli/internal/tmux/popup.go` | Create |
| `tools/party-cli/internal/tmux/*_test.go` | Create |

## Requirements

**Functionality:**
- Query sessions and panes through typed functions
- Resolve pane targets through strict role metadata only
- Return explicit delivery results instead of best-effort exit codes
- Capture pane content and launch tmux popups through reusable helpers
- Share deterministic companion-session helpers for launch, routing, and filtering

**Key gotchas:**
- Keep the tmux layer free of business logic that belongs in lifecycle or message services
- Do not take ownership of `tmux-codex.sh`; this task prepares the Go layer for other flows only

## Tests

Test cases:
- Session and pane query parsing
- Strict role lookup success, not-found, and ambiguous cases
- Delivery success and timeout/error cases
- Pane capture and popup command construction
- Companion helper naming and lookup behavior

## Acceptance Criteria

- [ ] Shared tmux service exists with typed query, send, capture, and popup helpers
- [ ] Role lookup is strict and explicit
- [ ] Delivery results are no longer silent
- [ ] Companion-session helpers match discovery assumptions
- [ ] tmux package tests pass
