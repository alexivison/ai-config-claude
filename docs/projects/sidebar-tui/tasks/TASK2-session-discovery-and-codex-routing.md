# Task 2 — Session Discovery And Codex Routing

**Dependencies:** Task 1 | **Issue:** N/A (sidebar-tui-v2)

---

## Goal

Make Codex routing companion-aware without leaking hidden companion sessions into session discovery, picker flows, or user-facing lists, fail closed with explicit liveness and recursion guards when companion metadata goes stale, and add a runtime status file to `tmux-codex.sh` so the sidebar can read structured Codex state instead of scraping pane output.

## Scope Boundary (REQUIRED)

**In scope:**
- Companion-aware `party_role_pane_target()` resolution for `codex`
- Explicit recursion-depth guard and stale-manifest self-healing
- Visible-session helper(s) that exclude `-codex` companions from scan-based UX
- Updating discovery, picker, list, and routing-wrapper semantics to use those helpers
- Runtime status file (`/tmp/<session>/codex-status.json`) written by `tmux-codex.sh` on dispatch and completion, containing `state`, `target`, `start_time`, `last_verdict`, `verdict_time`

**Out of scope (handled by other tasks):**
- Companion creation and teardown mechanics
- Sidebar Bubble Tea rendering or popup actions
- Reading the status file from the Go sidebar (Task 4)

**Cross-task consistency check:**
- Task 1 writes `codex_session`; this task must make that field useful everywhere routing and discovery touch session names.
- Tasks 4 and 5 will assume `party_state_get_field(<session>, "codex_session")` is trustworthy only because this task self-heals stale values and guards recursion.
- Task 4 reads the runtime status file this task introduces; the file format is the contract between `tmux-codex.sh` (writer) and `codex.go` (reader).

## Reference

Files to study before implementing:

- `session/party-lib.sh:295-332` — current scan-based `discover_session()` fallback
- `session/party-lib.sh:397-503` — current role resolver and legacy fallback wrapper
- `session/party-picker.sh:21-126` — active/resumable picker entry generation
- `session/party.sh:346-362` and `session/party.sh:396-438` — bulk stop and active list output
- `claude/skills/codex-transport/scripts/tmux-codex.sh:30-40` — Codex transport entrypoint that consumes the updated routing helpers
- `claude/skills/codex-transport/scripts/tmux-codex.sh:43-106` — `--review` mode where status file writes should happen on dispatch
- `claude/skills/codex-transport/scripts/tmux-codex.sh:134-152` — `--prompt` mode, same
- `claude/skills/codex-transport/scripts/tmux-codex.sh:154-171` — `--review-complete` mode where status file should record verdict
- `tests/test-party-routing.sh:43-150` — existing routing regression style

## Design References (REQUIRED for UI/component tasks)

N/A (non-UI task)

## Data Transformation Checklist (REQUIRED for shape changes)

This task consumes the new `codex_session` field and changes how session-name scans are interpreted.

- [ ] `codex_session` liveness is checked before any recursive resolution
- [ ] Dead companions clear `codex_session` so later reads do not repeat stale lookups
- [ ] Wrapper fallback only applies to legacy two-pane sessions with no roles; sidebar sessions preserve `ROLE_NOT_FOUND`
- [ ] Scan-based helpers exclude `-codex` sessions consistently across discovery, picker, and list flows
- [ ] `tmux-codex.sh` writes `/tmp/<session>/codex-status.json` with `state`, `target`, `start_time`, `last_verdict`, `verdict_time` on dispatch and completion
- [ ] Status file format is documented in code comments as the contract between shell (writer) and Go (reader)

## Files to Create/Modify

| File | Action |
|------|--------|
| `session/party-lib.sh` | Modify |
| `session/party-picker.sh` | Modify |
| `session/party.sh` | Modify if visible-session helper is reused by bulk stop/list |
| `tests/test-party-routing.sh` | Modify |
| `claude/skills/codex-transport/scripts/tmux-codex.sh` | Modify (add runtime status file writes on dispatch/completion) |

## Requirements

**Functionality:**
- Extend `party_role_pane_target()` so a missing `codex` role in the main session consults the parent manifest's `codex_session`, verifies the companion is live, and resolves its pane with a hard max recursion depth of one.
- Clear stale `codex_session` values when the manifest points at a dead companion.
- Refine `party_role_pane_target_with_fallback()` so sidebar sessions with role metadata preserve `ROLE_NOT_FOUND` instead of degrading to `ROUTING_UNRESOLVED`; legacy fallback remains limited to two-pane sessions with no roles.
- Add shared helpers for "all party sessions" versus "visible party sessions" and switch scan-based discovery, picker, and list code to the visible set.
- Preserve the existing `_require_session()` contract in `tmux-codex.sh`; the transport should work because its dependency changed, not because every caller was rewritten.
- Add runtime status file writes to `tmux-codex.sh`: on `--review` and `--prompt` dispatch, write `{"state":"reviewing","target":"<title>","start_time":"<ISO>"}` to `/tmp/<session>/codex-status.json`. On `--review-complete`, update with `{"state":"idle","last_verdict":"APPROVED|REQUEST_CHANGES","verdict_time":"<ISO>"}`. This replaces fragile pane scraping — the sidebar reads this file instead of parsing Codex CLI output.

**Key gotchas:**
- Hidden companions still use the `party-` prefix, so any remaining raw `grep '^party-'` scan will leak them back into UX or create ambiguous discovery.
- Relying on the absence of companion manifests is not enough; recursion depth must be explicit.
- The wrapper's current legacy fallback can mask a true sidebar-session `ROLE_NOT_FOUND` unless its semantics are tightened.
- The status file must use atomic writes (write to tmp + mv) to avoid partial reads by the sidebar's Go polling loop.

## Tests

Test cases:
- Resolve `codex` through a live companion session
- Kill the companion and verify routing returns `ROLE_NOT_FOUND` while clearing stale metadata
- Verify legacy two-pane sessions without roles still use the existing fallback
- Verify discovery and picker/list helpers ignore `-codex` sessions
- Verify `tmux-codex.sh --review` writes status file with `state=reviewing` and correct target
- Verify `tmux-codex.sh --review-complete` updates status file with verdict and timestamp

Verification commands:
- `bash tests/test-party-routing.sh`
- `bash tests/test-party-companion.sh`

## Acceptance Criteria

- [ ] Codex routing resolves a live companion session and never recurses more than once
- [ ] Dead or stale companions clear `codex_session` and fail closed
- [ ] Legacy no-role two-pane sessions still work through the existing fallback
- [ ] Hidden companions do not appear in `discover_session()`, picker output, or active-session lists
- [ ] `tmux-codex.sh` routing works through the updated library helpers
- [ ] `tmux-codex.sh` writes runtime status file atomically on dispatch and completion
- [ ] Status file format is stable and documented as the shell↔Go contract
