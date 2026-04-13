# Companion Abstraction Design

> **Specification:** [SPEC.md](./SPEC.md)

## Prerequisite

This design targets the codebase after [PR #119](https://github.com/alexivison/ai-config/pull/119) lands. PR #119 consolidates shell scripts into `party-cli` Go binary, giving us:
- `transport.Service` with `Review()`, `PlanReview()`, `Prompt()`, etc.
- `tmux.Client` with `ResolveRole()` for pane resolution by `@party_role`
- `state.Store` with flock-protected manifest persistence and `Extra` map
- `CodexStatus` struct for companion state tracking
- `party-cli transport <mode>` as the unified CLI command

The companion abstraction layers on top of these Go primitives — not the deleted shell scripts.

## Architecture Overview

The design introduces three new concepts:

1. **Companion Interface** — A Go interface (`Companion`) that each companion CLI implements, covering startup, completion detection, and metadata
2. **Companion Registry** — A Go package that loads companion definitions from `.party.toml` (project-level) with hardcoded defaults, and resolves names to implementations
3. **Project Config** (`.party.toml`) — Per-repo overrides for companion selection, layout, spec format, and evidence requirements

The execution core, sub-agents, and evidence system are untouched. Only the transport service and session startup change.

```
┌─────────────────────────────────────────────────┐
│                  Execution Core                  │
│  (sequence, evidence, critics, dispute — NO      │
│   changes)                                       │
└────────────────────┬────────────────────────────┘
                     │ "send to wizard"
                     ▼
┌─────────────────────────────────────────────────┐
│        transport.Service (companion-aware)        │
│  resolve name → Companion → dispatch via tmux    │
└───────┬─────────────┬───────────────┬───────────┘
        ▼             ▼               ▼
   ┌─────────┐  ┌──────────┐  ┌────────────┐
   │  Codex   │  │  Gemini  │  │   Stub/    │
   │Companion │  │Companion │  │  Example   │
   └─────────┘  └──────────┘  └────────────┘
```

## Existing Standards (post-PR #119)

| Pattern | Location | How It Applies |
|---------|----------|----------------|
| Transport dispatch | `tools/party-cli/internal/transport/transport.go` (`Service.Review()`, etc.) | Add `companion string` parameter; resolve via registry instead of hardcoded `resolveCodexContext()` |
| Role-based pane resolution | `tools/party-cli/internal/tmux/query.go` (`ResolveRole()`) | Already parameterized by role string — pass companion role from registry |
| Manifest extras | `tools/party-cli/internal/state/manifest.go` (`ExtraString()`) | Use `companion_<name>_thread_id` pattern for per-companion state |
| Status persistence | `tools/party-cli/internal/transport/status.go` (`CodexStatus`) | Generalize to `CompanionStatus`; filename becomes `companion-status-<name>.json` |
| Template rendering | `tools/party-cli/internal/transport/template.go` (`RenderTemplate()`) | Template path becomes `companion-transport/templates/<name>/review.md` |
| Evidence recording | `claude/hooks/lib/evidence.sh` (`append_evidence()`) | Already accepts agent type as string — no change needed |
| TOON findings format | `shared/references/agent-transport/scripts/toon-transport.sh` | Already companion-agnostic — no change needed |
| Runner interface | `tools/party-cli/internal/tmux/` (`Runner` interface) | Enables mocking for companion adapter tests |
| Hook PreToolUse | `claude/hooks/codex-gate.sh`, `codex-trace.sh` | Pattern match `party-cli transport` + extract companion name from `--to` flag |

## File Structure

```
tools/party-cli/
├── internal/
│   ├── companion/
│   │   ├── companion.go          # Create — Companion interface + registry
│   │   ├── codex.go              # Create — Codex implementation
│   │   ├── stub.go               # Create — Example stub implementation
│   │   └── config.go             # Create — .party.toml parsing
│   ├── transport/
│   │   ├── transport.go          # Modify — companion-parameterized dispatch
│   │   ├── status.go             # Modify — CompanionStatus (was CodexStatus)
│   │   ├── transport_test.go     # Modify — multi-companion test cases
│   │   └── template.go           # Modify — companion-scoped template paths
│   ├── state/
│   │   └── manifest.go           # Modify — Companions array
│   ├── tui/
│   │   └── sidebar_status.go     # Modify — read companion-status-<name>.json
│   └── tmux/
│       └── query.go              # No change — ResolveRole() already generic
├── cmd/
│   ├── companion.go              # Create — `party-cli companion query` subcommand
│   ├── transport.go              # Modify — add --to flag
│   ├── start.go                  # Modify — dynamic companion startup
│   ├── continue.go               # Modify — multi-companion resume
│   └── install.go                # Modify — companion-aware install
claude/
├── skills/
│   ├── companion-transport/      # Rename from codex-transport/
│   │   ├── SKILL.md              # Modify — role-based dispatch, --to flag
│   │   └── templates/
│   │       └── wizard/           # Create — per-companion template subdir
│   │           └── review.md     # Move from codex-transport/templates/
├── hooks/
│   ├── companion-gate.sh         # Rename from codex-gate.sh
│   ├── companion-guard.sh        # Rename from wizard-guard.sh
│   ├── companion-trace.sh        # Rename from codex-trace.sh
│   └── pr-gate.sh                # Modify — config-driven evidence requirements
```

**Legend:** `Create` = new file, `Modify` = edit existing, `Rename` = move + modify

## Companion Interface (Go)

```go
// internal/companion/companion.go

type Companion interface {
    // Identity
    Name() string              // "wizard" — used in transport addressing
    CLI() string               // "codex" — binary name
    Role() string              // "analyzer" — tmux @party_role value
    Capabilities() []string    // ["review", "plan", "prompt"]

    // Lifecycle
    Start(ctx context.Context, opts StartOpts) error
    ParseCompletion(message string) (*CompletionResult, bool)
}

type StartOpts struct {
    Session  string
    CWD      string
    ThreadID string // for resumption (e.g. Codex uses CODEX_THREAD_ID env var)
    Window   int    // tmux window index — layout concern, not core identity
}

type CompletionResult struct {
    Mode         string // "review", "plan-review", "prompt"
    FindingsFile string // path to TOON findings
    Verdict      string // "APPROVED", "REQUEST_CHANGES", etc.
}

type Registry struct {
    companions map[string]Companion
    order      []string              // .party.toml declaration order; deterministic iteration
}

func NewRegistry(cfg *Config) *Registry          // from .party.toml or defaults
func (r *Registry) Get(name string) (Companion, error)
func (r *Registry) List() []Companion
func (r *Registry) ForCapability(cap string) (Companion, error)  // returns first match in .party.toml declaration order (deterministic)
func (r *Registry) Names() []string
```

The **Codex companion** (`codex.go`) implements this interface using the existing transport logic from PR #119. `ParseCompletion()` checks for the hardcoded `"Review complete. Findings at: "` prefixes that are currently in `notify.go`.

## Companion Registry & Config

```go
// internal/companion/config.go

type Config struct {
    Party      PartyConfig                `toml:"party"`
    Companions map[string]CompanionConfig `toml:"companions"`
    Specs      SpecsConfig                `toml:"specs"`
    Evidence   EvidenceConfig             `toml:"evidence"`
}

type CompanionConfig struct {
    CLI          string   `toml:"cli"`
    Role         string   `toml:"role"`
    Capabilities []string `toml:"capabilities"`
    PaneWindow   int      `toml:"pane_window"`  // tmux layout concern — passed via StartOpts, not on interface
}
```

**Resolution order:** `.party.toml` in CWD → walk up to git root → hardcoded defaults.

**Defaults** (when no `.party.toml` exists):

```toml
[companions.wizard]
cli = "codex"
role = "analyzer"
capabilities = ["review", "plan", "prompt"]
pane_window = 0
```

## Project Config (`.party.toml`)

```toml
# .party.toml — optional, lives in repo root
# Absence = defaults (Codex as wizard, classic layout, full tier)

[party]
layout = "classic"                 # classic | sidebar

[companions.wizard]
cli = "codex"                      # CLI binary name
role = "analyzer"                  # semantic role for @party_role
capabilities = ["review", "plan", "prompt"]
pane_window = 0                    # tmux window index (0 = hidden)

# Example second companion (commented out):
# [companions.oracle]
# cli = "gemini-cli"
# role = "researcher"
# capabilities = ["prompt", "research"]
# pane_window = 2

[specs]
format = "internal"                # internal | openspec (future adapter)

[evidence]
# Override required evidence types for pr-gate
# Default: ["pr-verified", "code-critic", "minimizer", "companion", "test-runner", "check-runner"]
# Set to skip companion review (e.g. solo mode):
# required = ["pr-verified", "code-critic", "minimizer", "test-runner", "check-runner"]
```

## Data Flow (Transport Routing — post-PR #119)

```
Claude skill invokes:
  party-cli transport --to wizard review <work_dir>
       │
       ▼
  cmd/transport.go (Cobra command)
       │
       ├── registry.Get("wizard") → Codex companion
       ├── tmux.ResolveRole(companion.Role()) → pane target
       ├── transport.RenderTemplate("wizard/review.md", vars)
       └── svc.Review(ctx, ReviewOpts{Companion: "wizard", ...})
              │
              ├── tmux.Send(pane, rendered message)
              ├── WriteCompanionStatus("wizard", "working", ...)
              └── return ReviewResult{FindingsFile}

  ... Codex works ...

  Codex completes → party-cli notify "Review complete. Findings at: ..."
       │
       ▼
  cmd/notify.go
       │
       ├── registry.List() → iterate companions
       ├── companion.ParseCompletion(message) → match Codex
       ├── ParseVerdict(findingsFile)
       └── WriteCompanionStatus("wizard", "idle", verdict)
```

## Hook Bridge: `party-cli companion query`

Shell hooks cannot import Go packages. A `party-cli companion query` subcommand bridges the gap — hooks call it to read registry/config state without parsing TOML themselves.

```
party-cli companion query roles              # list all companion roles (one per line)
party-cli companion query names              # list all companion names (one per line)
party-cli companion query evidence-required  # list required evidence types (one per line)
```

Reads `.party.toml` using the same resolution logic as the registry (CWD → git root → defaults). Output is newline-delimited plain text for easy consumption by `grep`/`while read`.

This subcommand is created in **Task 1** (alongside the registry) and consumed by **Task 3** hooks.

## Integration Points (post-PR #119)

| Point | PR #119 Code | Companion Abstraction Change |
|-------|-------------|------------------------------|
| Transport dispatch | `resolveCodexContext()` hardcoded role="codex" | `resolveCompanionContext(name)` via registry |
| Transport methods | `Service.Review(ReviewOpts)` | Add `Companion string` field to all `*Opts` structs |
| Status struct | `CodexStatus` + `codex-status.json` | `CompanionStatus` + `companion-status-<name>.json` |
| Template paths | `codex-transport/templates/review.md` | `companion-transport/templates/<name>/review.md` |
| Completion detection | Hardcoded prefixes in `notify.go` | `companion.ParseCompletion(msg)` per companion |
| Manifest | `CodexBin` field + `codex_thread_id` extra | `Companions []CompanionState` typed field |
| Session startup | `cmd/start.go` launches one Codex window | Iterates `registry.List()`, calls `companion.Start()` per entry |
| Session resume | `continue.go` reads `codex_thread_id` | Iterates `manifest.Companions` for each thread ID |
| CLI command | `party-cli transport review` | `party-cli transport --to wizard review` (default: first w/ capability) |
| PreToolUse gate | `codex-gate.sh` matches `party-cli +transport` | `companion-gate.sh` extracts `--to <name>`, blocks `approve` for any companion |
| PreToolUse guard | `wizard-guard.sh` matches codex/Wizard tmux refs | `companion-guard.sh` calls `party-cli companion query roles` to resolve all companion roles |
| PostToolUse trace | `codex-trace.sh` records evidence type "codex" | `companion-trace.sh` records evidence type = companion name |
| PR gate | `pr-gate.sh` hardcodes `REQUIRED="... codex ..."` | Calls `party-cli companion query evidence-required`; falls back to default with companion name |
| Install | `party-cli install` hardcodes Codex setup | Iterates registered companions for CLI checks and auth |
| TUI sidebar | `sidebar_status.go` reads `codex-status.json` | Read `companion-status-<name>.json`; iterate companions or scan for status files |
| Permissions | `Bash(party-cli:*)` in settings.json | No change needed — already covers `party-cli transport --to ...` |

## Design Decisions

| Decision | Rationale | Alternatives Considered |
|----------|-----------|-------------------------|
| Go `Companion` interface (not shell adapters) | PR #119 already moved transport to Go; shell adapters would re-introduce the shell layer we just removed | Shell adapter scripts (rejected: contradicts #119 direction) |
| `.party.toml` parsed in Go, exposed via `party-cli companion query` | `party-cli` owns config; hooks call query subcommand instead of parsing TOML in shell | Shell TOML parsing (rejected: #119 removes shell scripts; fragile and duplicates logic) |
| Interface with concrete types (not plugin system) | New companions are added as Go files + rebuild; simpler than plugin loading. Config selects which registered adapter is active — `.party.toml` controls *selection*, not *definition*. Adding a companion with novel completion parsing requires a Go adapter. | Go plugin system (rejected: fragile, platform-dependent); fully config-driven generic adapter (rejected: completion parsing is CLI-specific, can't be fully generalized without per-CLI logic) |
| `--to <name>` on CLI command | Explicit routing is simpler and debuggable; capability routing layers on top | Capability-only routing (rejected: ambiguous when multiple companions share a capability) |
| Default to Codex when no config | Zero-config backward compatibility; existing users don't need `.party.toml` | Require `.party.toml` (rejected: breaking change) |
| Evidence type = companion name | `append_evidence()` already accepts arbitrary type strings; `"wizard"` instead of `"codex"` | Separate evidence namespace (rejected: unnecessary indirection) |
| Rename hook files (not parameterize existing) | Clean break; stubs at old paths for transition | Keep codex-* names (rejected: confusing once system is multi-companion) |

## External Dependencies

- **Go TOML parser:** `github.com/BurntSushi/toml` or `github.com/pelletier/go-toml/v2` for `.party.toml` parsing
- **No new CLI tools required for v1.** Companion CLIs are user-provided; only the Go interface and Codex implementation are new code.
