# Execution Core

Shared rules for all workflow skills. Bugfix-workflow omits checkboxes (no PLAN.md).

## Core Sequence

```
/write-tests → implement → checkboxes → self-review → [code-critic + minimizer] → codex → /pre-pr-verification → commit → PR
```

## Self-Review

Before critics, verify: (1) acceptance criteria met, (2) tests cover criteria, (3) no debug artifacts, (4) `git diff` matches intent, (5) no obvious bugs. Fix failures before proceeding.

## Marker System

`marker-invalidate.sh` deletes all review markers on Edit|Write of implementation files (skips `.md`, `/tmp/`, `.log`, `.jsonl`). Editing code after approval invalidates it — re-run the cascade. Markers are hook-created evidence; never create manually.

`codex-gate.sh` blocks `--review` without critic APPROVE markers, blocks `--approve` without codex-ran marker. If critics returned REQUEST_CHANGES, you MUST re-run them after fixing — the gate enforces this.

## Review Governance

Classify every finding before acting:

| Severity | Definition | Action |
|----------|-----------|--------|
| **Blocking** | Correctness bug, crash, security HIGH/CRITICAL | Fix + re-run |
| **Non-blocking** | Style, "could be simpler", defensive edge cases | Note only, do NOT re-run |
| **Out-of-scope** | Pre-existing untouched code, requirements not in TASK | Reject |

**Issue ledger:** Track findings across iterations. Closed findings cannot be re-raised without new evidence. Critic reversing own feedback = oscillation — use own judgment, proceed.

**Caps:** Blocking: max 3 critic + 3 codex iterations → NEEDS_DISCUSSION. Non-blocking: max 1 round → accept or drop.

**Tiered re-review:** One-symbol swap → test-runner only. Logic change → test-runner + critics. New export/signature/security path → full cascade.

**Scope enforcement:** Every sub-agent prompt MUST include TASK file scope boundaries. Critics review the diff, not the codebase. Pre-existing code is non-blocking unless newly reachable.

## Decision Matrix

| Step | Outcome | Next | Pause? |
|------|---------|------|--------|
| /write-tests | Written (RED) | Implement | NO |
| Implement | Done | Checkboxes | NO |
| Self-review | PASS/FAIL | Critics / fix | NO |
| code-critic or minimizer | APPROVE | Wait for other / codex | NO |
| code-critic or minimizer | REQUEST_CHANGES (blocking) | Fix + re-run both | NO |
| code-critic or minimizer | REQUEST_CHANGES (non-blocking) | Note, continue | NO |
| code-critic or minimizer | NEEDS_DISCUSSION / oscillation / cap | Ask user | YES |
| Both critics done, no blocking | — | Run codex | NO |
| codex | APPROVE | /pre-pr-verification | NO |
| codex | REQUEST_CHANGES (blocking) | Fix → tiered re-review → re-run codex | NO |
| codex | NEEDS_DISCUSSION | Ask user | YES |
| /pre-pr-verification | Pass/Fail | PR / fix | NO |
| security-scanner | HIGH/CRITICAL | Ask user | YES |
| Edit/Write (impl) | Markers invalidated | Re-run cascade | NO |

## Valid Pause Conditions

Investigation findings, NEEDS_DISCUSSION, 3 strikes, oscillation, iteration cap, explicit blockers.

## Sub-Agent Behavior

Investigation (codex debug): always pause, show full findings. Verification (test/check/security): never pause, summary only. Iterative (critics, codex): pause on NEEDS_DISCUSSION/oscillation/cap.

## Verification Principle

Evidence before claims. No assertions without proof (test output, file:line, grep result). Code edits invalidate prior evidence — rerun. Red flags: "should work", commit without checks, stale evidence.

## PR Gate

Code PRs require all markers: pre-pr-verification, code-critic, minimizer, codex, test-runner, check-runner, security-scanner. Markers created by `agent-trace.sh` and `codex-trace.sh`.

**Post-PR:** Changes in same branch → re-run /pre-pr-verification → amend + force-push with `--force-with-lease`.

## Violation Patterns

| Pattern | Action |
|---------|--------|
| Stop after partial completion | Continue — don't ask "should I continue?" |
| Chase non-blocking nits 2+ rounds | Triage, note, move on |
| Implement every finding without triage | Classify blocking/non-blocking/out-of-scope first |
| Full cascade after one-line fix | Tiered re-review |
| Skip self-review | Run it — critics depend on it |
| Approve without --review-complete | Gate blocks — run review first |
| Edit after approval, then PR | Markers invalidated — re-run |
| Create markers manually | Forbidden — hooks create evidence |
| Call codex without re-running critics | Gate blocks — re-run critics |
