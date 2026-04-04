# Task 3 — Generalize Hooks

**Dependencies:** Task 1

## Goal

Rename and parameterize the three Codex-specific hooks (`codex-gate.sh`, `wizard-guard.sh`, `codex-trace.sh`) to be companion-generic. Update `pr-gate.sh` to read required evidence types from `.party.toml` instead of a hardcoded string.

## Scope Boundary

**In scope:**
- Rename `codex-gate.sh` → `companion-gate.sh` — block `approve` subcommand for ANY companion
- Rename `wizard-guard.sh` → `companion-guard.sh` — block direct tmux to ANY companion pane
- Rename `codex-trace.sh` → `companion-trace.sh` — record evidence with companion name as type
- Update `pr-gate.sh` — read `[evidence].required` from `.party.toml` (fall back to current hardcoded default)
- Leave thin redirect stubs at old file paths for transition until Task 5 updates settings.json

**Out of scope:**
- Transport changes (Task 2)
- Session/manifest changes (Task 4)
- settings.json path updates (Task 5)
- Hook test updates (Task 6)

**Design References:** N/A (non-UI task)

## Reference

- `claude/hooks/codex-gate.sh` — Current self-approval blocker (matches `party-cli +transport`)
- `claude/hooks/wizard-guard.sh` — Current direct tmux blocker (matches codex/Wizard refs)
- `claude/hooks/codex-trace.sh` — Current evidence recorder
- `claude/hooks/pr-gate.sh` — Current hardcoded `REQUIRED="... codex ..."`
- `claude/hooks/lib/evidence.sh` — `append_evidence()` accepts arbitrary type strings
- `tools/party-cli/internal/companion/config.go` (Task 1) — `.party.toml` parser for evidence config

## Files to Create/Modify

| File | Action |
|------|--------|
| `claude/hooks/companion-gate.sh` | Create (logic from codex-gate.sh, generalized) |
| `claude/hooks/companion-guard.sh` | Create (logic from wizard-guard.sh, generalized) |
| `claude/hooks/companion-trace.sh` | Create (logic from codex-trace.sh, generalized) |
| `claude/hooks/pr-gate.sh` | Modify — config-driven evidence requirements |
| `claude/hooks/codex-gate.sh` | Modify — redirect stub to companion-gate.sh |
| `claude/hooks/wizard-guard.sh` | Modify — redirect stub to companion-guard.sh |
| `claude/hooks/codex-trace.sh` | Modify — redirect stub to companion-trace.sh |

## Requirements

**Functionality:**
- `companion-gate.sh`: Match `party-cli transport` commands (same as current). Extract companion name from `--to <name>` flag if present (default: "wizard"). Block `approve` subcommand for any companion. Allow all other modes.
- `companion-guard.sh`: Block direct tmux commands targeting any companion pane. Resolve companion roles dynamically — use `party-cli companion list --roles` (or parse `.party.toml` directly) instead of hardcoded "codex" / "Wizard" regex. Still fail-open on parse errors.
- `companion-trace.sh`: After a successful `party-cli transport` command, record evidence using the companion name extracted from `--to` flag (e.g., `append_evidence "$session_id" "wizard" "APPROVED" "$cwd"`). Sentinel detection generalized: companion adapter outputs standardized markers.
- `pr-gate.sh`: Use `party-cli companion evidence-required` (or parse `.party.toml` `[evidence].required` directly). If not set, use current default with `"codex"` replaced by active companion name(s). Quick-tier evidence list unchanged.
- Redirect stubs: Old filenames source the new file and pass through. One-liners.

**Key gotchas:**
- Hooks run in shell — they can't import Go packages directly. Use `party-cli` subcommands to query the registry, or parse `.party.toml` with lightweight shell logic.
- The redirect stubs ensure hooks work during the transition before `settings.json` is updated in Task 5.
- Evidence type changing from `"codex"` to companion name means existing evidence files become stale — this is fine since evidence is per-session.
- `companion-trace.sh` sentinel strings may need to standardize. If the Codex adapter (Task 1) defines standard completion markers, use those.

## Tests

- `companion-gate.sh` blocks `party-cli transport approve` regardless of `--to` value
- `companion-gate.sh` allows `party-cli transport --to wizard review`
- `companion-guard.sh` blocks `tmux send-keys` targeting any companion role's pane
- `companion-trace.sh` records evidence with companion name as type
- `pr-gate.sh` with `.party.toml` `[evidence].required` uses custom list
- `pr-gate.sh` without `.party.toml` uses default with companion name substituted
- Redirect stubs correctly delegate to new files

## Acceptance Criteria

- [ ] All three hooks renamed with companion-generic logic
- [ ] Redirect stubs exist at old paths
- [ ] `companion-gate.sh` blocks `approve` for any companion
- [ ] `companion-guard.sh` resolves companion roles dynamically
- [ ] `companion-trace.sh` records evidence using companion name
- [ ] `pr-gate.sh` reads evidence requirements from `.party.toml`
- [ ] `pr-gate.sh` falls back to defaults when no config exists
