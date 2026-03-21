# Party Sidebar TUI V2 Implementation Plan

> **Goal:** Replace the visible Codex pane in standard and worker sessions with a narrow sidebar while keeping Codex reachable through a hidden companion tmux session and leaving master sessions untouched.
>
> **Architecture:** `session/party.sh` launches a visible sidebar pane plus a detached `<party-id>-codex` companion session, persists that session name in the parent manifest, and uses session-scoped tmux hooks to preserve the `15/55/30` layout despite global rebalance hooks. `party-lib.sh` resolves Codex through the companion with liveness and recursion guards. `tmux-codex.sh` writes a runtime status file on dispatch/completion so the sidebar reads structured state instead of scraping Codex CLI output. `tools/party-tracker/` gains a sidebar mode that reads the status file, renders offline-safe status, and opens a snapshot-based popup for inspection. Promotion from sidebar to master tears down the companion and replaces the sidebar pane with the tracker.
>
> **Tech Stack:** Bash, tmux 3.6a, jq-backed manifest helpers, Go 1.25.7, Bubble Tea, Bubbles, Lip Gloss
>
> **Specification:** [SPEC-sidebar-tui-v2.md](./SPEC-sidebar-tui-v2.md) | **Design:** [DESIGN-sidebar-tui-v2.md](./DESIGN-sidebar-tui-v2.md)

## Scope

This plan covers standard and worker party sessions only. It includes launch-time layout changes, companion-session lifecycle management, companion-aware routing, hidden-session filtering in discovery/picker/list flows, sidebar-mode work in `party-tracker`, and regression coverage. Master-session launch and interaction patterns remain unchanged.

## Task Granularity

- [x] **Standard** — tasks target a coherent slice of behavior and stay small enough to merge independently
- [ ] **Atomic** — not needed; this work spans tmux session plumbing, tracker UI, and tests rather than 2-5 minute micro-steps

## Tasks

- [ ] [Task 1](./tasks/TASK1-sidebar-layout-and-companion-lifecycle.md) — Launch sidebar sessions with a detached Codex companion, persist `codex_session`, make teardown paths companion-aware, and handle sidebar→master promotion (deps: none)
- [ ] [Task 2](./tasks/TASK2-session-discovery-and-codex-routing.md) — Extend pane routing, stale-companion self-healing, visible-session filtering, and add runtime status file writes to `tmux-codex.sh` (deps: Task 1)
- [ ] [Task 3](./tasks/TASK3-sidebar-mode-and-session-info.md) — Add `party-tracker --sidebar <session-id>` and render the session-info half of the sidebar without regressing master tracker mode (deps: Task 1)
- [ ] [Task 4](./tasks/TASK4-codex-status-and-offline-state.md) — Read the runtime status file to derive Codex state, target, elapsed time, and last verdict with offline-safe rendering (deps: Task 2, Task 3)
- [ ] [Task 5](./tasks/TASK5-codex-peek-popup.md) — Add snapshot-based Codex peek popup with periodic refresh and sidebar flash-message handling for unavailable companions (deps: Task 3, Task 4)
- [ ] [Task 6](./tasks/TASK6-regression-tests-and-verification.md) — Add shell and Go regression coverage for launch, cleanup, routing, promotion, hidden-session filtering, status file, and sidebar parsing behavior (deps: Task 1, Task 2, Task 3, Task 4, Task 5)

UI-bearing tasks include `Design References` sections that point at [plans/sidebar-tui-v2-layout.svg](./plans/sidebar-tui-v2-layout.svg).

## Coverage Matrix

| New Field/Endpoint | Added In | Code Paths Affected | Handled By | Converter Functions |
|--------------------|----------|---------------------|------------|---------------------|
| `PARTY_LAYOUT=sidebar|classic` | Task 1 | `party_start()`, `party_continue()`, `party_launch_agents()`, session-scoped layout hooks | Task 1, Task 6 | N/A (env-driven launch branch) |
| `codex_session` manifest field | Task 1 | launch, resume, session-closed hook, `party_stop()`, `party_delete()`, `party_promote()`, `party_role_pane_target*()`, sidebar polling, popup peek | Task 1, Task 2, Task 4, Task 5, Task 6 | `party_state_set_field()`, `party_state_get_field()`, `readManifest()` |
| Sidebar→master promotion | Task 1 | `party_promote()` must replace sidebar with tracker, kill companion, clear `codex_session` | Task 1, Task 6 | Reuses existing `party_promote()` flow |
| Hidden-companion session filtering | Task 2 | `discover_session()`, picker/list output, bulk stop enumeration, scan-based UX | Task 2, Task 6 | `party_visible_sessions()` (new helper) |
| Runtime status file (`codex-status.json`) | Task 2 | `tmux-codex.sh` writes on dispatch/completion, sidebar reads on poll | Task 2, Task 4, Task 6 | JSON file in `/tmp/<session>/codex-status.json` |
| `--sidebar` tracker CLI mode | Task 3 | tracker entrypoint, launch command assembly, mode-specific rendering and key handling | Task 3, Task 5, Task 6 | CLI parse -> sidebar model initialization |
| `codexStatus` sidebar model | Task 4 | status file reading, offline fallback, status rendering, flash/peek gating | Task 4, Task 5, Task 6 | `readCodexStatus()`, verdict/target parsers (new) |

