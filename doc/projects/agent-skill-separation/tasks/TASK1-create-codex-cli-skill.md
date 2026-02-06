# Task 1 — Create codex-cli Skill

**Dependencies:** none | **Issue:** agent-skill-separation

---

## Goal

Extract all procedural content from `codex.md` into a new `codex-cli` skill. This skill will contain CLI invocation details, output formats, and execution procedures that the codex agent will preload via the `skills:` field.

## Scope Boundary (REQUIRED)

**In scope:**
- Creating `claude/skills/codex-cli/SKILL.md`
- Extracting CLI commands, execution process, output formats from codex.md
- Plan review checklist (recently added)

**Out of scope:**
- Modifying codex.md (Task 2)
- Gemini agent/skill (Tasks 3-4)

## Reference

Files to study before implementing:

- `claude/agents/codex.md` — Source content to extract
- `claude/skills/task-workflow/SKILL.md` — Example of non-invocable skill structure

## Files to Create/Modify

| File | Action |
|------|--------|
| `claude/skills/codex-cli/SKILL.md` | Create |

## Requirements

**Functionality:**
- Skill must have `user-invocable: false` in frontmatter
- Include all CLI invocation patterns from codex.md
- Include execution process steps
- Include output format templates
- Include plan review checklist
- Include cleanup protocol
- Include iteration support

**Content to extract from codex.md:**

1. Lines 17-27: Supported Task Types table
2. Lines 28-55: Plan Review Checklist (CRITICAL section)
3. Lines 56-64: Execution Process
4. Lines 65-79: Bash Execution Rules
5. Lines 80-93: Cleanup Protocol
6. Lines 94-131: Output Format templates
7. Lines 133-143: Iteration Support
8. Lines 155-157: Safety (`-s read-only` requirement)

## Tests

- Skill file exists at correct path
- Frontmatter has `user-invocable: false`
- All sections from source are present

## Acceptance Criteria

- [x] `claude/skills/codex-cli/SKILL.md` created
- [x] Contains all procedural content from codex.md
- [x] Frontmatter includes `user-invocable: false`
- [x] ~120 lines of content (138 lines)
