# Task 3 — Create gemini-cli Skill

**Dependencies:** none | **Issue:** agent-skill-separation

---

## Goal

Extract all procedural content from `gemini.md` into a new `gemini-cli` skill. This skill will contain mode detection, CLI resolution, error handling, and output formats that the gemini agent will preload via the `skills:` field.

## Scope Boundary (REQUIRED)

**In scope:**
- Creating `claude/skills/gemini-cli/SKILL.md`
- Extracting mode detection, CLI resolution, error handling from gemini.md
- Log analysis procedures and output formats
- Web search procedures and output formats
- Security/privacy warnings

**Out of scope:**
- Modifying gemini.md (Task 4)
- Codex agent/skill (Tasks 1-2)

## Reference

Files to study before implementing:

- `claude/agents/gemini.md` — Source content to extract
- `claude/skills/task-workflow/SKILL.md` — Example of non-invocable skill structure

## Files to Create/Modify

| File | Action |
|------|--------|
| `claude/skills/gemini-cli/SKILL.md` | Create |

## Requirements

**Functionality:**
- Skill must have `user-invocable: false` in frontmatter
- Include all mode detection logic
- Include CLI resolution (bash function)
- Include error handling patterns
- Include log analysis mode (size estimation, model selection, invocation, overflow)
- Include web search mode
- Include security/privacy warnings
- Include output format templates

**Content to extract from gemini.md:**

1. Lines 17-24: Output Contract (CRITICAL — who writes output, where)
2. Lines 26-69: Mode Detection (explicit override, keyword heuristics, ambiguity)
3. Lines 70-107: CLI Resolution (bash function)
4. Lines 109-159: Error Handling
5. Lines 161-192: Security & Privacy (warnings, redaction guidance, pre-flight checks)
6. Lines 193-323: Log Analysis Mode (size estimation, invocation, overflow, output)
7. Lines 324-363: Web Search Mode
8. Lines 365-375: Boundaries and Safety

## Tests

- Skill file exists at correct path
- Frontmatter has `user-invocable: false`
- All sections from source are present
- Bash functions preserved correctly

## Acceptance Criteria

- [x] `claude/skills/gemini-cli/SKILL.md` created
- [x] Contains all procedural content from gemini.md
- [x] Frontmatter includes `user-invocable: false`
- [x] ~340 lines of content (361 lines)
