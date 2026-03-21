# Task 3 — Sidebar Mode And Session Info

**Dependencies:** Task 1 | **Issue:** N/A (sidebar-tui-v2)

---

## Goal

Add a dedicated sidebar mode to `party-tracker` that launches in worker and standalone sessions, preserves the current master-tracker experience, and renders the bottom "Session Info" section from manifest data without overflowing narrow panes.

## Scope Boundary (REQUIRED)

**In scope:**
- CLI parsing for `party-tracker --sidebar <session-id>`
- Sidebar-mode model/state split from the current master tracker
- Bottom-panel session info for standalone sessions and worker sessions with a master parent
- Narrow-width rendering guards, footer/help text, and mode-local key handling

**Out of scope (handled by other tasks):**
- Codex-state polling and verdict parsing
- Read-only popup peek behavior
- Companion routing or hidden-session filtering in shell scripts

**Cross-task consistency check:**
- This task consumes the sidebar launcher added by Task 1.
- Task 4 will populate the top Codex-status section on top of the sidebar layout scaffold created here.
- Task 5 will wire the `p` key into the sidebar keymap introduced here.

## Reference

Files to study before implementing:

- `tools/party-tracker/main.go:45-109` — current model, init, and update loop
- `tools/party-tracker/main.go:232-358` — current narrow-width helpers and rendering style
- `tools/party-tracker/main.go:419-435` — current CLI entrypoint
- `tools/party-tracker/workers.go:20-63` — manifest read helpers worth reusing or extending
- `tools/party-tracker/actions.go:10-69` — pattern for tmux-backed actions that sidebar mode should follow later

## Design References (REQUIRED for UI/component tasks)

- `../plans/sidebar-tui-v2-layout.svg`

## Data Transformation Checklist (REQUIRED for shape changes)

This task adds a new in-process sidebar model that consumes manifest data.

- [ ] Manifest JSON is expanded into a sidebar session-info struct without breaking master tracker reads
- [ ] Worker sessions with `parent_session` can read the parent's worker list from the manifest
- [ ] Sidebar CLI parsing remains backward-compatible with the existing master invocation
- [ ] Narrow-width rendering truncates rather than wrapping uncontrolled text

## Files to Create/Modify

| File | Action |
|------|--------|
| `tools/party-tracker/main.go` | Modify |
| `tools/party-tracker/workers.go` | Modify |
| `tools/party-tracker/sidebar.go` | Create |

## Requirements

**Functionality:**
- Parse `party-tracker --sidebar <session-id>` while keeping `party-tracker <session-id>` for master tracker mode untouched.
- Add sidebar-specific model state and rendering logic instead of overloading the master tracker view into unreadable conditionals.
- Render the bottom section from manifest data:
  - Standalone session: show session ID, title or cwd, and relevant timestamps.
  - Worker session: show session ID, parent master, and the worker list pulled from the parent manifest.
- Keep the existing Bubble Tea tick cadence and width helpers; sidebar mode must render sanely in very narrow panes.

**Key gotchas:**
- Worker-side "Session Info" is not just `parent_session`; the requirement calls for the worker list from the parent manifest, which means this task must read both manifests.
- The sidebar is narrow enough that multi-line truncation rules matter more than in the existing master tracker.
- Master tracker mode must remain byte-for-byte familiar to operators; do not accidentally route master sessions through sidebar rendering.

## Tests

Test cases:
- Launch `party-tracker --sidebar <session-id>` with a standalone manifest and verify session info renders
- Launch sidebar mode for a worker manifest with `parent_session` and verify the parent worker list is displayed
- Verify old master invocation still shows the worker tracker
- Verify narrow widths do not panic or produce unreadable overflow

Verification commands:
- `cd tools/party-tracker && go test ./...`
- `go run ./tools/party-tracker --sidebar party-test-sidebar`

## Acceptance Criteria

- [ ] Sidebar CLI mode exists and does not regress the existing master tracker invocation
- [ ] Bottom section renders standalone and worker session info from manifests
- [ ] Sidebar view remains usable at narrow widths
- [ ] Rendering scaffolding is ready for Task 4 to add live Codex status and Task 5 to add peek interactions
