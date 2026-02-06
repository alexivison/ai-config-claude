# Agent-Skill Separation Design

> **Specification:** [SPEC.md](./SPEC.md)

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    BEFORE (Current)                         │
├─────────────────────────────────────────────────────────────┤
│  codex.md (157 lines)          gemini.md (375 lines)        │
│  ├── WHAT (description)        ├── WHAT (description)       │
│  ├── HOW (CLI commands)        ├── HOW (mode detection)     │
│  ├── HOW (execution process)   ├── HOW (CLI resolution)     │
│  ├── HOW (output format)       ├── HOW (error handling)     │
│  └── HOW (cleanup protocol)    └── HOW (output formats)     │
└─────────────────────────────────────────────────────────────┘

                            ↓ REFACTOR ↓

┌─────────────────────────────────────────────────────────────┐
│                     AFTER (Proposed)                        │
├─────────────────────────────────────────────────────────────┤
│  AGENTS (declarative)          SKILLS (procedural)          │
│  ┌─────────────────────┐       ┌─────────────────────┐      │
│  │ codex.md (~30 lines)│       │ codex-cli/SKILL.md  │      │
│  │ skills:             │──────▶│ - CLI invocation    │      │
│  │   - codex-cli       │       │ - Output format     │      │
│  │ WHAT it does        │       │ - Cleanup protocol  │      │
│  │ WHEN to use         │       │ - Plan review list  │      │
│  └─────────────────────┘       └─────────────────────┘      │
│  ┌─────────────────────┐       ┌─────────────────────┐      │
│  │ gemini.md (~30 lines│       │ gemini-cli/SKILL.md │      │
│  │ skills:             │──────▶│ - Mode detection    │      │
│  │   - gemini-cli      │       │ - CLI resolution    │      │
│  │ WHAT it does        │       │ - Error handling    │      │
│  │ WHEN to use         │       │ - Output formats    │      │
│  └─────────────────────┘       └─────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

## Existing Standards (REQUIRED)

| Pattern | Location | How It Applies |
|---------|----------|----------------|
| Agent frontmatter | `claude/agents/codex.md:1-7` | Use `skills:` field to preload |
| Skill structure | `claude/skills/*/SKILL.md` | Follow existing skill format |
| Non-invocable skills | `claude/skills/task-workflow/SKILL.md:5` | Use `user-invocable: false` |

## File Structure

```
claude/
├── agents/
│   ├── codex.md           # Modify (slim down to ~30 lines)
│   └── gemini.md          # Modify (slim down to ~30 lines)
└── skills/
    ├── codex-cli/
    │   └── SKILL.md       # Create (procedural content ~120 lines)
    └── gemini-cli/
        └── SKILL.md       # Create (procedural content ~340 lines)
```

**Legend:** `Create` = new file, `Modify` = edit existing

## Data Transformation Points (REQUIRED)

No data transformations — this is a content reorganization.

| Source | Destination | What Moves |
|--------|-------------|------------|
| `codex.md:17-55` | `codex-cli/SKILL.md` | Supported task types, plan review checklist |
| `codex.md:56-131` | `codex-cli/SKILL.md` | Execution process, bash rules, output format |
| `codex.md:133-143` | `codex-cli/SKILL.md` | Iteration support |
| `codex.md:155-157` | `codex-cli/SKILL.md` | Safety (`-s read-only` requirement) |
| `gemini.md:17-24` | `gemini-cli/SKILL.md` | Output contract (who writes, where) |
| `gemini.md:26-69` | `gemini-cli/SKILL.md` | Mode detection logic |
| `gemini.md:70-159` | `gemini-cli/SKILL.md` | CLI resolution, error handling |
| `gemini.md:161-192` | `gemini-cli/SKILL.md` | Security & privacy warnings, redaction |
| `gemini.md:193-323` | `gemini-cli/SKILL.md` | Log analysis mode, web search mode |

## Integration Points (REQUIRED)

| Point | Existing Code | New Code Interaction |
|-------|---------------|----------------------|
| Agent invocation | `Task(codex, prompt)` | Unchanged — agent preloads skill |
| Skill loading | Claude Code `skills:` field | Injects skill content at startup |
| Workflow references | `plan-workflow/SKILL.md:61` | No change needed |

## Agent Content After Refactor

### codex.md (Target: ~30 lines)

```markdown
---
name: codex
description: "Deep reasoning via Codex CLI for code review, architecture, plan review, debugging"
model: haiku
tools: Bash, Read, Grep, Glob, TaskStop
skills:
  - codex-cli
color: blue
---

You are a Codex CLI wrapper agent. Delegate deep reasoning tasks to Codex and return structured results.

## Capabilities

- Code review (bugs, security, maintainability)
- Architecture analysis (patterns, complexity)
- Plan review (feasibility, risks, data flow)
- Design decisions (compare approaches)
- Debugging (error analysis)
- Trade-off evaluation

## Boundaries

- **DO**: Read files, invoke Codex CLI, parse output, return structured results
- **DON'T**: Modify files, make commits, implement fixes

## Important

The main agent must NEVER run `codex exec` directly. Always spawn this agent via Task tool.

See preloaded `codex-cli` skill for CLI invocation details and output formats.
```

### gemini.md (Target: ~30 lines)

```markdown
---
name: gemini
description: "Gemini-powered analysis: 2M context for logs, Flash for web search"
model: haiku
tools: Bash, Glob, Grep, Read, Write, WebSearch, WebFetch
skills:
  - gemini-cli
color: green
---

You are a Gemini CLI wrapper agent. Delegate log analysis and web research to Gemini and return structured results.

## Capabilities

- Log analysis (large files up to 2M tokens via gemini-2.5-pro)
- Web search synthesis (via gemini-2.0-flash)

## Mode Selection

- **Log analysis**: File paths with log extensions, "analyze logs" phrases
- **Web search**: "research online", "search the web", explicit external queries

## Boundaries

- **DO**: Read files, estimate size, invoke Gemini CLI, write findings, return results
- **DON'T**: Modify source code, send logs without privacy warning

See preloaded `gemini-cli` skill for mode detection, CLI commands, and output formats.
```

## Skill Content Structure

### codex-cli/SKILL.md sections:

1. CLI Invocation (`codex exec -s read-only`)
2. Timeout and Bash Rules
3. Supported Task Types (table)
4. Plan Review Checklist
5. Execution Process
6. Output Format Templates
7. Iteration Support
8. Cleanup Protocol

### gemini-cli/SKILL.md sections:

1. CLI Resolution (bash function)
2. Mode Detection Logic
3. Error Handling
4. Log Analysis Mode
   - Size estimation
   - Model selection
   - Invocation pattern
   - Overflow strategy
   - Output format
5. Web Search Mode
   - Process
   - Output format
6. Security & Privacy Warnings

## Design Decisions

| Decision | Rationale | Alternatives Considered |
|----------|-----------|-------------------------|
| Use `skills:` preload | Claude Code native mechanism | Inline includes (not supported) |
| `user-invocable: false` | Skills are internal, not for direct use | Make invocable (unnecessary) |
| Keep agent boundaries in agent | Quick reference for agent behavior | Move to skill (loses visibility) |
| Keep capabilities in agent | Helps main agent decide when to invoke | Move to skill (harder to discover) |

## Verification

After refactor:
1. Run `plan-workflow` on a test feature → codex should still review
2. Invoke gemini for log analysis → should still work
3. Check agent line counts (codex <40, gemini <40)
