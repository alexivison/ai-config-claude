# TASK1: gemini-log-analyzer Agent

**Issue:** gemini-integration-log-analyzer
**Depends on:** TASK0

## Objective

Create an agent that leverages Gemini's 2M token context for large-scale log analysis.

## Required Context

Read these files first:
- `claude/agents/log-analyzer.md` — Current log analyzer (inherit patterns)
- `claude/agents/codex.md` — Agent definition pattern
- `gemini/AGENTS.md` — Gemini instructions (from TASK0)
- Run `gemini --help` to understand CLI options

## Files to Create/Modify

| File | Action |
|------|--------|
| `claude/agents/gemini-log-analyzer.md` | Create |

## Implementation Details

### claude/agents/gemini-log-analyzer.md

**Frontmatter:**
```yaml
---
name: gemini-log-analyzer
description: "Large-scale log analysis using Gemini's 2M token context. Use for logs exceeding 100K tokens."
model: haiku
tools: Bash, Glob, Grep, Read, Write
color: green
---
```

**Core Behavior:**

1. **Size Estimation:**
   - Count lines: `wc -l`
   - Sample first 100 lines to estimate avg line length
   - Estimate tokens: `(lines × avg_chars) / 4` (rough token estimate)
   - Threshold: 100K tokens

2. **Routing Logic:**
   ```
   IF estimated_tokens < 100K:
     Delegate to standard log-analyzer (return message to main agent)
   ELSE:
     Use Gemini for analysis
   ```

3. **Gemini Invocation (use stdin for large content):**
   ```bash
   # CORRECT: Pipe logs via stdin
   cat /path/to/logs.log | gemini --approval-mode plan -m gemini-2.5-pro -p "Analyze these logs. Identify:
   - Error patterns and frequencies
   - Time-based clusters/spikes
   - Correlations between error types
   - Root cause hypotheses"

   # WRONG: Never embed large content in argument (shell limit ~256KB)
   # gemini -p "$(cat large.log)" ← DO NOT DO THIS
   ```

4. **Output Format:**
   - Same as `log-analyzer.md` for consistency
   - Write to `~/.claude/logs/{identifier}.md`

**Key Sections to Include:**

- Process flow with size check
- Delegation logic to standard log-analyzer
- Gemini CLI invocation pattern (stdin piping)
- Output format matching existing log-analyzer
- Return message format

## Verification

```bash
# Agent file exists and has correct frontmatter
grep -q "gemini-log-analyzer" claude/agents/gemini-log-analyzer.md

# Check for delegation logic
grep -q "100K\|100000\|delegate" claude/agents/gemini-log-analyzer.md

# Check for correct CLI invocation pattern (stdin piping)
grep -qE "cat.*\| gemini" claude/agents/gemini-log-analyzer.md
```

## Acceptance Criteria

- [ ] Agent definition created at `claude/agents/gemini-log-analyzer.md`
- [ ] Includes size estimation logic (100K token threshold)
- [ ] Falls back to standard log-analyzer for small logs
- [ ] Uses `cat logs | gemini -p` pattern (stdin piping, NOT argument embedding)
- [ ] Uses `--approval-mode plan` for read-only operation
- [ ] Output format matches existing log-analyzer
- [ ] Writes findings to `~/.claude/logs/{identifier}.md`
- [ ] Tested with 1MB+ log file successfully
