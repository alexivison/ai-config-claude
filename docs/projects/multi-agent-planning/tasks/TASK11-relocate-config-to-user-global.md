# Task 11 — Relocate Config to User-Global Only (Drop `.party.toml`)

**Dependencies:** Tasks 1–10 (this task modifies code they created)
**Branch:** `feature/multi-agent-planning` (or a follow-up branch after Tasks 1–10 land)

## Goal

Remove `.party.toml` repo-level config entirely. Agent selection is a user preference, not a repo property — storing it in repos creates git noise (users must `.gitignore` the file, or it gets accidentally committed and forces agent choices on collaborators). Replace with a user-global config at `~/.config/party-cli/config.toml` (XDG-aware).

Add a `party-cli config` subcommand so users can manage preferences without editing TOML directly.

## Scope Boundary

**In scope:**
- `tools/party-cli/internal/agent/config.go` — Remove `findConfigPath()` git-root walk; look up user-global path only
- `tools/party-cli/cmd/config.go` — New `party-cli config` subcommand (init, show, path, set-primary, set-companion, unset-companion)
- `tools/party-cli/cmd/root.go` — Register the new config subcommand
- `tools/party-cli/cmd/agent.go` — Remove `repoRoot` parameter dependency for config path resolution (query should read user-global)
- `tools/party-cli/internal/agent/config_test.go` — Update tests for user-global resolution
- Documentation updates: README.md, CLAUDE.md references, DESIGN.md

