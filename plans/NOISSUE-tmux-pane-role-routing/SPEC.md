# Role-Based tmux Party Routing Specification

## Problem Statement

- Pane routing is currently index-bound (`0.0` for Claude, `0.1` for Codex), so layout changes can silently misroute messages.
- The launcher and theme assume a fixed two-pane layout with Claude on the left and Codex on the right.
- Desired operator layout is now: pane 0 = Codex, pane 1 = Claude, pane 2 = normal interactive shell pane.

## Goal

Make agent routing role-based rather than pane-order-based, while adopting the new default pane order (`Codex`, `Claude`, `Shell`).

## Feature Flag

No feature flag. This is a foundational tmux orchestration behavior change.

## User Experience

| Scenario | User Action | Expected Result |
|----------|-------------|-----------------|
| Happy path launch | Run `./session/party.sh` | Party starts with Codex in pane `0`, Claude in pane `1`, and a normal shell in pane `2` |
| Claude sends to Codex | Run `~/.claude/skills/codex-transport/scripts/tmux-codex.sh --prompt "..." <workdir>` | Message is delivered to Codex even if pane indices are changed manually |
| Codex sends to Claude | Run `~/.codex/skills/claude-transport/scripts/tmux-claude.sh "..."` | Message is delivered to Claude based on role lookup, not `0.0` |
| Missing role metadata (legacy 2-pane) | Remove pane role metadata in a 2-pane session, then send | Script falls back to legacy pane targets (`claude=>0.0`, `codex=>0.1`) |
| Missing role metadata (new 3-pane) | Remove pane role metadata in a 3-pane session, then send | Script exits with explicit `ROUTING_UNRESOLVED` error — fallback does not activate for non-legacy topology |
| Duplicate role metadata | Manually set same `@party_role` on two panes, then send | Script exits with explicit `ROLE_AMBIGUOUS` error |

## Acceptance Criteria

- [ ] `party.sh` creates the default 3-pane layout with roles: `codex` (pane `0`), `claude` (pane `1`), `shell` (pane `2`).
- [ ] `tmux-claude.sh` no longer hardcodes `CLAUDE_PANE="$SESSION_NAME:0.0"`; it resolves the Claude pane by role first.
- [ ] `tmux-codex.sh` no longer hardcodes `CODEX_PANE="$SESSION_NAME:0.1"`; it resolves the Codex pane by role first.
- [ ] `configure_party_theme` labels panes by role metadata, not by `pane_index == 0` assumptions.
- [ ] Automated tests cover role-based pane lookup, legacy fallback behavior, topology guard, and duplicate-role detection.
- [ ] Non-session modes in `tmux-codex.sh` (`--approve`, `--review-complete`, `--re-review`, `--needs-discussion`) remain session-independent — no role resolution on these paths.
- [ ] `bash tests/run-tests.sh` passes.

## Non-Goals

- Supporting cross-window or cross-session routing (routing remains scoped to the discovered party session).
- Changing codex/claude hook gating semantics (approval gates remain as-is).
- Redesigning the entire tmux UI beyond the requested role/order change.

## Assumption

“Pane 2: Normal window” is interpreted as a third normal shell pane in the same tmux window (`session:0.2`).

## Technical Reference

For implementation details, see [DESIGN.md](./DESIGN.md).
