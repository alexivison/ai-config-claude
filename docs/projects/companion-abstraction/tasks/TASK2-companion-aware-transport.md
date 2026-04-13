# Task 2 — Companion-Aware Transport

**Dependencies:** Task 1

## Goal

Parameterize `transport.Service` so all dispatch methods accept a companion name and resolve context via the registry instead of hardcoded `resolveCodexContext()`. Add `--to <name>` flag to the `party-cli transport` CLI command. Rename the `codex-transport` skill to `companion-transport`.

## Scope Boundary

**In scope:**
- `transport.Service`: Replace `resolveCodexContext()` with `resolveCompanionContext(name string)` using `Registry.Get()`
- All `*Opts` structs: Add `Companion string` field
- `CodexStatus` → `CompanionStatus`; status filename → `companion-status-<name>.json`
- Template paths: `codex-transport/templates/` → `companion-transport/templates/wizard/` (companion-scoped)
- `cmd/transport.go`: Add `--to <name>` persistent flag (default: first companion with capability matching the mode)
- `cmd/notify.go`: Use `companion.ParseCompletion()` instead of hardcoded prefix checks
- Rename skill directory: `claude/skills/codex-transport/` → `claude/skills/companion-transport/`
- Update `SKILL.md` for role-based language and `--to` flag

**Out of scope:**
- Hook changes (Task 3)
- Session/manifest changes (Task 4)
- settings.json updates (Task 5)
- Doc updates beyond the transport SKILL.md (Task 7)

**Design References:** N/A (non-UI task)

## Reference

- `tools/party-cli/internal/transport/transport.go` — `resolveCodexContext()`, `Service.Review()`, etc.
- `tools/party-cli/internal/transport/status.go` — `CodexStatus`, `WriteCodexStatus()`
- `tools/party-cli/internal/transport/template.go` — `RenderTemplate()` path resolution
- `tools/party-cli/cmd/transport.go` — Cobra command definitions
- `tools/party-cli/cmd/notify.go` — Completion message prefix checks
- `tools/party-cli/internal/tui/sidebar_status.go` — Reads `codex-status.json` for TUI sidebar display
- `tools/party-cli/internal/tui/sidebar_test.go` — Sidebar status tests

## Files to Create/Modify

| File | Action |
|------|--------|
| `tools/party-cli/internal/transport/transport.go` | Modify — companion-parameterized dispatch |
| `tools/party-cli/internal/transport/status.go` | Modify — `CompanionStatus`, `companion-status-<name>.json` |
| `tools/party-cli/internal/transport/template.go` | Modify — companion-scoped template paths |
| `tools/party-cli/cmd/transport.go` | Modify — `--to` flag |
| `tools/party-cli/cmd/notify.go` | Modify — `ParseCompletion()` via companion interface |
| `tools/party-cli/internal/tui/sidebar_status.go` | Modify — read `companion-status-<name>.json` |
| `tools/party-cli/internal/tui/sidebar_test.go` | Modify — update status filename assertions |
| `claude/skills/codex-transport/` | Rename to `claude/skills/companion-transport/` |
| `claude/skills/companion-transport/SKILL.md` | Modify — role-based language, `--to` flag |

## Requirements

**Functionality:**
- `resolveCompanionContext(name string)` resolves session, runtime dir, and pane target by calling `registry.Get(name)` then `tmux.ResolveRole(companion.Role())`
- All six transport modes work with `--to wizard`: review, plan-review, prompt, review-complete, needs-discussion, triage-override
- Default `--to` value: first companion with capability matching the mode (e.g., `review` mode → first companion with `"review"` capability)
- `CompanionStatus` struct replaces `CodexStatus`; written to `companion-status-<name>.json`
- TUI sidebar (`internal/tui/sidebar_status.go`): Update to read `companion-status-<name>.json` instead of `codex-status.json`. Iterate companion names from the registry (or scan for `companion-status-*.json` files). Update sidebar tests accordingly.
- `notify.go`: Iterates `registry.List()`, calls `ParseCompletion()` on each to detect which companion completed
- Template resolution: `companion-transport/templates/wizard/review.md` (falls back to `companion-transport/templates/review.md` if companion-specific template doesn't exist)
- SKILL.md updated: all `party-cli transport` examples use `--to wizard`; "Codex" → "companion" in plumbing; persona preserved

**Key gotchas:**
- `Codex → Claude` transport (`codex/skills/claude-transport/`) calls `party-cli notify` — its status write needs to use the new filename pattern. Update the notify command, not the Codex-side script.
- Hooks still match `party-cli transport` — Task 3 updates them for `--to`. During transition, hooks pass since they don't inspect `--to` yet.
- The `--to` default resolution must not fail when `.party.toml` doesn't exist (fall back to registry defaults).

## Tests

- `resolveCompanionContext("wizard")` returns same pane target as old `resolveCodexContext()`
- `party-cli transport --to wizard review <dir>` dispatches correctly
- `party-cli transport review <dir>` (no `--to`) defaults to wizard
- Status file created at `companion-status-wizard.json`
- `notify` command correctly identifies completing companion via `ParseCompletion()`
- Template falls back to generic when companion-specific template doesn't exist
- SKILL.md has no hardcoded `codex-transport` or `tmux-codex.sh` references

## Acceptance Criteria

- [ ] `resolveCodexContext()` replaced with `resolveCompanionContext(name)`
- [ ] All `*Opts` structs have `Companion` field
- [ ] `--to <name>` flag works on all transport subcommands
- [ ] Default `--to` resolves via capability
- [ ] `CompanionStatus` replaces `CodexStatus`
- [ ] Status filename is `companion-status-<name>.json`
- [ ] `notify` uses `ParseCompletion()` for companion detection
- [ ] Skill renamed to `companion-transport` with updated SKILL.md
- [ ] Template resolution is companion-scoped with generic fallback
- [ ] TUI sidebar reads `companion-status-<name>.json` (not `codex-status.json`)
