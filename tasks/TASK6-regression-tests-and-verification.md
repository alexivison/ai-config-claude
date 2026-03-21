# Task 6 — Regression Tests And Verification

**Dependencies:** Task 1, Task 2, Task 3, Task 4, Task 5 | **Issue:** N/A (sidebar-tui-v2)

---

## Goal

Lock the feature behind repeatable regression coverage so companion lifecycle, sidebar→master promotion, hidden-session filtering, companion-aware routing, runtime status file, classic compatibility, and sidebar parsing behavior remain provable after future shell and UI changes.

## Scope Boundary (REQUIRED)

**In scope:**
- Shell regression coverage for launch, cleanup, promotion, routing, and hidden-session filtering
- Go unit tests for sidebar parsing/helpers and status file reading
- Test-runner updates and verification commands

**Out of scope (handled by other tasks):**
- New feature behavior itself
- Additional UX polish beyond what tests must assert

**Cross-task consistency check:**
- Every new contract introduced in Tasks 1-5 must be covered here at least once.
- Companion lifecycle tests must prove the failsafe requirements from the source prompt, including stale metadata clearing and bulk-stop exclusion.

## Reference

Files to study before implementing:

- `tests/run-tests.sh:1-37` — top-level shell test runner
- `tests/test-party-routing.sh:1-150` — routing regression patterns and lightweight tmux mocks
- `tests/test-party-master.sh:27-112` — manifest setup/cleanup style
- `tools/party-tracker/go.mod:1-33` — Go test module boundary for sidebar parser tests

## Design References (REQUIRED for UI/component tasks)

N/A (non-UI task)

## Data Transformation Checklist (REQUIRED for shape changes)

N/A (verification task)

## Files to Create/Modify

| File | Action |
|------|--------|
| `tests/test-party-routing.sh` | Modify |
| `tests/test-party-companion.sh` | Create |
| `tests/run-tests.sh` | Modify |
| `tools/party-tracker/codex_test.go` | Create |
| `tools/party-tracker/sidebar_test.go` | Create if render helpers warrant direct tests |

## Requirements

**Functionality:**
- Add shell coverage for companion creation, cleanup through all teardown paths, sidebar→master promotion (companion killed, `codex_session` cleared, tracker in pane 0), stale-companion self-healing, hidden-session filtering, runtime status file writes, and classic-layout fallback.
- Extend routing tests so sidebar sessions preserve `ROLE_NOT_FOUND`, legacy sessions retain two-pane fallback, and recursion depth is guarded.
- Add Go tests for status-file parsing, verdict-age/elapsed helpers, and narrow-width sidebar rendering helpers as needed.
- Keep Go tests stdlib-only and use `t.Parallel()` where test isolation allows it.

**Key gotchas:**
- Bulk stop must be tested against companion exclusion explicitly; this is a source-level requirement, not an incidental behavior.
- Tests should avoid depending on a live Codex binary; use fixtures, mocked tmux output, or minimal detached tmux sessions instead.
- Verification must cover master-session non-regression, not just worker/standalone success cases.

## Tests

Test cases:
- Companion launch, stop, delete, and session-closed cleanup
- Sidebar→master promotion: companion killed, `codex_session` cleared, tracker visible in pane 0
- Hidden companion exclusion from discovery, picker, and list flows
- Dead companion self-healing and wrapper semantics
- Runtime status file: written on dispatch, updated on completion, read correctly by Go
- Classic layout compatibility and master-session non-regression
- Status file parsing cases for reviewing, done, idle (missing file), offline (dead companion), and stale verdict handling

Verification commands:
- `bash tests/run-tests.sh`
- `cd tools/party-tracker && go test ./...`

## Acceptance Criteria

- [ ] Shell tests cover companion lifecycle, promotion, and hidden-session filtering end to end
- [ ] Go tests cover status-file parsing and any sidebar helper logic that is easy to regress
- [ ] Verification commands pass from the repository root
- [ ] The full feature remains provable without relying on manual tmux inspection alone
