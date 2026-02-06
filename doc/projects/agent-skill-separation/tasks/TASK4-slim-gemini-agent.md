# Task 4 — Slim gemini.md to Declarative Only

**Dependencies:** Task 3 | **Issue:** agent-skill-separation

---

## Goal

Reduce `gemini.md` from 375 lines to ~30 lines by removing procedural content (now in `gemini-cli` skill) and keeping only declarative content. Add `skills: [gemini-cli]` to frontmatter.

## Scope Boundary (REQUIRED)

**In scope:**
- Modifying `claude/agents/gemini.md`
- Adding `skills:` field to frontmatter
- Keeping only: description, capabilities, mode overview, boundaries

**Out of scope:**
- gemini-cli skill (Task 3 — must be complete)
- Codex agent/skill (Tasks 1-2)

## Reference

Files to study before implementing:

- `claude/skills/gemini-cli/SKILL.md` — Skill that agent will preload
- `doc/projects/agent-skill-separation/DESIGN.md` — Target agent structure

## Files to Create/Modify

| File | Action |
|------|--------|
| `claude/agents/gemini.md` | Modify |

## Requirements

**Keep in agent:**
- Frontmatter (name, description, model, tools, color) + add `skills:`
- Core principle (1-2 sentences)
- Capabilities list (what it can do)
- Mode selection overview (brief — log vs web)
- Boundaries (DO/DON'T)
- Reference to preloaded skill

**Remove from agent (now in skill):**
- Output Contract table
- Mode Detection detailed logic
- CLI Resolution bash function
- Error Handling
- Security & Privacy (detailed)
- Log Analysis Mode procedures
- Web Search Mode procedures

**Target structure:**
```markdown
---
name: gemini
description: "..."
model: haiku
tools: Bash, Glob, Grep, Read, Write, WebSearch, WebFetch
skills:
  - gemini-cli
color: green
---

[Core principle - 2 sentences]

## Capabilities
[Bullet list - log analysis, web search]

## Mode Selection
[Brief overview - when log vs web]

## Boundaries
[DO/DON'T]

See preloaded `gemini-cli` skill for mode detection, CLI commands, and output formats.
```

## Tests

- Agent file < 40 lines
- `skills:` field present in frontmatter
- References `gemini-cli` skill
- Capabilities and boundaries still documented

## Acceptance Criteria

- [x] gemini.md reduced to < 40 lines (32 lines)
- [x] Frontmatter includes `skills: [gemini-cli]`
- [x] Agent still describes capabilities and boundaries
- [x] References preloaded skill for procedural details
