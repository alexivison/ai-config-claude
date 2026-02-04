# TASK1: gemini-log-analyzer Agent

**Issue:** gemini-integration-log-analyzer
**Depends on:** TASK0

## Objective

Create an agent that leverages Gemini's 2M token context for large-scale log analysis.

## Required Context

Read these files first:
- `claude/agents/log-analyzer.md` — Current log analyzer (inherit patterns)
- `claude/agents/codex.md` — Agent definition pattern
- `gemini-cli/config.toml` — Gemini configuration (from TASK0)

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

3. **Gemini Invocation (CRITICAL: use --file or --stdin):**
   ```bash
   # CORRECT: Use --file for large logs (avoids shell arg limit)
   gemini-cli exec --file /path/to/logs.log "Analyze these logs. Identify:
   - Error patterns and frequencies
   - Time-based clusters/spikes
   - Correlations between error types
   - Root cause hypotheses"

   # CORRECT: Or pipe via stdin
   cat /path/to/logs.log | gemini-cli exec --stdin "Analyze these logs..."

   # WRONG: Never embed large content in argument (shell limit ~256KB)
   # gemini-cli exec "$(cat large.log)" ← DO NOT DO THIS
   ```

4. **Output Format:**
   - Same as `log-analyzer.md` for consistency
   - Write to `~/.claude/logs/{identifier}.md`

**Key Sections to Include:**

- Process flow with size check
- Delegation logic to standard log-analyzer
- Gemini prompt template for log analysis (using --file or --stdin)
- Output format matching existing log-analyzer
- Return message format

## Verification

```bash
# Agent file exists and has correct frontmatter
grep -q "gemini-log-analyzer" claude/agents/gemini-log-analyzer.md

# Check for delegation logic
grep -q "100K\|100000\|delegate" claude/agents/gemini-log-analyzer.md

# Check for correct CLI invocation pattern (--file or --stdin)
grep -qE "\-\-file|\-\-stdin" claude/agents/gemini-log-analyzer.md
```

## Acceptance Criteria

- [ ] Agent definition created at `claude/agents/gemini-log-analyzer.md`
- [ ] Includes size estimation logic (100K token threshold)
- [ ] Falls back to standard log-analyzer for small logs
- [ ] Uses `gemini-cli exec --file` or `--stdin` for large logs (NOT argument embedding)
- [ ] Output format matches existing log-analyzer
- [ ] Writes findings to `~/.claude/logs/{identifier}.md`
- [ ] Tested with 1MB+ log file successfully
