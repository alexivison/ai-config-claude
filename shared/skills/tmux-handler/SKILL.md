---
name: tmux-handler
description: >-
  Handle incoming peer-agent messages via tmux. Covers review requests, review
  completion, questions, task requests/results, plan review requests/results,
  and NEEDS_DISCUSSION debates, in TOON format. Triggers whenever a `[PRIMARY]`
  or `[COMPANION]` prefixed message appears. Use this skill to correctly parse,
  validate, triage, and respond to peer-agent communication regardless of which
  role you hold.
user-invocable: false
---

# tmux-handler — Handle incoming messages from the peer agent via tmux

This skill is role-aware: your current role determines which message types you receive and which transport script you reply through. `[PRIMARY]` and `[COMPANION]` are the message prefixes.

## Trigger

You see a message in your pane prefixed with `[PRIMARY]` or `[COMPANION]`. The prefix identifies the sender; you infer your own role from context.

## Reply direction

Reply through the transport script in your **own** agent's `agent-transport` skill directory. The canonical scripts live locally, not in `shared/`.

| Your role | Script to use | Direction |
|---|---|---|
| primary  | `tmux-companion.sh` | primary → companion |
| companion | `tmux-primary.sh` | companion → primary |

Invoke via the skill directory that corresponds to your agent (examples, substitute your agent's skill root):

- Primary → companion prompt: `<agent-skill-root>/agent-transport/scripts/tmux-companion.sh --prompt "<message>" "$(pwd)"`
- Companion → primary notify: `<agent-skill-root>/agent-transport/scripts/tmux-primary.sh "<message>"`

## TOON findings format

All structured findings (code review, plan review) use TOON format.

### Canonical schema

```toon
findings[N]{id,file,line,severity,category,description,suggestion}:
  F1,path/to/file.ts,42,blocking,correctness,"Description here","Suggestion here"
summary: One paragraph summary
stats:
  blocking_count: 0
  non_blocking_count: 0
  files_reviewed: 0
```

### Rules

- Field order is fixed: `id,file,line,severity,category,description,suggestion`.
- `line` MUST be an unquoted integer.
- `description` and `suggestion` MUST be quoted when they contain commas, colons, quotes, backslashes, or control characters.
- Quoted strings use TOON escaping: `\\`, `\"`, `\n`, `\r`, `\t`.
- `findings[N]` MUST equal the actual row count.
- Findings files contain raw TOON only. Do NOT wrap file contents in markdown fences.

### Triage checklist (readers)

When reading a TOON findings file:
1. Validate header line matches `findings[N]{id,file,line,severity,category,description,suggestion}:`
2. Verify `[N]` equals the actual row count
3. Read `summary` and `stats` sections
4. If malformed: record validation issue, request re-emit via `--prompt`, OR triage manually as plain text if urgent

### Helper workflow

When Bash is available, prefer the shared transport helper over manual TOON parsing or emission. The helper lives in your agent's local `agent-transport/scripts/` directory under the name `toon-transport.sh`:

- Encode canonical findings JSON to raw TOON:
  `<agent-skill-root>/agent-transport/scripts/toon-transport.sh encode-findings /tmp/findings.json <findings_file>`
- Decode a TOON findings file to JSON for inspection:
  `<agent-skill-root>/agent-transport/scripts/toon-transport.sh decode <findings_file>`
- Validate a TOON findings file:
  `<agent-skill-root>/agent-transport/scripts/toon-transport.sh validate-findings <findings_file>`

Preferred emission flow:
1. Draft findings as canonical JSON in a temp file.
2. Run `encode-findings` to produce the final `.toon` file.
3. If uncertain, run `validate-findings` before notifying the peer.

## Message types received by the companion (from the primary)

### Review request
Message asks you to review changes against a base branch.

Default priority for review findings (highest first):
1. Correctness and regression risk
2. Unnecessary complexity / over-abstraction
3. Simpler equivalent approach
4. Style and preference nits (only when explicitly requested)

1. **Get the diff**: Run `git diff $(git merge-base HEAD <base>)..HEAD` to see the changes.
2. **Review scope**: Review changed files AND adjacent files (callers, callees, types, tests) for correctness bugs, crash/regression paths, security issues, wrong output, and avoidable complexity.
3. **Classify each finding**:
   - **blocking**: correctness bug, crash/regression path, wrong output, security HIGH/CRITICAL
   - **non-blocking**: materially simpler equivalent implementation that reduces complexity/risk
   - **omit by default**: style nits, naming preferences (include only if the primary explicitly asks for polish/nits)
4. **Write findings** to the file path specified in the message, using the helper workflow above whenever Bash is available.
5. Include a single `VERDICT:` line at the end of the findings file (`VERDICT: APPROVED` or `VERDICT: REQUEST_CHANGES`). The primary's `--review-complete` call reads this line.
6. **Notify the primary** using the reply direction above with the canonical `[COMPANION] Review complete. Findings at: <path>` message.

### Re-review request
The primary fixed blocking issues and requests another pass.

- Verify previous blocking issues were addressed
- Flag only genuinely NEW blocking/non-blocking issues
- Do NOT re-raise findings that were already addressed
- Do not introduce new nit-level churn in re-review unless explicitly requested

### Task request
The primary asks you to investigate or work on something.

1. Perform the requested task
2. Write results to the file path specified (if given)
3. Notify the primary with `[COMPANION] Task complete. Response at: <path>`

### NEEDS_DISCUSSION debate (via --prompt)
The primary sends a structured position on a disputed finding — either from your review or a critic's.

1. Read the primary's position: concede, counter-argue, or propose compromise, with evidence
2. Evaluate the evidence against the codebase:
   - If well-supported (concrete file:line, diff evidence) → **concede** explicitly
   - If gaps → **counter** with your own file:line evidence showing why the finding stands
   - If both positions have merit → **propose compromise** (e.g., "fix X but defer Y")
3. Responses must be evidence-based — "I still think this is wrong" without a file:line reference is not a valid counter
4. **No fixed exchange cap.** Continue the discussion — each round should make progress. If the discussion becomes genuinely circular (same arguments repeated 3+ times with no new evidence), state your final position clearly so the primary can escalate to the user with both sides summarized
5. Write response to the specified path
6. Notify the primary with `[COMPANION] Task complete. Response at: <response_file>`

### Plan review request
The primary shares a plan and asks for your assessment.

1. Read the plan
2. Evaluate feasibility, risks, missing steps
3. Write feedback to the specified file using the TOON findings schema above (categories may include `architecture`, `feasibility`, `missing-step`). Prefer the helper workflow over hand-typing TOON.
4. Notify the primary with `[COMPANION] Plan review complete. Findings at: <path>`

### Question from the primary
The primary asks for information or your opinion.

1. Read the question
2. Investigate the codebase or reason about the answer
3. **Structured findings response**: When the primary requests structured findings and provides a `.toon` response path, emit canonical TOON with the helper workflow above — not markdown.
4. **Narrative Q&A**: When the request is conversational, write concise text. A `.toon` extension alone does not mean the payload must be structured TOON.
5. Write response to the exact path the primary specified (do not change the extension).
6. Notify the primary with `[COMPANION] Task complete. Response at: <response_file>`

## Message types received by the primary (from the companion)

### Review complete
Message: `[COMPANION] Review complete. Findings at: <path>`

1. Read the FULL findings file (TOON format) with your read mechanism, or decode via the helper workflow above
2. Validate per the triage checklist above (or via `validate-findings`)
3. Mark review evidence as complete using your agent's transport:
   `<agent-skill-root>/agent-transport/scripts/tmux-companion.sh --review-complete <path>`
4. Triage each finding: blocking / non-blocking / out-of-scope
5. Update your issue ledger (reject re-raised closed findings, detect oscillation)
6. The verdict comes from the `VERDICT:` line the companion wrote in the findings file — `--review-complete` reads it automatically:
   - `VERDICT: APPROVED` in findings → approval evidence created
   - `VERDICT: REQUEST_CHANGES` → no approval evidence; fix code, re-run critics, dispatch new `--review` → `--review-complete`
   - Unresolvable → `tmux-companion.sh --needs-discussion "reason"`
   - **Do NOT call `--approve` directly** — the gate blocks it.

### Question from the companion
Message: `[COMPANION] Question: <question>. Write response to: <response_file>`

1. Read the question
2. Investigate the codebase to answer
3. **Structured findings response**: When the companion requests structured findings and provides a `.toon` response path, emit canonical TOON with the helper workflow above — not markdown tables. The requester controls the extension; write to the exact path provided.
4. **Narrative Q&A**: When the request is conversational, write concise text to the provided path. A `.toon` extension alone does not force a structured TOON payload.
5. Notify the companion with `[PRIMARY] Task complete. Response at: <response_file>`

### Task complete
Message: `[COMPANION] Task complete. Response at: <path>`

1. Read the response file. If the original request asked for structured findings, expect TOON; otherwise treat it as plain text.
2. Stop polling once that notice arrives, then continue your workflow with the information the companion provided.

### Plan review complete
Message: `[COMPANION] Plan review complete. Findings at: <path>`

1. Read the findings file (TOON format), preferably via the helper workflow above
2. Validate per the triage checklist above
3. Triage findings same as code review (blocking / non-blocking / out-of-scope)
4. Incorporate feedback into the plan

## Dispute Resolution

Follow `shared/execution-core.md` § Dispute Resolution. Use `--dispute <file>` with `--review` for companion disputes, `--prompt` for NEEDS_DISCUSSION debates.
