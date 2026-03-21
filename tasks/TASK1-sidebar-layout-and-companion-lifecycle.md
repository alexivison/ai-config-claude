# Task 1 — Sidebar Layout And Companion Lifecycle

**Dependencies:** none | **Issue:** N/A (sidebar-tui-v2)

---

## Goal

Teach standard and worker sessions to launch with a sidebar pane and a detached Codex companion session while preserving classic layout as an explicit escape hatch, ensuring every teardown path kills the companion cleanly, and making sidebar→master promotion companion-aware.

## Scope Boundary (REQUIRED)

**In scope:**
- `PARTY_LAYOUT=sidebar|classic` branching for standard and worker sessions
- Detached `<party-id>-codex` companion session creation and manifest persistence
- Sidebar `15/55/30` pane sizing and session-scoped hook override for rebalance hooks
- Companion teardown in session-closed, `party_stop`, `party_delete`, and resume collision paths
- Sidebar→master promotion: replace visible sidebar pane with tracker, tear down companion session, clear `codex_session`, set `session_type=master`

**Out of scope (handled by other tasks):**
- Companion-aware pane routing and scan-based hidden-session filtering
- Bubble Tea sidebar rendering, status parsing, and popup interactions
- Regression test implementation beyond the minimal checks needed while coding

**Cross-task consistency check:**
- This task introduces the persisted `codex_session` field; Task 2 must route through it and hide companion sessions from scans, while Tasks 4 and 5 must consume it from the tracker side.
- This task defines the visible `sidebar` pane role and launch command; Task 3 must honor that launch contract without altering master tracker startup.
- This task updates `party_promote()` so it correctly handles sidebar sessions. Without this fix, promotion would resolve the codex role into the companion session (via Task 2's routing fallback) and respawn the tracker there — invisible to the user.

## Reference

Files to study before implementing:

- `session/party.sh:75-84` — existing session-closed hook wiring
- `session/party.sh:86-158` — current standard/worker three-pane launch flow
- `session/party.sh:169-217` — start path that should default to sidebar
- `session/party.sh:244-303` — continue/resume path that must recreate or replace companions safely
- `session/party.sh:316-362` — delete/stop flows that must kill companions
- `session/party-master.sh:46-83` — current tracker launcher pattern; reuse command resolution without changing master behavior
- `session/party-master.sh:86-139` — current `party_promote()` that resolves codex pane and replaces it with tracker; must be updated for sidebar sessions
- `tmux/tmux.conf:31-34` — global rebalance hooks that sidebar sessions must override at session scope
- `session/party-lib.sh:67-144` and `session/party-lib.sh:146-213` — manifest write/read helpers for `codex_session`

## Design References (REQUIRED for UI/component tasks)

- `../plans/sidebar-tui-v2-layout.svg`

## Data Transformation Checklist (REQUIRED for shape changes)

This task adds the persisted `codex_session` field and a launch-time layout mode.

- [ ] `PARTY_LAYOUT` environment read is centralized in the standard/worker launcher path
- [ ] `codex_session` is written through existing manifest helpers, not ad hoc JSON edits
- [ ] Resume/relaunch paths replace stale companion sessions without leaving old names behind
- [ ] Classic and master paths do not rely on `codex_session` being present
- [ ] Promotion clears `codex_session` and kills companion before setting `session_type=master`

## Files to Create/Modify

| File | Action |
|------|--------|
| `session/party.sh` | Modify |
| `session/party-lib.sh` | Modify |
| `session/party-master.sh` | Modify (`party_promote()` must handle sidebar→master transition) |

## Requirements

**Functionality:**
- Default standard/worker launch path to `PARTY_LAYOUT=sidebar`; preserve `PARTY_LAYOUT=classic` as the old visible-Codex topology.
- In sidebar mode, create a detached companion session named `<party-id>-codex`, run Codex there with `@party_role=codex`, and persist that session name on the parent manifest.
- Replace pane `0.0` with the sidebar launcher, mark it `@party_role=sidebar`, and size panes to roughly `15/55/30`.
- Install session-scoped `after-split-window`, `after-kill-pane`, and `client-resized` hooks so sidebar sessions reapply the custom layout instead of inheriting the global `even-horizontal` rebalance.
- Ensure session-closed, `party_stop`, `party_delete`, and resume collision paths all kill the companion session before or during parent teardown.
- Update `party_promote()` for sidebar sessions: (a) resolve the visible `sidebar` pane (not the codex role, which would resolve into the companion), (b) respawn it with the tracker command, (c) set `@party_role=tracker`, (d) kill the companion session, (e) clear `codex_session` from manifest, (f) set `session_type=master`. This mirrors how master sessions already work — no Codex, tracker in pane 0.

**Key gotchas:**
- The global hooks in `tmux/tmux.conf` will undo the custom split unless the sidebar session installs its own hooks.
- Companion sessions must not create their own manifests; the parent manifest remains the only durable source of `codex_session`.
- Resume logic must handle a leftover `<party-id>-codex` session name from a failed prior cleanup.
- Bulk stop must not enumerate companion sessions independently; parent teardown owns companion shutdown.
- `party_promote()` currently resolves the `codex` role pane to replace it with the tracker. With companion routing (Task 2), this would find `{session}-codex:0.0` and respawn the tracker there — invisible to the user. Promotion must target the `sidebar` role pane instead, and must run BEFORE Task 2's companion routing is active (hence in this task, not Task 2).

## Tests

Test cases:
- Launch a standard session in default mode and verify pane roles plus companion session creation
- Launch with `PARTY_LAYOUT=classic` and verify the old visible-Codex pane layout still appears
- Resume a sidebar session with an already-running stale companion and verify the stale companion is replaced cleanly
- Delete/stop a sidebar session and verify the companion is gone afterward
- Promote a sidebar session to master and verify: sidebar pane replaced by tracker, companion killed, `codex_session` cleared, `session_type` set to master

Verification commands:
- `bash tests/test-party-companion.sh`
- `PARTY_LAYOUT=classic bash session/party.sh --detached "layout smoke"`

## Acceptance Criteria

- [ ] Sidebar sessions create a detached `<party-id>-codex` companion and persist `codex_session`
- [ ] Sidebar pane is visible as role `sidebar` and layout stays near `15/55/30` after launch and resize
- [ ] `PARTY_LAYOUT=classic` preserves the current standard/worker layout
- [ ] Master sessions remain behaviorally unchanged
- [ ] Session-close, stop, delete, and resume collision paths do not leave orphaned companion sessions
- [ ] `party_promote()` replaces the sidebar pane with the tracker, kills the companion, clears `codex_session`, and sets `session_type=master`
