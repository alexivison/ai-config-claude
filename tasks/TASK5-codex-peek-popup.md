# Task 5 — Codex Peek Popup

**Dependencies:** Task 3, Task 4 | **Issue:** N/A (sidebar-tui-v2)

---

## Goal

Let sidebar users inspect Codex output through a snapshot-based tmux popup with periodic refresh, and receive inline feedback when the companion is unavailable.

## Scope Boundary (REQUIRED)

**In scope:**
- Sidebar keybinding for peek
- `tmux display-popup` with snapshot-based refresh (NOT `tmux attach-session -r` which switches the whole client)
- Flash-message or inline feedback when peek is unavailable
- Guarding the action on current `codexStatus`

**Out of scope (handled by other tasks):**
- Companion creation/routing/cleanup
- Codex status parsing itself
- Bottom session-info rendering

**Cross-task consistency check:**
- This task relies on Task 4's `codexStatus` so it can disable peek when Codex is offline.
- The popup target must remain the same `codex_session` field introduced in Task 1 and stabilized by Task 2.

## Reference

Files to study before implementing:

- `tools/party-tracker/actions.go:10-69` — current tmux-backed action wrapper style
- `tools/party-tracker/main.go:112-230` — current key handling pattern
- `man tmux` for `display-popup -E` semantics — popup runs a command, closes on exit

## Design References (REQUIRED for UI/component tasks)

- `../plans/sidebar-tui-v2-layout.svg`

## Data Transformation Checklist (REQUIRED for shape changes)

N/A (no new persisted shape; this task consumes `codexStatus` and `codex_session`)

## Files to Create/Modify

| File | Action |
|------|--------|
| `tools/party-tracker/actions.go` | Modify |
| `tools/party-tracker/main.go` | Modify |
| `tools/party-tracker/sidebar.go` | Modify |

## Requirements

**Functionality:**
- Bind `p` in sidebar mode to a `peekCodex()` action.
- Implement `peekCodex()` using snapshot-based refresh: `tmux display-popup -E -w 80% -h 80% "watch -n1 'tmux capture-pane -t <codex_session>:0.0 -p -S -500'"` or a small wrapper script that re-captures every ~1s inside the popup. User exits with `q` or `Ctrl-C`.
- If the companion is unavailable, do not let tmux print a raw error; instead show a short flash message in the sidebar.
- Keep the peek affordance visible but clearly unavailable when Codex is offline.

**Key gotchas:**
- `tmux attach-session -r` inside `display-popup` does NOT work — it switches the whole tmux client instead of embedding in the popup. This was independently confirmed during v1 review. Use snapshot-based approach instead.
- The `watch` command refreshes every 1s which is adequate for monitoring Codex output. A wrapper script can add ANSI coloring or header info if desired.
- Popup dismissal and flash-message clearing should fit Bubble Tea's update loop rather than blocking the UI thread.

## Tests

Test cases:
- Trigger peek when Codex is live and verify the popup command uses `capture-pane` targeting the companion session (not `attach-session`)
- Trigger peek when Codex is offline and verify a flash message appears instead of a tmux error
- Verify the `p` binding is sidebar-only and does not affect master tracker mode

Verification commands:
- `cd tools/party-tracker && go test ./...`
- Manual tmux smoke test from a sidebar worker session

## Acceptance Criteria

- [ ] Sidebar users can open a snapshot-based Codex popup with `p` that refreshes periodically (~1s)
- [ ] Popup uses `capture-pane`, NOT `attach-session -r` (which would hijack the client)
- [ ] Offline or dead companions surface a controlled flash message instead of a raw tmux error
- [ ] Peek behavior does not regress master tracker keybindings or standard shell interaction
