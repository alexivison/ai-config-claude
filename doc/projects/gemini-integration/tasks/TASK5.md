# TASK5: Documentation Updates

**Issue:** gemini-integration-docs
**Depends on:** TASK1, TASK2, TASK3

## Objective

Update all documentation to reflect the new Gemini agents.

## Required Context

Read these files first:
- `claude/agents/README.md` — Agent documentation
- `claude/CLAUDE.md` — Main configuration with sub-agents table
- `gemini/AGENTS.md` (from TASK0)

## Files to Modify

| File | Action |
|------|--------|
| `claude/agents/README.md` | Modify |
| `claude/CLAUDE.md` | Modify |

## Implementation Details

### claude/agents/README.md

Add three new sections after `codex`:

```markdown
## gemini-log-analyzer
**Use when:** Analyzing logs that exceed 100K tokens (~5K lines).

**Behavior:** Estimates log size, delegates to standard log-analyzer for small logs, uses Gemini 2M context for large logs.

**Writes to:** `~/.claude/logs/{identifier}.md`

**Returns:** Brief summary with file path, error counts, patterns.

**Note:** Uses Haiku (wrapper) + Gemini 2.5 Pro (via Gemini CLI). Falls back to standard log-analyzer for logs < 100K tokens.

## gemini-ui-debugger
**Use when:** Comparing implementation screenshots to Figma designs.

**Behavior:** Captures screenshot (via Chrome DevTools MCP or file path), fetches Figma design (via Figma MCP), compares using Gemini's multimodal capabilities.

**Returns:** Discrepancy report with severity ratings and suggested CSS fixes.

**Note:** Uses Haiku (wrapper) + Gemini 2.5 Pro (via Gemini CLI). Requires Figma URL or file key.

## gemini-web-search
**Use when:** Researching questions that need external information.

**Trigger:** Auto-suggested by skill-eval.sh for research queries.

**Behavior:** Performs web searches, optionally fetches full pages, synthesizes results using Gemini Flash.

**Returns:** Structured findings with source citations and confidence level.

**Note:** Uses Haiku (wrapper) + Gemini 2.0 Flash (via Gemini CLI). Always cites sources.
```

### claude/CLAUDE.md

Update the Sub-Agents table to include:

```markdown
| Scenario | Agent |
|----------|-------|
| Run tests | test-runner |
| Run typecheck/lint | check-runner |
| Security scan | security-scanner (optional) |
| Complex bug investigation | codex (debugging task) |
| Analyze logs | log-analyzer (or gemini-log-analyzer for large logs) |
| After implementing | code-critic (MANDATORY) |
| After code-critic | codex (MANDATORY) |
| After creating plan | codex (MANDATORY) |
| Large log analysis (>100K tokens) | gemini-log-analyzer |
| UI vs Figma comparison | gemini-ui-debugger |
| Web research | gemini-web-search |
```

## Verification

```bash
# Check for new agent documentation
grep -q "gemini-log-analyzer" claude/agents/README.md
grep -q "gemini-ui-debugger" claude/agents/README.md
grep -q "gemini-web-search" claude/agents/README.md

# Check CLAUDE.md updated
grep -q "gemini-" claude/CLAUDE.md
```

## Acceptance Criteria

- [ ] `claude/agents/README.md` updated with three new agent sections
- [ ] `claude/CLAUDE.md` sub-agents table updated
- [ ] All verification commands pass
