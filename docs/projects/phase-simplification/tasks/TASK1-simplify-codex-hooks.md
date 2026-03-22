# Task 1 — Simplify Codex Hooks

**Dependencies:** none | **Issue:** N/A (phase-simplification)

---

## Goal

Remove the phase-specific Codex hook behavior so Codex entry and completion hooks only do what still matters in the simplified model: block self-approval, record Codex approval evidence, and leave review sequencing to workflow skills.

## Scope Boundary (REQUIRED)

**In scope:**
- `claude/hooks/codex-gate.sh` review-path simplification
- `claude/hooks/codex-trace.sh` retirement of `codex-ran`
- `claude/hooks/tests/test-codex-gate.sh` rewrite for non-gating `--review`
- `claude/hooks/tests/test-codex-trace.sh` rewrite for direct `codex` evidence creation
- Hook header comments that currently describe phases

**Out of scope (handled by other tasks):**
- `claude/hooks/pr-gate.sh` full-tier enforcement changes
- Cross-hash critic oscillation detection
- Rule-doc updates in `claude/rules/execution-core.md`

**Cross-task consistency check:**
- Task 2 must stop treating `codex-ran` as meaningful evidence once this task removes it.
- Task 4 must rewrite the rule doc after this behavior lands; otherwise `execution-core.md` will still promise a first-review gate that no longer exists.

## Reference

Files to study before implementing:

- `claude/hooks/codex-gate.sh:33-46` — the `--approve` block to keep intact
- `claude/hooks/codex-gate.sh:49-99` — the phase-1 and phase-2 review logic to delete
- `claude/hooks/codex-trace.sh:61-80` — current `codex-ran` creation and approval gating
- `claude/hooks/lib/evidence.sh:185-205` — shared evidence append contract that remains unchanged
- `claude/hooks/tests/test-codex-gate.sh:67-199` — phase-heavy tests to rewrite
- `claude/hooks/tests/test-codex-trace.sh:92-211` — `codex-ran` assertions to remove or replace

## Design References (REQUIRED for UI/component tasks)

N/A (non-UI task)

## Data Transformation Checklist (REQUIRED for shape changes)

This task changes internal evidence semantics, not external APIs.

- [ ] `CODEX APPROVED` creates `codex` evidence directly, without any `codex-ran` prerequisite
- [ ] `tmux-codex.sh --review` becomes a pass-through in the gate hook, regardless of critic evidence state
- [ ] `tmux-codex.sh --approve` remains denied exactly as before
- [ ] Object and string `tool_response` formats continue to work in `codex-trace.sh`
- [ ] Stale-evidence behavior remains enforced by the PR gate, not reintroduced here

## Files to Create/Modify

| File | Action |
|------|--------|
| `claude/hooks/codex-gate.sh` | Modify |
| `claude/hooks/codex-trace.sh` | Modify |
| `claude/hooks/tests/test-codex-gate.sh` | Modify |
| `claude/hooks/tests/test-codex-trace.sh` | Modify |

## Requirements

**Functionality:**
- Keep the `tmux-codex.sh --approve` hard block in `claude/hooks/codex-gate.sh`.
- Remove all critic-evidence checks from `tmux-codex.sh --review`; the hook should allow review, prompt, plan-review, and review-complete flows through.
- Stop writing `codex-ran` evidence in `claude/hooks/codex-trace.sh`.
- Allow `CODEX APPROVED` to write `codex` evidence directly after successful `--review-complete`.
- Update script comments so they describe the single-phase model rather than phase 1/2 behavior.

**Key gotchas:**
- `codex-trace.sh` must still ignore failed Bash commands and non-`tmux-codex.sh` invocations.
- Combined stdout such as `CODEX_REVIEW_RAN` plus `CODEX APPROVED` must still result in `codex` evidence.
- `TRIAGE_OVERRIDE` handling in `codex-trace.sh` is retained and must not regress while the middle section is simplified.

## Tests

Test cases:
- `--review` with no evidence is allowed
- `--review` with critic evidence is also allowed
- `--approve` is denied with or without prior evidence
- `--prompt` and `--plan-review` still pass through
- `--review-complete` with `CODEX APPROVED` creates `codex` evidence
- `--review-complete` with `CODEX REQUEST_CHANGES` creates no `codex` evidence
- Failed Bash execution and invalid JSON still fail open

Verification commands:
- `bash claude/hooks/tests/test-codex-gate.sh`
- `bash claude/hooks/tests/test-codex-trace.sh`

## Acceptance Criteria

- [ ] `claude/hooks/codex-gate.sh` contains only the `--approve` deny path plus general allow paths
- [ ] No `codex-ran` evidence is written or required anywhere in Codex hook tests
- [ ] `claude/hooks/tests/test-codex-gate.sh` explicitly covers "`--review` without evidence is allowed"
- [ ] `claude/hooks/tests/test-codex-trace.sh` proves `codex` evidence is recorded directly from `CODEX APPROVED`
- [ ] All Task 1 verification commands pass