**Validation:** Every persisted or user-visible addition is traced from creation through routing/UI/test coverage. The highest-risk field is `codex_session`; it is intentionally covered by every downstream task.

## Dependency Graph

```text
Task 1 ───> Task 2 ───────────────┐
   │                               │
   └───> Task 3 ───> Task 4 ───> Task 5
                                    │
Task 2 ─────────────────────────────┤
Task 3 ─────────────────────────────┤
Task 4 ─────────────────────────────┤
Task 5 ─────────────────────────────┘
                     └──────> Task 6
```

## Task Handoff State

| After Task | State |
|------------|-------|
| Task 1 | Sidebar sessions launch with a detached companion, maintain `15/55/30`, kill companions during direct teardown paths, and promotion from sidebar→master works correctly |
| Task 2 | Hidden companions no longer leak into discovery/picker/list flows; Codex routing resolves companion sessions safely and self-heals stale metadata; `tmux-codex.sh` writes runtime status file on dispatch/completion |
| Task 3 | `party-tracker` can run in sidebar mode and render session context while master tracker mode still behaves as before |
| Task 4 | Sidebar shows Codex state from runtime status file with offline fallback; no stale verdict leakage |
| Task 5 | Sidebar users can inspect Codex through a snapshot-based popup with periodic refresh; guarded feedback when unavailable |
| Task 6 | Regression coverage exercises shell lifecycle, routing semantics, classic/master compatibility, and Go-level parser/render helpers |

## External Dependencies

| Dependency | Status | Blocking |
|------------|--------|----------|
| tmux 3.6a hook scoping and popup support | Verified locally via `tmux -V` and an isolated hook-override experiment | Task 1 |
| jq-backed manifest helpers | Already assumed by manifest persistence code | Task 1, Task 2, Task 4 |
| Existing Bubble Tea tracker module | Present in `tools/party-tracker/go.mod` | Task 3, Task 4, Task 5 |

## Plan Evaluation Record

PLAN_EVALUATION_VERDICT: PASS

Evidence:
- [x] Existing standards referenced with concrete paths
- [x] Data transformation points mapped
- [x] Tasks have explicit scope boundaries
- [x] Dependencies and verification commands listed per task
- [x] Requirements reconciled against source inputs
- [x] Whole-architecture coherence evaluated
- [x] UI/component tasks include design references

Source reconciliation:
- The requested transport behavior flows through `party_role_pane_target_with_fallback()` already used by `_require_session()` in `claude/skills/codex-transport/scripts/tmux-codex.sh:30-40`, so routing edits are in party-lib.sh. However, `tmux-codex.sh` gains status file writes (Task 2) so the sidebar can read structured state instead of scraping Codex CLI output.
- Hidden companions require more than bulk-stop filtering. `discover_session()` (`session/party-lib.sh:295-332`), picker/list flows (`session/party-picker.sh:21-126`, `session/party.sh:396-438`), and scan-based UX also need explicit `-codex` exclusion.
- The plan does not edit `tmux/tmux.conf` despite the global `even-horizontal` hooks at `tmux/tmux.conf:31-34`. tmux 3.6a allows session-scoped hook overrides, and a local isolated test returned `@hook_result session` when both global and session `after-split-window` hooks were present.
- `party_promote()` (`session/party-master.sh:86-139`) resolves the codex pane via `party_role_pane_target()` — with companion routing, this would find the companion pane and respawn the tracker there (invisible). Task 1 handles promotion explicitly: replace the visible sidebar pane, tear down the companion, clear `codex_session`.
- `tmux attach-session -r` inside `display-popup` does NOT work as an embedded viewer — it switches the whole client. Task 5 uses a snapshot approach with periodic refresh instead.

## Definition of Done

- [ ] All task checkboxes complete
- [ ] Companion sessions are hidden from user-facing party discovery and fully cleaned up
- [ ] `PARTY_LAYOUT=classic` preserves current standard/worker behavior
- [ ] Master sessions remain unchanged
- [ ] Sidebar→master promotion correctly replaces sidebar with tracker and tears down companion
- [ ] Sidebar launch, routing, offline handling, and popup peek verification commands pass
- [ ] SPEC acceptance criteria are satisfied
