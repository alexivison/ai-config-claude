# Role-Based tmux Party Routing Implementation Plan

> **Goal:** Remove pane-index coupling from Codex/Claude tmux routing while adopting default pane order `0=codex`, `1=claude`, `2=shell`.
>
> **Architecture:** Store role metadata on panes (`@party_role`) at launch, resolve transport targets by role via shared helpers, and preserve legacy fallback for old sessions. Keep session discovery and `tmux_send` semantics unchanged.
>
> **Tech Stack:** Bash, tmux, jq (unchanged optional), existing shell test harness.
>
> **Specification:** [SPEC.md](./SPEC.md) | **Design:** [DESIGN.md](./DESIGN.md)

## Scope

This plan covers launcher, shared routing helpers, transport scripts, tests, and README updates in this repository only.

## Task Granularity

- [x] **Standard** — ~200 lines of implementation (tests excluded), split if >5 files (default)
- [ ] **Atomic** — 2-5 minute steps with checkpoints (for high-risk: auth, payments, migrations)

## Tasks

- [ ] [Task 1](./tasks/TASK1-role-resolution-primitives.md) — Add role-to-pane resolver helpers and legacy fallback in `party-lib.sh` (deps: none)
- [ ] [Task 2](./tasks/TASK2-party-layout-and-theme.md) — Change launcher to 3-pane default order and role-aware pane labeling (deps: Task 1)
- [ ] [Task 3](./tasks/TASK3-transport-routing-and-tests.md) — Migrate transport scripts to role routing and add regression tests (deps: Task 1, Task 2)
- [ ] [Task 4](./tasks/TASK4-docs-and-verification.md) — Update documentation and run full verification (deps: Task 3)

## Coverage Matrix (REQUIRED for new fields/endpoints)

| New Field/Endpoint | Added In | Code Paths Affected | Handled By | Converter Functions |
|--------------------|----------|---------------------|------------|---------------------|
| `@party_role=codex` | Task 2 | Claude→Codex routing, pane labels | Task 3 (routing), Task 2 (labels) | `party_role_pane_target*` |
| `@party_role=claude` | Task 2 | Codex→Claude routing, pane labels | Task 3 (routing), Task 2 (labels) | `party_role_pane_target*` |
| `@party_role=shell` | Task 2 | Visual labeling, operator shell pane | Task 2 | `configure_party_theme` role mapping |
| Legacy fallback (`claude=>0.0`, `codex=>0.1`) | Task 1 | Existing 2-pane sessions started pre-change | Task 3 validation | `party_role_pane_target_with_fallback` (topology-guarded) |
| Topology guard (2-pane check) | Task 1 | Fallback activation path | Task 1 + Task 3 tests | `party_role_pane_target_with_fallback` |
| Duplicate-role detection | Task 1 | Any session with tag drift | Task 1 + Task 3 tests | `party_role_pane_target` |

**Validation:** Each role mapping is produced once (launcher) and consumed by both transport directions. Fallback only activates for proven legacy topology (exactly 2 panes, no role metadata).

## Dependency Graph

```text
Task 1 ───> Task 2 ───> Task 3 ───> Task 4
```

## Task Handoff State

| After Task | State |
|------------|-------|
| Task 1 | Shared resolver APIs exist with topology guard and duplicate-role detection; no behavior change yet |
| Task 2 | New party sessions launch with target 3-pane role layout |
| Task 3 | Script routing is role-based with test coverage for fallback/regressions |
| Task 4 | Docs match behavior; full test suite passes |

## External Dependencies

| Dependency | Status | Blocking |
|------------|--------|----------|
| tmux installed locally | Existing requirement | Task 2, Task 3, Task 4 manual validation |
| jq (optional manifest persistence) | Existing optional | Not blocking for routing work |

## Plan Evaluation Record

PLAN_EVALUATION_VERDICT: PASS

Evidence:
- [x] Existing standards referenced with concrete paths
- [x] Data transformation points mapped
- [x] Tasks have explicit scope boundaries
- [x] Dependencies and verification commands listed per task
- [x] Requirements reconciled against source inputs
- [x] Whole-architecture coherence evaluated

Source reconciliation:
- User intent: “Pane 0: Codex, Pane 1: Claude, Pane 2: Normal window” + “make routings non-reliant on pane ordering”.
- Current constraints validated at: `session/party.sh:126`, `session/party.sh:129`, `codex/skills/claude-transport/scripts/tmux-claude.sh:19`, `claude/skills/codex-transport/scripts/tmux-codex.sh:15`.
- Assumption explicitly documented in SPEC: “Pane 2” interpreted as third pane in same tmux window.

## Definition of Done

- [ ] All task checkboxes complete
- [ ] All verification commands pass
- [ ] SPEC.md acceptance criteria satisfied