**Out of scope:**
- Keeping `.party.toml` as an optional fallback (we're dropping it entirely for simplicity)
- Migration from existing `.party.toml` files (users just run `party-cli config init` once)

## Reference Files

### Current config resolution (to be refactored)

- `tools/party-cli/internal/agent/config.go` — Current `LoadConfig` walks from CWD up to git root looking for `.party.toml`. Replace with user-global lookup.
  - Lines 63-90: `LoadConfig()` — simplify to check user-global path only
  - Lines 141-168: `findConfigPath()` — replace with `userConfigPath()` that resolves XDG/HOME
  
- `tools/party-cli/cmd/agent.go` — Lines 25-33: reads `repoRoot` then calls `LoadConfig(cwd, nil)`. After refactor, `LoadConfig` no longer needs CWD.

### Existing subcommand pattern

- `tools/party-cli/cmd/agent.go` — Shows how to build a subcommand with modes (roles, names, primary-name, etc.). The `config` subcommand follows the same pattern.

- `tools/party-cli/cmd/root.go` — Lines 86-104: shows where to register the new subcommand (`root.AddCommand(newConfigCmd())`).

### XDG resolution reference

Standard Go pattern for XDG config dir:

```go
func userConfigDir() (string, error) {
    if xdg := os.Getenv("XDG_CONFIG_HOME"); xdg != "" {
        return filepath.Join(xdg, "party-cli"), nil
    }
    home, err := os.UserHomeDir()
    if err != nil {
        return "", err
    }
    return filepath.Join(home, ".config", "party-cli"), nil
}
```

Go 1.13+ also provides `os.UserConfigDir()` which handles this across platforms.

## Files to Create/Modify

| File | Action | Key Changes |
|------|--------|-------------|
| `tools/party-cli/internal/agent/config.go` | Modify | Replace `findConfigPath(cwd)` with `userConfigPath()`; drop CWD parameter from `LoadConfig` |
| `tools/party-cli/internal/agent/config_test.go` | Modify | Update tests — no more CWD/git-root walks; test XDG resolution instead |
| `tools/party-cli/cmd/config.go` | Create | New subcommand with init, show, path, set-primary, set-companion, unset-companion |
| `tools/party-cli/cmd/config_test.go` | Create | Tests for each config subcommand mode |
| `tools/party-cli/cmd/agent.go` | Modify | Drop `repoRoot` from `newAgentCmd` — query reads user-global |
| `tools/party-cli/cmd/root.go` | Modify | Register `newConfigCmd()` |
| `tools/party-cli/cmd/start.go` | Modify | Drop CWD-based config lookup; use `LoadConfig(nil)` with flag overrides only |
| `tools/party-cli/cmd/spawn.go` | Modify | Same as start.go |
| `tools/party-cli/internal/session/service.go` | Modify | Remove any `repoRoot`-for-config logic |
| `claude/hooks/*.sh` | Modify | Hooks calling `party-cli agent query` no longer pass repo paths; query reads user-global |
| `claude/hooks/tests/*.sh` | Modify | Update hook tests that depended on `.party.toml` in test fixtures |
| `tests/test-party-routing.sh` | Modify (if applicable) | Remove any `.party.toml` fixture creation |
| `README.md` | Modify | Replace `.party.toml` docs with `party-cli config` docs |
| `claude/CLAUDE.md` | Modify | Same |

## Requirements

### LoadConfig signature change

**Before:**
```go
func LoadConfig(cwd string, overrides *ConfigOverrides) (*Config, error)
```

**After:**
```go
func LoadConfig(overrides *ConfigOverrides) (*Config, error)
```

Implementation:
```go
func LoadConfig(overrides *ConfigOverrides) (*Config, error) {
    path, err := UserConfigPath()
    if err != nil {
        return nil, err
    }
    
    var cfg *Config
    if _, statErr := os.Stat(path); os.IsNotExist(statErr) {
        cfg = DefaultConfig()
    } else if statErr != nil {
        return nil, fmt.Errorf("stat %s: %w", path, statErr)
    } else {
        cfg, err = loadConfigFile(path)
        if err != nil {
            return nil, err
        }
    }

    applyOverrides(cfg, overrides)
    hydrateReferencedAgents(cfg)
    return cfg, nil
}

// UserConfigPath returns the path to the user-global config file.
func UserConfigPath() (string, error) {
    dir, err := os.UserConfigDir()  // respects XDG_CONFIG_HOME
    if err != nil {
        return "", err
    }
    return filepath.Join(dir, "party-cli", "config.toml"), nil
}
```

### `party-cli config` subcommand

```
party-cli config init              # create ~/.config/party-cli/config.toml with commented defaults
party-cli config show              # print current resolved config (merged with defaults)
party-cli config path              # print absolute path of config file
party-cli config set-primary NAME  # set roles.primary.agent = NAME
party-cli config set-companion NAME # set roles.companion.agent = NAME
party-cli config unset-companion   # remove roles.companion (run without companion by default)
```

All modes that modify the file:
1. Load existing config (or defaults if missing)
2. Apply the requested mutation
3. Write atomically (write to `.tmp` then rename)
4. Print a confirmation line like `primary set to "codex"`

`config init` writes a template file with commented explanations:

```toml
# party-cli config — user-global agent preferences
# Location: ~/.config/party-cli/config.toml
#
# This file controls which agents party-cli uses. Delete it to revert to defaults
# (Claude as primary, Codex as companion).
#
# CLI flags override this file per-session:
#   party.sh --primary codex "task"   # one-off override
#   party.sh --no-companion "task"    # run without companion

[agents.claude]
cli = "claude"

[agents.codex]
cli = "codex"

[roles]
  [roles.primary]
  agent = "claude"

  [roles.companion]
  agent = "codex"
  window = 0
```

`config init` is idempotent — if the file already exists, print `config already exists at <path>` and exit 0.

### Remove `repoRoot` from agent query

`tools/party-cli/cmd/agent.go` currently takes `repoRoot` and passes it to `LoadConfig`. After this task:

```go
func newAgentCmd() *cobra.Command {  // no repoRoot parameter
    ...
}

// In the query handler:
cfg, err := agent.LoadConfig(nil)  // no cwd, no repoRoot
```

This also fixes the `TestAgentQuery_NoCompanion` CI failure identified in PR #139 review — that test failed because `PARTY_REPO_ROOT` leaked in from the CI env. With user-global config, the test's CWD no longer matters.

### Hook consequences

Hooks that invoke `party-cli agent query` pass no repo-specific arguments — the query resolves user-global config. This means:
- `companion-gate.sh`, `companion-trace.sh`, `companion-guard.sh`, `primary-state.sh` — no changes needed beyond what Task 7 already did (they don't pass repo paths)
- Hook tests that set up `.party.toml` fixtures need to set up user-global config in a test HOME instead:
  ```bash
  export HOME="$TEST_HOME"
  mkdir -p "$HOME/.config/party-cli"
  cat > "$HOME/.config/party-cli/config.toml" <<EOF
  [roles.primary]
  agent = "claude"
  EOF
  ```

### Backward compatibility

**No `.party.toml` fallback.** This is an intentional clean break:
- Users who had `.party.toml` files run `party-cli config init` once (or accept defaults)
- The file count in user repos drops from potentially-many to zero
- Simpler code — no dual resolution paths

If grep finds any `.party.toml` references in user projects, they can `cp .party.toml ~/.config/party-cli/config.toml` as a manual one-time migration.

## Tests

### config package
- `LoadConfig` with no user-global file → returns default config
- `LoadConfig` with user-global file → parses and merges with defaults
- `LoadConfig` with `XDG_CONFIG_HOME` set → uses XDG path
- `LoadConfig` with overrides → overrides take precedence
- `UserConfigPath` returns the expected path format

### config subcommand
- `config init` creates file if missing; exits 0 if file exists
- `config show` prints resolved config
- `config path` prints absolute path
- `config set-primary codex` modifies file; subsequent `show` reflects change
- `config set-companion claude` modifies file
- `config unset-companion` removes companion section
- Atomic write — interrupted writes don't corrupt the file

### Regression
- `TestAgentQuery_NoCompanion` (previously fixed via `t.Setenv` workaround) — now passes cleanly because CWD/repoRoot no longer matters
- All existing tests that set up `.party.toml` fixtures → updated to use user-global or overrides

## Acceptance Criteria

- [ ] `.party.toml` support removed from `internal/agent/config.go`
- [ ] `LoadConfig` no longer takes `cwd` parameter
- [ ] `UserConfigPath()` respects `XDG_CONFIG_HOME` and falls back to `~/.config/party-cli/config.toml`
- [ ] `party-cli config` subcommand with init/show/path/set-primary/set-companion/unset-companion
- [ ] `party-cli agent query` no longer depends on CWD or `PARTY_REPO_ROOT`
- [ ] Hook tests updated to use user-global config in test HOME (not repo-local)
- [ ] README.md and CLAUDE.md updated — no references to `.party.toml`
- [ ] `TestAgentQuery_NoCompanion` passes without `t.Setenv` workaround
- [ ] All existing tests pass
- [ ] No `.party.toml` references remain in codebase (`grep -r "party\.toml"` returns only historical docs)
