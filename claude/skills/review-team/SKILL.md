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

Spawn an Agent Teams teammate that tries to break the code while Codex reviews it. Both run concurrently; advisory only — no gating markers.

## Preflight

Skip silently (proceed Codex-only) if `CLAUDE_TEAM_REVIEW` is not `1`.

## Spawn

**CRITICAL: Do NOT use the Agent tool.** Agent Teams teammates are NOT sub-agents. The `Agent` tool does not support `subagent_type: "teammate"` — using it silently falls back to a regular sub-agent.

Agent Teams teammates are spawned via **natural language**. Tell Claude to create a teammate directly:

> Spawn an adversarial reviewer teammate to stress-test my code changes. The teammate should review the diff and report findings. Use in-process display mode.

Before spawning, prepare the context the teammate will need:

1. Run `git diff "$(git merge-base HEAD main)"` and save the output
2. Identify in-scope and out-of-scope files from the TASK

Then request the teammate with the full review prompt:

> Create an agent team with one teammate: an adversarial code reviewer.
>
> Here is the diff to review:
> <paste diff>
>
> In-scope: <files from TASK>
> Out-of-scope: <everything else>
>
> The reviewer should focus on:
> - Failure modes and error paths
> - Edge cases the tests don't cover
> - Input validation gaps
> - Race conditions and state corruption
> - Security surface (injection, privilege escalation, data leakage)
>
> Output: max 20 lines, with `file:line` references.
> Classify each finding: `[must]` (correctness/security) or `[should]` (robustness).
> If no issues: return APPROVE.
>
> After the reviewer finishes, clean up the team.

## After Spawning

**No code edits until BOTH Codex AND the reviewer return (or 5-minute timeout).** Continue with non-edit work only.

Triage the union of Codex + reviewer findings per `execution-core.md` severity rules. Reviewer findings are advisory — they create no markers and block no gates.
