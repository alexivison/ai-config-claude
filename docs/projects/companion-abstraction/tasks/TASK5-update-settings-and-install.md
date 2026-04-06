# Task 5 — Update settings.json and Install

**Dependencies:** Task 2, Task 3

## Goal

Wire the renamed hooks into `settings.json` and make `party-cli install` companion-aware. Remove redirect stubs from Task 3 once settings point to new paths.

## Scope Boundary

**In scope:**
- `claude/settings.json`: Update hook command paths from `codex-*` to `companion-*`
- `tools/party-cli/cmd/install.go`: Make companion-aware (iterate registry for CLI checks and auth prompts)
- Remove redirect stubs at old hook paths (now safe since settings.json points to new names)

**Out of scope:**
- Hook logic changes (already done in Task 3)
- Transport logic changes (already done in Task 2)
- Workflow / CLAUDE.md updates (Task 7)

**Design References:** N/A (non-UI task)

## Reference

- `claude/settings.json` — Current hook paths reference `codex-gate.sh`, `wizard-guard.sh`, `codex-trace.sh`
- `tools/party-cli/cmd/install.go` — Current install command with hardcoded Codex setup
- `claude/hooks/codex-gate.sh` — Redirect stub (from Task 3) to remove

## Files to Create/Modify

| File | Action |
|------|--------|
| `claude/settings.json` | Modify — hook paths |
| `tools/party-cli/cmd/install.go` | Modify — companion-aware install |
| `claude/hooks/codex-gate.sh` | Delete (redirect stub, no longer needed) |
| `claude/hooks/wizard-guard.sh` | Delete (redirect stub, no longer needed) |
| `claude/hooks/codex-trace.sh` | Delete (redirect stub, no longer needed) |

## Requirements

**Functionality:**
- `settings.json` hooks: Replace `codex-gate.sh` → `companion-gate.sh`, `wizard-guard.sh` → `companion-guard.sh`, `codex-trace.sh` → `companion-trace.sh` in all command paths
- `settings.json` permissions: No change needed — `Bash(party-cli:*)` already covers `party-cli transport --to ...`
- `party-cli install`: Load registry. For each companion in `registry.List()`: check if CLI binary exists, prompt user to install if not, prompt for auth if needed. Keep the same interactive UX as current Codex-specific install.
- Codex config directory (`~/.codex`) symlink still created — it's Codex's own config, not ours to rename

**Key gotchas:**
- Deleting the redirect stubs is safe ONLY after settings.json points to the new names. These must happen atomically (same commit).
- **Running session migration:** Sessions started before this task will have the old settings.json cached. Document in the commit message and PR description that active party sessions should be restarted after this change lands. `party-cli install` should warn if old hook paths are detected in any loaded settings.json.
- `party-cli install` must still work with no `.party.toml` (defaults to Codex install flow)

## Tests

- `settings.json` contains no references to `codex-gate.sh`, `wizard-guard.sh`, or `codex-trace.sh`
- `party-cli install` with default registry prompts for Codex
- `party-cli install` with two-companion `.party.toml` prompts for both
- Redirect stubs are deleted

## Acceptance Criteria

- [ ] `settings.json` hook paths all point to `companion-*` named hooks
- [ ] `party-cli install` iterates companions from registry
- [ ] Redirect stubs at old hook paths deleted
- [ ] Codex config symlink still created in default flow
