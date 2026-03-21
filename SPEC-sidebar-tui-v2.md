# Party Sidebar TUI V2 Specification

## Problem Statement

- Standard and worker party sessions currently spend one third of the window on a visible Codex pane, even though Codex is usually driven indirectly through `tmux-codex.sh` rather than by direct human interaction.
- The current `even-horizontal` layout wastes horizontal space in Claude's pane and gives no compact summary of Codex activity or session context.
- Hiding Codex in another tmux window would still pollute the user's status bar, picker flows, and session discovery.

## Goal

Replace the visible Codex pane in standard and worker sessions with a narrow sidebar while keeping Codex available through a hidden companion tmux session and preserving the current master-session experience.

## User Experience

| Scenario | User Action | Expected Result |
|----------|-------------|-----------------|
| Default launch | Run `session/party.sh` for a standard or worker session | Main window opens as `sidebar | claude | shell` at roughly `15/55/30`; Codex runs in a detached companion session and is absent from the main status bar |
| Classic escape hatch | Run `PARTY_LAYOUT=classic session/party.sh` | Existing three-pane `codex | claude | shell` layout remains unchanged |
| Master launch | Run `session/party.sh --master` | Master session still uses tracker, Claude, and shell; no Codex companion or sidebar is introduced |
| Codex review dispatch | Claude invokes `tmux-codex.sh --review|--prompt|--plan-review` from a sidebar worker | Routing resolves Codex through the companion session without changing the caller contract |
| Companion offline | Companion session dies or manifest points at a stale companion | Sidebar shows Codex as offline, peek is guarded, stale `codex_session` metadata is cleared, and routing fails closed without recursion loops |
| Session teardown | User closes the worker session or runs `party.sh --stop|--delete` | Parent session teardown kills the companion session as part of the same flow; bulk stop skips direct companion enumeration |

## Acceptance Criteria

- [ ] Standard and worker sessions default to a sidebar layout with a detached companion Codex session.
- [ ] Master sessions remain unchanged regardless of `PARTY_LAYOUT`.
- [ ] `PARTY_LAYOUT=classic` preserves the current visible Codex pane behavior.
- [ ] Companion sessions do not appear in normal party discovery, picker, or list flows.
- [ ] `party_role_pane_target_with_fallback()` resolves Codex through a live companion session and self-heals stale `codex_session` values.
- [ ] Sidebar top section shows Codex state, target, elapsed time, and latest verdict when available.
- [ ] Sidebar bottom section shows standalone session metadata or, for workers, master/worker context from manifests.
- [ ] Dead companions render as offline, clear stale data, and recover automatically on the next refresh.
- [ ] Codex peek uses a live read-only popup and shows a flash message instead of a tmux error when unavailable.
- [ ] Session close, `party_stop`, `party_delete`, and bulk stop all avoid orphaned companion sessions.

## Non-Goals

- Reworking master-session tracker UX or layout.
- Changing Claude-to-Codex message formats in `tmux-codex.sh`.
- Replacing tmux with another process supervisor.
- Adding new third-party dependencies beyond the existing Go/Bubble Tea stack.

## Technical Reference

Implementation details and evidence live in [DESIGN-sidebar-tui-v2.md](./DESIGN-sidebar-tui-v2.md).
