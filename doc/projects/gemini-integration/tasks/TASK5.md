# TASK5: Documentation Updates

**Issue:** gemini-integration-docs
**Depends on:** TASK1, TASK2, TASK3

## Objective

Update all documentation to reflect the new Gemini agents.

## Required Context

Read these files first:
- `claude/agents/README.md` — Agent documentation
- `claude/CLAUDE.md` — Main configuration with sub-agents table
- `gemini-cli/` directory (from TASK0)

## Files to Modify

| File | Action |
|------|--------|
| `claude/agents/README.md` | Modify |
| `claude/CLAUDE.md` | Modify |
| `gemini-cli/README.md` | Create |

## Implementation Details

### claude/agents/README.md

Add three new sections after `codex`:

```markdown
## gemini-log-analyzer
**Use when:** Analyzing logs that exceed 100K tokens (~5K lines).

**Behavior:** Estimates log size, delegates to standard log-analyzer for small logs, uses Gemini 2M context for large logs.

**Writes to:** `~/.claude/logs/{identifier}.md`

**Returns:** Brief summary with file path, error counts, patterns.

**Note:** Uses Haiku (wrapper) + Gemini 1.5 Pro (via Gemini CLI). Falls back to standard log-analyzer for logs < 100K tokens.

## gemini-ui-debugger
**Use when:** Comparing implementation screenshots to Figma designs.

**Behavior:** Captures screenshot (via Chrome DevTools MCP or file path), fetches Figma design (via Figma MCP), compares using Gemini's multimodal capabilities.

**Returns:** Discrepancy report with severity ratings and suggested CSS fixes.

**Note:** Uses Haiku (wrapper) + Gemini 1.5 Pro (via Gemini CLI). Requires Figma URL or file key.

## gemini-web-search
**Use when:** Researching questions that need external information.

**Trigger:** Auto-suggested by skill-eval.sh for research queries.

**Behavior:** Performs web searches, optionally fetches full pages, synthesizes results using Gemini Flash.

**Returns:** Structured findings with source citations and confidence level.

**Note:** Uses Haiku (wrapper) + Gemini 1.5 Flash (via Gemini CLI). Always cites sources.
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

### gemini-cli/README.md

Create setup and usage documentation:

```markdown
# Gemini CLI

Gemini integration for Claude Code, providing access to Gemini's unique capabilities.

## Setup

1. Get a Gemini API key from [Google AI Studio](https://aistudio.google.com/app/apikey)

2. Set environment variable:
   ```bash
   export GEMINI_API_KEY="your-api-key"
   ```

3. Optionally add to shell profile (`~/.zshrc` or `~/.bashrc`):
   ```bash
   echo 'export GEMINI_API_KEY="your-api-key"' >> ~/.zshrc
   ```

## Usage

The CLI is invoked by Claude Code agents, not directly by users.

### Commands

```bash
# Text query (default model: gemini-1.5-pro)
gemini-cli exec "Your prompt here"

# Use Flash model for faster inference
gemini-cli exec --model flash "Your prompt here"

# Multimodal query with image
gemini-cli exec --image /path/to/image.png "Describe this image"

# Multiple images (max 4)
gemini-cli exec --image img1.png --image img2.png "Compare these images"

# Large input via stdin (REQUIRED for inputs > 100KB)
cat large.log | gemini-cli exec --stdin "Analyze these logs..."

# Large input via file
gemini-cli exec --file /path/to/large.log "Analyze these logs..."
```

## Configuration

Edit `gemini-cli/config.toml`:

```toml
[models]
default = "gemini-1.5-pro-latest"    # For log analysis, UI comparison
fast = "gemini-1.5-flash-latest"      # For web search synthesis
```

## Agents Using Gemini

| Agent | Model | Use Case |
|-------|-------|----------|
| gemini-log-analyzer | Pro | Large log files (>100K tokens) |
| gemini-ui-debugger | Pro | Screenshot vs Figma comparison |
| gemini-web-search | Flash | Web research synthesis |

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "GEMINI_API_KEY not set" | Set the environment variable |
| Rate limit errors | Wait and retry, or reduce request frequency |
| Image too large | Resize image before sending |
```

## Verification

```bash
# Check README files exist
test -f claude/agents/README.md && echo "agents/README.md exists"
test -f gemini-cli/README.md && echo "gemini-cli/README.md exists"

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
- [ ] `gemini-cli/README.md` created with setup instructions
- [ ] All verification commands pass
