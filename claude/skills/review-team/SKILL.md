---
name: review-team
description: >-
  Spawn an adversarial reviewer teammate via Agent Teams to stress-test code changes.
  Runs concurrently with Codex review after critics approve. Focuses on failure modes,
  edge cases, input validation gaps, race conditions, and security surface. Advisory
  only — produces no gating markers. Requires CLAUDE_TEAM_REVIEW=1 environment variable.
user-invocable: false
---

# Review Team — Adversarial Reviewer

Spawns one **Agent Teams** teammate that tries to break the code while Codex performs deep review. Both run concurrently; no code edits until both return (or timeout).

**This skill uses Agent Teams — NOT a regular sub-agent.** The reviewer must appear as a `@teammate` in the session, not as a `code-critic(...)` sub-agent call. Using a regular Agent sub-agent is the wrong mechanism and a process violation.

## Preflight

All checks must pass. If any fail, log the reason and proceed Codex-only (no blocking).

1. `CLAUDE_TEAM_REVIEW=1` environment variable is set
2. Claude Code version supports Agent Teams (`claude --version` >= 1.0.74)
3. Running in main Paladin context (not inside a sub-agent — no `subagent_type` in environment)

Skip silently if preflight fails. Log to evidence-trace.log:
```
timestamp | review-team | SKIP:reason | session_id
```

## When to Invoke

After critics APPROVE (both code-critic and minimizer), immediately after dispatching Codex review. Step 8 in task-workflow.

## Teammate Role — Adversarial Reviewer

The teammate's sole purpose is to try to break the code. Focus areas:

- Failure modes and error paths
- Edge cases the tests don't cover
- Input validation gaps
- Race conditions and state corruption
- "What's the worst that happens if X fails?"
- Security surface (injection, privilege escalation, data leakage)

## How to Spawn

Use the Agent tool with `subagent_type: "teammate"` and a descriptive `name` (e.g., `"adversarial-reviewer"`). This creates an Agent Teams teammate that appears as `@adversarial-reviewer` in the session.

The teammate is short-lived and read-only. Prefer `in-process` display mode (set via `teammateMode` in settings.json or `--teammate-mode in-process` CLI flag). If running in tmux where `auto` defaults to split panes, accept the split pane.

## Spawn Prompt

Include in the teammate prompt:

1. The working tree diff against merge-base (`git diff "$(git merge-base HEAD main)"`) — this captures uncommitted changes since step 8 runs before commit
2. TASK scope boundaries (in-scope and out-of-scope files)
3. Instruction: produce concise findings (max 20 lines) with `file:line` references
4. Instruction: classify each finding as `[must]` (correctness/security) or `[should]` (robustness)
5. Instruction: if no issues found, return `**APPROVE**`

## Concurrency Rule

**BARRIER:** No code edits until BOTH Codex AND adversarial reviewer return (or 5-minute timeout).

The lead (Paladin) should toggle delegate mode during team review to avoid implementing instead of coordinating.

## Timeout

If the reviewer does not complete within 5 minutes, proceed with Codex findings only. Log timeout:
```
timestamp | review-team | TIMEOUT | session_id
```

## Synthesis

After both return, triage the UNION of Codex + reviewer findings using standard severity classification:
- **Blocking:** correctness bug, crash, security HIGH/CRITICAL → fix + re-run
- **Non-blocking:** robustness, style → note only
- **Out-of-scope:** pre-existing issues → reject

Reviewer findings are **advisory** — they create no gating markers and block no gates.

## Auditability

No marker file — Agent Teams lacks per-teammate hooks, and markers must be hook-created per `execution-core.md`. Completion is logged to `evidence-trace.log` via the skill's preflight/completion logging:
```
timestamp | review-team | COMPLETED | session_id
```

## Common Mistakes

1. **Using a regular sub-agent instead of Agent Teams.** Spawning `code-critic(Adversarial reviewer...)` as a standard Agent sub-agent is wrong. The reviewer must be a `teammate` sub-agent that shows up as `@adversarial-reviewer`. If you catch yourself writing `code-critic(...)` for this step, stop — you are using the wrong mechanism.
2. **Skipping this step entirely.** In past sessions the team review check was skipped because it was a sub-step. It is now step 8 in task-workflow. Check `CLAUDE_TEAM_REVIEW` right after dispatching Codex.

## Cleanup

After synthesis, shut down the teammate and clean up the team. Do not leave orphaned team sessions.
