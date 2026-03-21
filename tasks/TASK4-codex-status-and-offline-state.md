# Task 4 — Codex Status And Offline State

**Dependencies:** Task 2, Task 3 | **Issue:** N/A (sidebar-tui-v2)

---

## Goal

Populate the sidebar's top section by reading the runtime status file written by `tmux-codex.sh` (Task 2), deriving a stable `codexStatus` view model that can show idle/reviewing/done/offline states without leaking stale data.

## Scope Boundary (REQUIRED)

**In scope:**
- Reading `/tmp/<session>/codex-status.json` (written by `tmux-codex.sh` in Task 2)
- Companion-session liveness checks from the tracker side (for offline detection)
- Top-panel rendering for status, target, elapsed time, and latest verdict
- Offline fallback and automatic recovery on the next poll

**Out of scope (handled by other tasks):**
- Sidebar launch plumbing and bottom session-info rendering
- Read-only popup interactions and flash-message UX
- Shell-side companion creation or routing

**Cross-task consistency check:**
- This task depends on Task 2 keeping `codex_session` fresh and self-healed, and on the runtime status file format introduced there.
- This task fills the top half of the sidebar scaffold from Task 3 and must expose enough state for Task 5 to gate the peek action.

## Reference

Files to study before implementing:

- `tools/party-tracker/main.go:71-79` — current polling cadence
- `tools/party-tracker/workers.go:105-153` — existing tmux capture and snippet filtering pattern (reference for Go-side tmux interaction, but status file is preferred over pane scraping)
- `claude/skills/codex-transport/scripts/tmux-codex.sh:68-131` — where status file writes happen (Task 2); defines the JSON contract this task reads
- `session/party-lib.sh:203-213` — manifest field reads for `codex_session`

## Design References (REQUIRED for UI/component tasks)

- `../plans/sidebar-tui-v2-layout.svg`

## Data Transformation Checklist (REQUIRED for shape changes)

This task introduces a new UI-facing `codexStatus` model that reads from the runtime status file.

- [ ] Status file JSON is parsed into `codexStatus` struct with `state`, `target`, `start_time`, `last_verdict`, `verdict_time`
- [ ] Companion liveness is checked via `tmux has-session` to detect offline state even when status file exists
- [ ] Active review timing and verdict-age calculations use `start_time` and `verdict_time` from the status file
- [ ] Offline transitions clear stale target/verdict display instead of reusing old values
- [ ] Missing or unparseable status file maps to `idle` (not `offline` — companion may be alive but no dispatch yet)

## Files to Create/Modify

| File | Action |
|------|--------|
| `tools/party-tracker/codex.go` | Create |
| `tools/party-tracker/sidebar.go` | Modify |
| `tools/party-tracker/main.go` | Modify |

## Requirements

**Functionality:**
- Read `codex_session` from the parent manifest and check `tmux has-session -t <codex_session>` on every poll for liveness.
- Read `/tmp/<session>/codex-status.json` (written by `tmux-codex.sh` in Task 2) to get structured state: `state`, `target`, `start_time`, `last_verdict`, `verdict_time`.
- Derive display state: `idle` (no active work), `reviewing` (dispatch in progress), `done` (verdict received), `offline` (companion dead).
- Display target reference and elapsed time (from `start_time`) when Codex is actively reviewing.
- Display last verdict with age (from `verdict_time`) when available.
- Recover automatically on the next tick if the companion session returns.

**Key gotchas:**
- The status file is the primary source of truth for Codex state — do NOT fall back to pane scraping. Pane scraping is fragile and was explicitly rejected during plan review.
- A missing status file with a live companion means `idle` (no dispatch yet), not `offline`.
- A status file with `state=reviewing` but dead companion means `offline` — companion liveness check overrides file state.
- Offline mode must dim or clear stale status text so users do not mistake dead data for live work.

## Tests

Test cases:
- Parse status file with `state=reviewing` into `reviewing` display state with elapsed time
- Parse status file with `last_verdict=APPROVED` into verdict display with age
- Missing status file with live companion → `idle`
- Status file with `state=reviewing` but dead companion → `offline`
- Lose the companion session and verify the UI model becomes `offline`
- Restore the companion and verify the next poll recovers

Verification commands:
- `cd tools/party-tracker && go test ./...`
- `bash tests/test-party-companion.sh`

## Acceptance Criteria

- [ ] Sidebar shows Codex state, target, elapsed time, and latest verdict from the runtime status file
- [ ] Offline state appears within one poll interval and clears stale data
- [ ] Sidebar recovers automatically when the companion session returns
- [ ] Status file parsing is backed by Go unit tests with fixture JSON, not pane scraping
