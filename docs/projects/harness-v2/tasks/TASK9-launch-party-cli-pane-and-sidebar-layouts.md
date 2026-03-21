# Task 9 — Launch Party CLI Pane And Sidebar Layouts

**Dependencies:** Task 6, Task 7, Task 8 | **Issue:** TBD

---

## Goal

Put the unified binary into live sessions. Pane `0` should now run `party-cli`, master sessions should show the tracker shell, worker and standalone sessions should default to the sidebar shell, Codex should move to a hidden deterministic companion session, and `PARTY_LAYOUT=classic` must still preserve the old visible-Codex layout.

## Scope Boundary (REQUIRED)

**In scope:**
- Update shell launchers to start `party-cli` in pane `0`
- Keep master layout as tracker | claude | shell
- Change standard/worker default layout to sidebar | claude | shell
- Create and clean up deterministic hidden Codex companion sessions for sidebar mode
- Preserve `PARTY_LAYOUT=classic` as a first-class escape hatch
- Update shell routing helpers so retained Codex transport resolves the companion session when sidebar mode is active

**Out of scope (handled by other tasks):**
- Final worker sidebar widgets
- CLI lifecycle command ownership
- Final wrapper cutover

**Cross-task consistency check:**
- Companion naming created here must match the discovery filters from Task 5 and companion helpers from Task 6
- Task 12 assumes the sidebar shell launched here already exists and can read runtime status later

## Reference

Files to study before implementing:

- `session/party.sh` — current standard/worker launch flow
- `session/party-master.sh` — current master launch flow
- `session/party-lib.sh` — role routing and session discovery helpers
- `claude/skills/codex-transport/scripts/tmux-codex.sh` — retained shell caller that must keep working

## Design References (REQUIRED for UI/component tasks)

- `../diagrams/session-layouts.svg`
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
| `session/party.sh` | Modify |
| `session/party-master.sh` | Modify |
| `session/party-lib.sh` | Modify |
| `claude/skills/codex-transport/scripts/tmux-codex.sh` | Modify only if helper names or routing glue change |
| `tests/test-party-routing.sh` | Modify |
| `tests/test-party-master.sh` | Modify |
| `tests/test-party-sidebar-layout.sh` | Create |

## Requirements

**Functionality:**
- New sessions launch `party-cli` in pane `0`
- Worker and standalone sessions default to sidebar layout with hidden Codex companion
- Master sessions default to tracker layout
- `PARTY_LAYOUT=classic` preserves the existing visible-Codex behavior
- Companion sessions are cleaned up on teardown and remain hidden from user-facing discovery
- Retained Codex transport continues to resolve a live target in both sidebar and classic modes

**Key gotchas:**
- Do not add a new persisted manifest field merely to track the companion; deterministic naming is sufficient
- Promotion and teardown paths must not orphan companion sessions
- **Promotion compatibility (blocking):** The current shell promotion path (`session/party-master.sh:126-133`) resolves a visible `codex` role pane and respawns the tracker into it. Once sidebar mode removes the visible Codex pane, promotion breaks. This task MUST update the promotion path to handle sidebar mode: replace the sidebar pane with the tracker and tear down the companion, or defer the sidebar layout change to after Task 10 ports promotion. No independently shippable PR may leave promotion broken.

## Tests

Test cases:
- Sidebar default launch for standalone and worker sessions
- Classic fallback launch
- Master launch remains tracker-based
- Companion cleanup on stop/delete/session close
- Codex transport routing resolves the companion when sidebar mode is active

## Acceptance Criteria

- [ ] Pane `0` launches `party-cli` in new sessions
- [ ] Sidebar and classic layouts both work as designed
- [ ] Hidden Codex companions are deterministic, hidden, and cleaned up
- [ ] `tmux-codex.sh` still reaches Codex through retained shell routing
- [ ] Shell promotion (`party.sh --promote`) works in both sidebar and classic modes
- [ ] Layout and routing tests pass
