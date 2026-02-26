---
name: tmux-handler
description: Handle incoming messages from Claude via tmux — review requests, task requests, plan reviews, and questions.
---

# tmux-handler — Handle incoming messages from Claude via tmux

## Trigger

You see a message in your pane prefixed with `[CLAUDE]`. These are from Claude's tmux pane.

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
- Always wrap the TOON block in a fenced ` ```toon ` code block.

## Transport direction

| Agent calling | Script to use | Direction |
|---|---|---|
| Claude | `tmux-codex.sh` | Claude → Codex |
| Codex | `tmux-claude.sh` | Codex → Claude |

## Message types

### Review request
Message asks you to review changes against a base branch.

1. **Get the diff**: Run `git diff $(git merge-base HEAD <base>)..HEAD` to see the changes
2. **Review scope**: Review changed files AND adjacent files (callers, callees, types, tests)
   for: correctness bugs, crash paths, security issues, wrong output, architectural concerns
3. **Classify each finding**:
   - **blocking**: correctness bug, crash path, wrong output, security HIGH/CRITICAL
   - **non-blocking**: style nit, "could be simpler", defensive edge case, consistency preference
4. **Write findings** to the file path specified in the message, using the TOON findings schema above.
5. **Do NOT include a "verdict" field.** You produce findings — the verdict is Claude's decision.
6. **Notify Claude** when done:
   ```bash
   ~/.codex/skills/claude-transport/scripts/tmux-claude.sh "Review complete. Findings at: <findings_file>"
   ```

### Re-review request
Claude fixed blocking issues and requests another pass.

- Verify previous blocking issues were addressed
- Flag only genuinely NEW issues
- Do NOT re-raise findings that were already addressed

### Task request
Claude asks you to investigate or work on something.

1. Perform the requested task
2. Write results to the file path specified (if given)
3. Notify Claude: `tmux-claude.sh "Task complete. Response at: <path>"`

### Plan review request
Claude shares a plan and asks for your assessment.

1. Read the plan
2. Evaluate feasibility, risks, missing steps
3. Write feedback to the specified file using the TOON findings schema above (categories may include `architecture`, `feasibility`, `missing-step`)
4. Notify Claude: `tmux-claude.sh "Plan review complete. Findings at: <path>"`

### Question from Claude
Claude asks for information or your opinion.

1. Read the question
2. Investigate the codebase or reason about the answer
3. **Structured findings response**: When Claude requests structured findings and provides a `.toon` response path, emit TOON with the canonical schema above — not markdown.
4. **Narrative Q&A**: When the request is conversational, write concise text.
5. Write response to the exact path Claude specified (do not change the extension).
6. Notify Claude: `tmux-claude.sh "Response ready at: <path>"`
