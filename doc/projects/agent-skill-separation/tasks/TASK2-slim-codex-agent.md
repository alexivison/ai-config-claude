# Task 2 — Slim codex.md to Declarative Only

**Dependencies:** Task 1 | **Issue:** agent-skill-separation

---

## Goal

Reduce `codex.md` from 157 lines to ~30 lines by removing procedural content (now in `codex-cli` skill) and keeping only declarative content. Add `skills: [codex-cli]` to frontmatter.

## Scope Boundary (REQUIRED)

**In scope:**
- Modifying `claude/agents/codex.md`
- Adding `skills:` field to frontmatter
- Keeping only: description, capabilities, boundaries, important notes

**Out of scope:**
- codex-cli skill (Task 1 — must be complete)
- Gemini agent/skill (Tasks 3-4)

## Reference

Files to study before implementing:

- `claude/skills/codex-cli/SKILL.md` — Skill that agent will preload
- `doc/projects/agent-skill-separation/DESIGN.md` — Target agent structure

## Files to Create/Modify

| File | Action |
|------|--------|
| `claude/agents/codex.md` | Modify |

## Requirements

**Keep in agent:**
- Frontmatter (name, description, model, tools, color) + add `skills:`
- Core principle (1-2 sentences)
- Capabilities list (what it can do)
- Boundaries (DO/DON'T)
- Important notes (main agent must not run codex directly)
- Reference to preloaded skill

**Remove from agent (now in skill):**
- Supported Task Types table
- Plan Review Checklist
- Execution Process
- Bash Execution Rules
- Cleanup Protocol
- Output Format templates
- Iteration Support

**Target structure:**
```markdown
---
name: codex
description: "..."
model: haiku
tools: Bash, Read, Grep, Glob, TaskStop
skills:
  - codex-cli
color: blue
---

[Core principle - 2 sentences]

## Capabilities
[Bullet list]

## Boundaries
[DO/DON'T]

## Important
[Main agent note]

See preloaded `codex-cli` skill for CLI details and output formats.
```

## Tests

- Agent file < 40 lines
- `skills:` field present in frontmatter
- References `codex-cli` skill
- Capabilities and boundaries still documented

## Acceptance Criteria

- [x] codex.md reduced to < 40 lines (37 lines)
- [x] Frontmatter includes `skills: [codex-cli]`
- [x] Agent still describes capabilities and boundaries
- [x] References preloaded skill for procedural details
