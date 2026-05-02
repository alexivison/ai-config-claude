# Pi as a Third Agent

> **Goal:** `party-cli config set-companion pi` (or `set-primary pi`) launches a working Pi pane that participates in master/worker sessions, accepts relay/broadcast, returns readable output via `read`, and resumes across `continue`.
>
> **Approach:** Add Pi (`@mariozechner/pi-coding-agent`) as a third selectable provider alongside Claude and Codex. Zero regression for existing setups. Hooks, skills, subagents, and evidence governance remain Claude/Codex-only — Pi panes run "naked" with our master/worker prompts in this phase.

This plan is the first milestone of a longer migration that could eventually replace Claude Code and Codex entirely with Pi. See [Background](#background) for the broader research that motivated this scoping.

## Phases

| Phase | Deliverable | Effort | Depends on |
|---|---|---|---|
| 0 | Reconnaissance — verify Pi's actual flag and output behavior | ½ day | — |
| 1 | Pi provider stub in `internal/agent/pi.go` + registry wiring | 1 day | Phase 0 |
| 2 | Output filter strategy for Pi panes (`read` command) | ½–1½ days | Phase 0 |
| 3 | Resume-ID plumbing | ½ day | Phase 0 |
| 4 | Tests and integration wiring | 1 day | Phases 1–3 |
| 5 | Manual end-to-end validation | ½ day | Phase 4 |
| 6 | Docs and migration notes | ½ day | Phase 5 |

**Total budget:** ~5 working days.

## Phase 0 — Reconnaissance

The earlier research was ~85% derived from Pi's docs. Five facts must be verified on a real Pi binary before code is written; each one determines a branch in Phases 1–3.

| # | Question | How to answer | Decision it unblocks |
|---|---|---|---|
| 0.1 | Do `--append-system-prompt`, `--no-session`, `--session <id>`, `--mode json`, `--mode rpc` exist on the installed binary? | `pi --help`, `pi --version` | Whether the BuildCmd shape works at all |
| 0.2 | What does a Pi session ID look like? Path, UUID, short token? | `pi -p "hi"; ls -la ~/.pi/agent/sessions/`; inspect `--mode json` output for any session-ID emission | Whether `validResumeID` regex needs relaxing |
| 0.3 | Does `--session <id> --append-system-prompt "..."` re-apply the prompt cleanly on resume? | Launch with prompt, kill, resume same flags, observe behavior | Whether `continue.go` can pass `MasterPrompt()` every time or must persist it |
| 0.4 | What does `pi --mode json -p "list files"` actually emit? | Capture stdout to a file; inspect JSONL events | Whether `read.go` can pivot to JSON ingestion or must keep capture-pane |
| 0.5 | What does an interactive Pi pane look like under `tmux capture-pane`? Glyph prefixes? Differential render artifacts? | Run Pi in tmux, `tmux capture-pane -p -S -200` after each tool call | Whether we need a `FilterPiLines` at all |

**Deliverable:** `docs/projects/pi-third-agent/RECON.md` answering all five with output snippets.

## Phase 1 — Provider Stub

**Files to create**

- `tools/party-cli/internal/agent/pi.go` — implements all 13 methods of `agent.Agent`

**Files to edit**

- `tools/party-cli/internal/agent/registry.go` — register `"pi"` in `providerConstructors`
- `tools/party-cli/internal/agent/config.go` — add `pi` to `DefaultConfig().Agents` (do **not** change default `Roles`; Claude+Codex stay default)
- `tools/party-cli/cmd/prune.go` — add `~/.pi/agent/sessions`, `~/.pi/agent/git` to artifact path list

**Pi provider methods (proposed)**

| Method | Value |
|---|---|
| `Name()` | `"pi"` |
| `DisplayName()` | `"Pi"` |
| `Binary()` | `cfg.CLI` or `"pi"` |
| `ResumeKey()` | `"pi_session_id"` |
| `ResumeFileName()` | `"pi-session-id"` |
| `EnvVar()` | `"PI_SESSION_ID"` |
| `BinaryEnvVar()` | `"PI_BIN"` |
| `FallbackPath()` | `"~/.local/share/npm/bin/pi"` (npm global default) |
| `MasterPrompt()` | Claude's verbatim, s/Claude/Pi/ |
| `WorkerPrompt()` | Claude's verbatim |
| `FilterPaneLines()` | TBD by Phase 2 — placeholder: `tmux.FilterAgentLines` |
| `PreLaunchSetup()` | No-op (no Pi env-var conflicts to clear) |
| `BuildCmd(opts)` | See below |

**`BuildCmd` proposed shape**

```
export PATH=<agentPath>; exec pi
  [--append-system-prompt <MasterPrompt or WorkerPrompt+SystemBrief>]
  [--session <ResumeID>]
  [<initial-prompt-positional-or-via-stdin>]
```

**Open in Phase 1, decided by Phase 0 recon**

- Whether to also pass `--thinking high` for master sessions (analog to Claude's `--effort high`)
- Whether the initial prompt is positional (`pi "<prompt>"`) or only deliverable post-launch via `tmux send-keys`
- Whether `--no-session` is needed in any path

## Phase 2 — Output Filter Strategy

The `party-cli read` command currently dispatches on agent name to either `tmux.FilterCodexLines` or `tmux.FilterAgentLines`. Pi has no glyph prefixes (component-based rendering), so this needs a new strategy. Decision tree based on Phase 0 outcomes:

- **0.5 reveals usable glyph-like markers** → write `FilterPiLines` in `internal/tmux/capture.go` mirroring `FilterAgentLines`, add `case "pi":` to `message.filterPrimaryPaneLines`. ~½ day.
- **0.5 shows no stable markers BUT 0.4 confirms `--mode json` works cleanly** → sidecar JSON file approach:
  - In `BuildCmd`, redirect stderr/stdout JSONL to `/tmp/<sessionID>/pi-events.jsonl`
  - In `read.go`, branch on agent name to read last N events from sidecar and pretty-print
  - Cleaner long-term but ~1.5 days of plumbing
- **Worst case (no markers, no usable JSON mode)** → `read` returns raw last-N-lines for Pi panes with a `[raw output — Pi has no structured pane format]` header. ~½ day. Acceptable for "third agent" milestone; document the limitation.

**Recommendation pending recon:** outcome 2 (sidecar JSON) is cleanest but commit only after seeing real events.

## Phase 3 — Resume-ID Plumbing

Decision tree based on Phase 0 outcome 0.2:

- **Short tokens matching `[A-Za-z0-9_-]+`** → zero changes
- **Path-style IDs** → relax `validResumeID` regex in `internal/state/manifest.go:19` to `^[A-Za-z0-9_./-]+$`. Add a unit test for path-traversal rejection (resume IDs are shell-quoted by `config.ShellQuote` already, so the surface is shallow but worth covering)
- **IDs needing indirection** → add a `pi-session-map.json` under `~/.party-state/` mapping ULIDs → Pi session paths. Pi provider's `BuildCmd` looks up the path; manifest stores the ULID. ~1 day extra. Avoid if possible.

## Phase 4 — Tests and Wiring

**Tests to add**

- `internal/agent/pi_test.go` — `BuildCmd` snapshot tests (master, worker, with/without resume, with/without prompt)
- `internal/agent/registry_test.go` — registry recognizes `"pi"`, primary↔companion swap works
- `internal/state/manifest_test.go` — if regex relaxed, add path-traversal rejection test
- `cmd/prune_test.go` — Pi artifact paths walk correctly

**No new tests for tmux/message layer** unless Phase 2 takes the JSON-sidecar route, in which case add an integration test with a fake sidecar file.

## Phase 5 — Manual Validation

Concrete checklist on a real machine:

1. `party-cli config set-companion pi`, `party-cli config show` displays Pi as companion
2. `./session/party.sh "test"` launches a session with Claude primary + Pi companion + shell, all panes alive
3. From primary: `~/.claude/skills/agent-transport/scripts/tmux-companion.sh --prompt "say hello" $(pwd)` delivers a message to the Pi pane
4. Pi receives, processes, replies. (Companion-side `tmux-primary.sh` may need a path tweak — flagged for the full migration, not blocking here)
5. `party-cli read <session>` returns something readable from the Pi pane (filter quality TBD by Phase 2)
6. `party-cli stop` then `party-cli continue <id>` resumes the Pi session with the right resume ID
7. Swap roles: `set-primary pi`, `set-companion claude`, repeat — confirms both directions work
8. `party-cli prune --artifacts --dry-run` lists Pi paths

Anything that fails here goes back to its Phase as a follow-up task.

## Phase 6 — Docs

- Update `README.md` "The Party" table to mention Pi as a third available agent
- Update `README.md` "CLI Installation Methods" with Pi's install command
- Add `docs/pi-companion.md` describing what works and what doesn't (no hooks, no evidence, no governance — explicit "use at own risk for Pi panes")
- Update `claude/CLAUDE.md` and `codex/AGENTS.md` to mention Pi as a third option in the Party table

## Definition of Done

- [ ] `pi install` (npm or homebrew) → `party-cli config set-companion pi` → `./session/party.sh "task"` launches a working 3-pane party with Claude primary + Pi companion + shell
- [ ] Primary can dispatch to Pi via `agent-transport`; Pi can reply via the companion-side transport
- [ ] `party-cli read`, `relay`, `broadcast`, `report`, `workers`, `continue`, `stop`, `delete` all function for Pi panes
- [ ] Role swap works in both directions (Pi-as-primary, Pi-as-companion)
- [ ] No regression for Claude+Codex setups (existing tests + manual smoke pass)
- [ ] `go test ./...` passes
- [ ] `docs/projects/pi-third-agent/RECON.md` exists with verified Phase 0 answers
- [ ] README and CLAUDE.md/AGENTS.md updated to mention Pi as a third option

**Explicitly out of scope for this phase:** hooks, skills, subagents, evidence system, pr-gate. Pi panes have no governance until the full migration (separate project).

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Phase 0 reveals a missing flag | Low | Halt; reassess port architecture before any Go work |
| Pi session resume doesn't re-inject the system prompt cleanly | Medium | Persist the prompt to `.pi/SYSTEM.md` per-session as a fallback; document the behavior |
| Pi pane output is genuinely unreadable via `capture-pane` | Medium | Phase 2 outcome 2 (JSON sidecar) handles this cleanly |
| `pi-tui` differential rendering breaks `tmux send-keys -l` paste timing | Low | Already have a 15ms `sendEnterDelay`; bump to 30ms for Pi if needed |
| Pi's npm-global binary path varies by system | Low | `FallbackPath` + `PI_BIN` env-var override mirror what we do for Claude/Codex |
| Pi 0.x versioning churn (weekly releases, occasional breaking changes) | Medium | Pin a known-good version; budget quarterly upgrade time |

## Background

Pi is a minimalist MIT-licensed TypeScript terminal coding agent (`@mariozechner/pi-coding-agent`, repo `github.com/badlogic/pi-mono`) launched late 2025. Earlier research established:

- Pi has full feature parity with Claude Code's CLI surface (resume, system prompts, autonomous mode, JSON/RPC output modes)
- Pi reads `CLAUDE.md` and `AGENTS.md` natively as context files (zero rewrite for our rules)
- Pi has a hook system (~25 lifecycle events) that is functionally equivalent to Claude Code's hooks
- Pi has no native subagents but the `pi-subagents` extension provides full parity
- Pi has no native MCP but `pi-mcp-adapter` provides token-efficient integration
- Pi-tui uses component-based rendering with no stable glyph prefixes — RPC/JSON mode is preferred over `capture-pane` for programmatic output ingestion

Full feasibility analysis lives in this PR's description and the upstream research thread.

This plan deliberately scopes only the "third agent" milestone. Full replacement of Claude Code + Codex by Pi is a separate, larger project (estimated ~5–6 weeks) that would port hooks, subagents, skills, evidence, and governance. We do that after this milestone proves the foundation works.
