# TASK0: Gemini CLI Configuration

**Issue:** gemini-integration-config

## Objective

Configure the Gemini CLI with instructions and context-loader skill, following the same pattern as Codex.

## Required Context

Read these files first:
- `gemini/settings.json` — Existing OAuth credentials (separate from `.gemini/` config)
- `codex/AGENTS.md` — Reference for instructions pattern
- `codex/skills/context-loader/SKILL.md` — Reference for context-loader skill
- Run `gemini --help` and `gemini skills --help` to understand CLI

## Files to Create

| File | Purpose |
|------|---------|
| `.gemini/GEMINI.md` | Instructions for Gemini when invoked by agents |
| `.gemini/skills/context-loader/SKILL.md` | Load shared context from `claude/` |

**Note:** The `gemini/` folder (OAuth creds) is separate from `.gemini/` (CLI config).

## Implementation Details

### Directory Structure

```
.gemini/                          # NEW - Gemini CLI config
├── GEMINI.md                     # Instructions for Gemini
└── skills/
    └── context-loader/
        └── SKILL.md              # Load shared context

gemini/                           # EXISTING - OAuth credentials
├── oauth_creds.json
├── settings.json
└── google_accounts.json
```

### .gemini/GEMINI.md

```markdown
# Gemini CLI — Research & Analysis Agent

**You are called by Claude Code for research and large-scale analysis.**

## Your Position

Claude Code (Orchestrator) calls you for:
- Large-scale log analysis (2M token context)
- Web research and synthesis
- Documentation search

You are part of a multi-agent system. Claude Code handles orchestration and execution.
You provide **research and analysis** that benefits from your 2M token context.

## Your Strengths (Use These)

- **2M token context**: Analyze massive log files at once
- **Google Search**: Latest docs, best practices, solutions
- **Fast synthesis**: Quick understanding of search results

## NOT Your Job (Others Do These)

| Task | Who Does It |
|------|-------------|
| Design decisions | Codex |
| Code review | code-critic, Codex |
| Code implementation | Claude Code |
| File editing | Claude Code |

## Output Format

Structure your response for Claude Code to use:

### For Log Analysis:
```markdown
## Log Analysis Report

**Source:** {log_path}
**Lines analyzed:** {count}

### Summary
{Key findings in 3-5 bullet points}

### Error Patterns
| Pattern | Count | Severity |
|---------|-------|----------|
...

### Recommendations
{Actionable suggestions}
```

### For Web Research:
```markdown
## Research Findings

**Query:** {question}

### Summary
{Key findings in 3-5 bullet points}

### Details
{Comprehensive analysis}

### Sources
{Links to documentation, examples}
```

## Key Principles

1. **Be thorough** — Use your large context to find comprehensive answers
2. **Cite sources** — Include URLs and references for web research
3. **Be actionable** — Focus on what Claude Code can use
4. **Stay in lane** — Analysis only, no code changes
```

### .gemini/skills/context-loader/SKILL.md

```markdown
---
name: context-loader
description: Load shared project context from claude/ directory to ensure Gemini CLI operates with the same knowledge as Claude Code.
---

# Context Loader Skill

## Purpose

Load shared project context to ensure Gemini CLI has the same knowledge as Claude Code.

## When to Activate

**ALWAYS** — This skill runs at the beginning of every research or analysis task.

## Execution

Read these files in order:

### 1. Rules (claude/rules/)
- `execution-core.md` — Core execution patterns
- `autonomous-flow.md` — Workflow guidelines
- `development.md` — Git and coding standards

### 2. Agent Instructions (claude/agents/)
- `README.md` — Agent overview and selection guide

### 3. Current Task Context
- Check for `TASK*.md` files in current directory
- Check for `PLAN.md` for implementation context

## Key Operating Principles

1. Prioritize readable, straightforward solutions
2. Default to analysis-only mode (no file modifications)
3. Reference existing patterns from the codebase
```

### Verify CLI Installation

```bash
# Check CLI is available
which gemini || command -v gemini

# Check version
gemini --version

# Verify authentication
gemini -p "Hello, respond with 'OK'" 2>&1 | head -5

# Check skills system
gemini skills list
```

### CLI Usage Patterns

| Pattern | Command |
|---------|---------|
| Simple query | `gemini -p "prompt"` |
| Large input via stdin | `cat file.log \| gemini -p "Analyze..."` |
| Read-only mode | `gemini --approval-mode plan -p "..."` |
| Model selection | `gemini -m gemini-2.0-flash -p "..."` |

### Comparison with Codex

| Feature | Codex | Gemini |
|---------|-------|--------|
| Instructions file | `codex/AGENTS.md` | `.gemini/GEMINI.md` |
| Skills directory | `codex/skills/` | `.gemini/skills/` |
| Prompt flag | Inline string | `-p "prompt"` |
| Read-only mode | `-s read-only` | `--approval-mode plan` |

## Verification

```bash
# Check directory structure
test -f .gemini/GEMINI.md && echo "GEMINI.md exists"
test -f .gemini/skills/context-loader/SKILL.md && echo "context-loader exists"

# Test CLI invocation
gemini -p "Respond with only: GEMINI_OK" 2>&1 | grep -q "GEMINI_OK" && echo "CLI works"

# Test stdin input
echo "test content" | gemini -p "Echo the input content" 2>&1 | head -3

# Test model selection
gemini -m gemini-2.0-flash -p "Say 'Flash OK'" 2>&1 | head -3
```

## Acceptance Criteria

- [ ] `.gemini/GEMINI.md` created with agent instructions
- [ ] `.gemini/skills/context-loader/SKILL.md` created
- [ ] CLI responds to `-p` flag queries
- [ ] Stdin input works (pipe content to gemini)
- [ ] Model selection works (`-m` flag)
- [ ] `--approval-mode plan` works for read-only
- [ ] Existing `gemini/` OAuth credentials NOT modified
