# Task 1 — Companion Interface, Registry, and Config

**Dependencies:** [PR #119](https://github.com/alexivison/ai-config/pull/119) (must be merged)

## Goal

Create the foundation layer in Go: a `Companion` interface, a `Registry` that loads companion definitions from `.party.toml`, a config parser, and the first implementation (Codex). Nothing uses this yet — later tasks wire it into transport, sessions, and hooks.

## Scope Boundary

**In scope:**
- `tools/party-cli/internal/companion/companion.go` — `Companion` interface + `Registry` type
- `tools/party-cli/internal/companion/codex.go` — Codex implementation of `Companion`
- `tools/party-cli/internal/companion/config.go` — `.party.toml` parsing + default config
- `tools/party-cli/cmd/companion.go` — `party-cli companion query` subcommand (bridge for shell hooks)
- Add TOML dependency (`github.com/BurntSushi/toml` or equivalent)

**Out of scope:**
- Modifying `transport.Service` (Task 2)
- Modifying hooks (Task 3)
- Modifying session startup or manifest (Task 4)
- Stub companion (Task 8)

**Design References:** N/A (non-UI task)

## Reference

Files to study before implementing (on the PR #119 branch):

- `tools/party-cli/internal/transport/transport.go` — Current `resolveCodexContext()` and dispatch patterns
- `tools/party-cli/internal/transport/status.go` — `CodexStatus` struct to generalize
- `tools/party-cli/cmd/notify.go` — Completion detection prefixes to extract into `ParseCompletion()`
- `tools/party-cli/internal/state/manifest.go` — `ExtraString("codex_thread_id")` pattern

## Files to Create/Modify

| File | Action |
|------|--------|
| `tools/party-cli/internal/companion/companion.go` | Create |
| `tools/party-cli/internal/companion/codex.go` | Create |
| `tools/party-cli/internal/companion/config.go` | Create |
| `tools/party-cli/internal/companion/companion_test.go` | Create — unit tests for registry, config, Codex implementation |
| `tools/party-cli/cmd/companion.go` | Create — `party-cli companion query` subcommand |
| `tools/party-cli/go.mod` | Modify — add TOML dependency |
| `tools/party-cli/go.sum` | Modify — dependency lock |

## Requirements

**Functionality:**
- `Companion` interface with methods: `Name()`, `CLI()`, `Role()`, `Capabilities()`, `Start(ctx, StartOpts)`, `ParseCompletion()`
- `StartOpts` struct with `Session`, `CWD`, `ThreadID`, `Window` fields (window is a layout concern, not core identity)
- `Registry` with: `NewRegistry(cfg *Config)`, `Get(name)`, `List()`, `ForCapability(cap)`, `Names()`
- `Config` struct parsed from `.party.toml` using TOML library
- Config resolution: `.party.toml` in CWD → walk up to git root → hardcoded defaults
- Codex `Companion` implementation that returns `Name()="wizard"`, `CLI()="codex"`, `Role()="analyzer"`, `Capabilities()=["review","plan","prompt"]`
- Codex `ParseCompletion()` extracts completion from the hardcoded prefixes currently in `notify.go` (`"Review complete. Findings at: "`, etc.)
- Default config (no `.party.toml`) produces a registry with one companion: wizard/codex
- `party-cli companion query` subcommand with three modes: `roles` (list companion roles), `names` (list companion names), `evidence-required` (list required evidence types). Output is newline-delimited plain text. This is the bridge for shell hooks that cannot import Go — Task 3 hooks consume this.

**Key gotchas:**
- The `Start()` method signature must account for thread resumption (Codex uses `CODEX_THREAD_ID` env var)
- Config must handle missing `.party.toml` gracefully (defaults, not errors)
- The `Companion` interface should be stable — later tasks depend on it, so changing it means cascading updates

## Tests

- `NewRegistry` with no `.party.toml` → returns registry with one companion named "wizard"
- `NewRegistry` with `.party.toml` defining two companions → both present in `List()`
- `Get("wizard")` returns Codex companion with correct metadata
- `ForCapability("review")` returns the wizard
- `ForCapability("nonexistent")` returns error
- Codex `ParseCompletion("Review complete. Findings at: /tmp/f.toon")` returns correct `CompletionResult`
- Codex `ParseCompletion("random message")` returns false
- Config resolution walks up to git root
- `party-cli companion query roles` outputs "analyzer" for default config
- `party-cli companion query names` outputs "wizard" for default config
- `party-cli companion query evidence-required` outputs default evidence types

## Acceptance Criteria

- [ ] `Companion` interface defined with all methods
- [ ] `Registry` loads from `.party.toml` or defaults
- [ ] Codex implementation passes all metadata and completion tests
- [ ] Config parser handles missing file gracefully
- [ ] TOML dependency added to go.mod
- [ ] `companion_test.go` covers registry creation, `Get()`, `ForCapability()`, config resolution, and Codex `ParseCompletion()`
- [ ] `party-cli companion query` subcommand works for `roles`, `names`, and `evidence-required`
- [ ] No existing files modified (pure addition to `internal/companion/` and `cmd/companion.go`)
