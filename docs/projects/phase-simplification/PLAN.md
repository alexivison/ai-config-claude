# Phase Simplification Implementation Plan

> **Goal:** Replace the two-phase critic-to-Codex hook gate with a single-phase model where workflow skills enforce sequencing, hooks only record evidence, and the PR gate remains the sole current-hash enforcement point.
>
> **Architecture:** `claude/hooks/codex-gate.sh` collapses to a self-approval block for `--approve`, `claude/hooks/codex-trace.sh` stops emitting `codex-ran`, and `claude/hooks/pr-gate.sh` always requires the full evidence set at the current `diff_hash` unless the quick tier or docs-only bypass applies. `claude/hooks/agent-trace-stop.sh` keeps same-hash oscillation handling and adds cross-hash finding fingerprints so repeated critic re-raises auto-triage after three hashes without reviving phase logic.
>
> **Tech Stack:** Bash, jq, Git diff hashing via `claude/hooks/lib/evidence.sh`, shell hook tests, Markdown
>
> **Specification:** External Claude handoff for "Simplify the evidence gate system" | **Design:** Existing hook implementations and tests cited below

## Scope

This plan covers the hook and rule-doc surface that currently implements phase separation: `claude/hooks/codex-gate.sh`, `claude/hooks/codex-trace.sh`, `claude/hooks/pr-gate.sh`, `claude/hooks/agent-trace-stop.sh`, their shell tests, and `claude/rules/execution-core.md`. It explicitly keeps `claude/hooks/lib/evidence.sh` unchanged, preserves docs-only bypass, quick-tier sizing, stale-evidence diagnostics, hook trace logging, and the hard block on `tmux-codex.sh --approve`.

## Task Granularity

- [x] **Standard** — each task owns one coherent behavior slice and its directly coupled tests/docs
- [ ] **Atomic** — not needed; the work is a small hook refactor, not a high-risk migration

## Tasks

- [ ] [Task 1](./tasks/TASK1-simplify-codex-hooks.md) — Remove phase logic from the Codex entry/exit hooks, retire `codex-ran`, and rewrite the Codex hook tests around the single-phase behavior (deps: none)
- [ ] [Task 2](./tasks/TASK2-simplify-pr-gate.md) — Make the PR gate require the full evidence set at the current hash with no phase-2 relaxation while preserving quick tier, docs-only bypass, and stale diagnostics (deps: Task 1)
- [ ] [Task 3](./tasks/TASK3-add-cross-hash-oscillation-detection.md) — Extend critic oscillation handling to detect the same normalized `REQUEST_CHANGES` finding across three or more hashes and auto-triage it (deps: none)
- [ ] [Task 4](./tasks/TASK4-sync-execution-core-and-verify.md) — Rewrite `execution-core.md` for single-phase enforcement and run the integrated hook regression suite against the new contract (deps: Task 1, Task 2, Task 3)

## Coverage Matrix

| New Field/Endpoint | Added In | Code Paths Affected | Handled By | Converter Functions |
|--------------------|----------|---------------------|------------|---------------------|
| Retire `codex-ran` evidence type | Task 1 | `codex-gate.sh`, `codex-trace.sh`, Codex hook tests, PR gate assumptions, rule docs | Task 1, Task 2, Task 4 | N/A (evidence type removal) |
| Single-phase full PR gate at current `diff_hash` | Task 2 | `gh pr create` enforcement, stale-evidence diagnostics, quick-tier fallback | Task 2, Task 4 | `check_all_evidence()` in `claude/hooks/lib/evidence.sh` |
| `finding_fingerprint` derived from minimizer `REQUEST_CHANGES` body (code-critic exempt) | Task 3 | `agent-trace-stop.sh` oscillation tracking across hashes, triage-override insertion, critic regression tests | Task 3, Task 4 | New normalization + hash helper local to `agent-trace-stop.sh` |
| Sequencing owned by workflow skills rather than hook phases | Task 4 | `execution-core.md` sequence, evidence section, decision matrix, violation patterns; skill docs (`codex-transport`, `task-workflow`, `tmux-handler`) | Task 4 | N/A |

**Validation:** Every behavioral change is traced from hook implementation to test coverage and then to the governing rule doc so the final model has one enforcement point instead of dueling phase rules.

## Dependency Graph

```text
Task 1 ───> Task 2 ───┐
                      │
Task 3 ───────────────┼───> Task 4
                      │
Task 1 ───────────────┘
```

## Task Handoff State

| After Task | State |
|------------|-------|
| Task 1 | `codex-gate.sh` only blocks `--approve`; `codex-trace.sh` records `codex` approval directly; Codex hook tests no longer assert phase behavior or `codex-ran` markers |
| Task 2 | `pr-gate.sh` enforces one full-tier rule: all required evidence must exist at the current hash; quick tier and docs-only bypass still behave as before |
| Task 3 | critic runs still record same-hash oscillation, and repeated normalized `REQUEST_CHANGES` findings across three or more hashes auto-create a triage override |
| Task 4 | rule docs, hook comments, and the hook test suite all describe and validate the same single-phase evidence model |

## External Dependencies

| Dependency | Status | Blocking |
|------------|--------|----------|
| `claude/hooks/lib/evidence.sh` current-hash matching and stale diagnostics | Present and intentionally unchanged | Tasks 1, 2, 3 |
| Shell hook test harness under `claude/hooks/tests/` | Present | Tasks 1, 2, 3, 4 |
| Workflow skills enforcing critic-to-Codex sequencing outside hooks | Existing contract; docs must be updated to state it plainly | Task 4 |

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
- `claude/hooks/codex-gate.sh:49-99` is the entire first-review and phase-2 review gate, while `claude/hooks/codex-gate.sh:33-46` is the only hard self-approval block worth keeping.
- `claude/hooks/codex-trace.sh:61-80` and `claude/hooks/pr-gate.sh:71-88` are the only live consumers of `codex-ran`; they must be simplified together or the evidence model becomes internally inconsistent.
- `claude/hooks/lib/evidence.sh:185-205` writes minimal JSONL evidence entries and `claude/hooks/lib/evidence.sh:212-271` enforces current-hash triage overrides, so cross-hash fingerprint tracking belongs in `agent-trace-stop.sh`, not the shared library.
- `claude/hooks/agent-trace-stop.sh:119-148` only detects same-hash alternation today; `claude/hooks/tests/test-agent-trace.sh:215-275` covers that behavior and provides the insertion point for new cross-hash regression cases.
- `claude/rules/execution-core.md:44-50`, `claude/rules/execution-core.md:69-76`, `claude/rules/execution-core.md:81-98`, and `claude/rules/execution-core.md:141-157` still describe phase-specific behavior that will be false once Tasks 1 and 2 land.
- No UI/component work is involved. Every task file marks `Design References` as `N/A (non-UI task)`.

## Definition of Done

- [ ] `codex-gate.sh` no longer blocks `--review`, but still hard-blocks `--approve`
- [ ] `codex-ran` evidence creation and all phase-1/phase-2 logic are removed from hooks and tests
- [ ] `pr-gate.sh` full tier always requires `pr-verified`, `code-critic`, `minimizer`, `codex`, `test-runner`, and `check-runner` at the current hash
- [ ] same-hash oscillation detection still works, and cross-hash finding repetition now auto-triages at three hashes
- [ ] `execution-core.md` states that workflow skills enforce sequencing and the PR gate is the single enforcement point
- [ ] targeted hook suites and the integrated hook test runner pass
- [ ] hook implementation is materially smaller than the current phase model, with the expected net reduction centered in `codex-gate.sh` and `pr-gate.sh`
