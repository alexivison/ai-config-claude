# Task 4 — Companion-Aware Sessions and Manifest

**Dependencies:** Task 1

## Goal

Make session startup and manifest state companion-generic. `cmd/start.go` creates companion windows dynamically from the registry. `cmd/continue.go` resumes N companions. The manifest `Companions[]` replaces Codex-specific fields.

## Scope Boundary

**In scope:**
- `cmd/start.go` (or `cmd/spawn.go`): Iterate `registry.List()`, call `companion.Start()` for each companion during session setup
- `cmd/continue.go`: Iterate `manifest.Companions` to resume each companion with its thread ID
- `internal/state/manifest.go`: Add `Companions []CompanionState` typed field; migrate `CodexBin` + `codex_thread_id` extra into this structure
- Runtime status: `notify.go` already writes to `companion-status-<name>.json` (from Task 2); ensure session queries use the new pattern

**Out of scope:**
- Transport changes (Task 2)
- Hook changes (Task 3)
- settings.json / install changes (Task 5)
- Workflow doc updates (Task 7)

**Design References:** N/A (non-UI task)

## Reference

- `tools/party-cli/cmd/start.go` — Current session startup (launches Codex in window 0)
- `tools/party-cli/cmd/continue.go` — Current resume (reads `codex_thread_id` from extras)
- `tools/party-cli/internal/state/manifest.go` — `CodexBin` field, `ExtraString("codex_thread_id")`
- `tools/party-cli/internal/companion/companion.go` (Task 1) — `Companion.Start()`, `Registry.List()`

## Files to Create/Modify

| File | Action |
|------|--------|
| `tools/party-cli/internal/state/manifest.go` | Modify — add `Companions []CompanionState` |
| `tools/party-cli/cmd/start.go` | Modify — dynamic companion startup |
| `tools/party-cli/cmd/continue.go` | Modify — multi-companion resume |

## Requirements

**Functionality:**
- `CompanionState` struct: `Name string`, `CLI string`, `Role string`, `Pane string`, `Window int`, `ThreadID string`
- `manifest.Companions` persisted in JSON alongside existing fields
- Session startup: Load registry from `.party.toml` (or defaults). For each companion in `registry.List()`: check if CLI is installed (`exec.LookPath`), warn and skip if not, otherwise call `companion.Start(ctx, session, window, cwd, "")` and record the `CompanionState` in the manifest
- Session resume: Read `manifest.Companions`, for each entry call `companion.Start(ctx, session, state.Window, cwd, state.ThreadID)` to resume with thread context
- Backward compatibility: If manifest has `codex_thread_id` in `Extra` (old format), migrate to a `Companions` entry on read. If `CodexBin` exists, populate from it.
- Missing CLI: Warn ("wizard companion (codex) not found, skipping") but don't fail session startup. Session runs Claude-only.

**Key gotchas:**
- `Companion.Start()` must handle the `CODEX_NOT_AVAILABLE` env var pattern — if the CLI isn't found, set this so transport commands fail gracefully instead of hanging
- The pane target recorded in `CompanionState.Pane` must be the resolved `session:window.pane` string for later use by transport
- `CodexBin` field in manifest can be deprecated but must still be readable for backward compat
- Go manifest custom `UnmarshalJSON`/`MarshalJSON` already preserves unknown fields; `Companions` needs to be a known field

## Tests

- Session startup with default registry → one companion window created (wizard/codex)
- Session startup with two-companion `.party.toml` → two companion windows created
- Session startup with missing companion CLI → warning logged, session continues without it
- Manifest round-trip: write `Companions` array → read back → fields preserved
- Old manifest with `codex_thread_id` extra → migrated to `Companions[0].ThreadID` on read
- Resume with `Companions` → each companion's `Start()` called with correct thread ID

## Acceptance Criteria

- [ ] `CompanionState` struct exists in manifest
- [ ] `cmd/start.go` iterates registry and starts companions dynamically
- [ ] Missing companion CLI produces warning, not failure
- [ ] `cmd/continue.go` resumes all companions from manifest state
- [ ] Old manifests with `codex_thread_id` backward-compatible
- [ ] Manifest JSON includes `companions` array
