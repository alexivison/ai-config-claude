---
name: working-with-skills
description: Rules and conventions for writing, editing, and organizing agent skills. MUST BE USED when creating a new skill, editing an existing SKILL.md, proposing skill changes via autoskill, or reviewing skill quality. Invoke when asked about skill format, structure, or best practices.
user-invocable: true
---

# Working with Skills

Conventions for creating and maintaining skills across Claude and Codex.

## Skill Directory Structure

```
skill-name/
├── SKILL.md           # Required — frontmatter + instructions
├── reference/         # Optional — detailed docs, API schemas, examples
├── scripts/           # Optional — executable automation (Bash, Python, JS)
└── assets/            # Optional — templates, static resources
```

Only create subdirectories when the content would bloat SKILL.md beyond its core instructions. Most skills need only SKILL.md.

## Frontmatter Specification

Every SKILL.md starts with a YAML frontmatter block:

```yaml
---
name: kebab-case-name
description: What the skill does and when to trigger it.
user-invocable: true
---
```

| Field | Required | Constraints |
|-------|----------|-------------|
| `name` | Yes | Kebab-case, lowercase letters/numbers/hyphens, max 64 chars |
| `description` | Yes | Max 1024 chars, no XML/HTML tags |
| `user-invocable` | Yes | `true` if callable via `/skill-name`, `false` if loaded implicitly |
| `model` | No | Target a specific model (e.g., `claude-opus-4-6` for heavy reasoning) |
| `allowed-tools` | No | Restrict to least-privilege toolset (e.g., `[Read, Grep, Glob]`) |

**The frontmatter is the only part loaded into context at session start.** The full body loads only when the skill activates. Budget accordingly — put discovery logic in the frontmatter, execution logic in the body.

## Writing Descriptions

The description is the primary discovery mechanism. A weak description causes under-triggering (skill exists but never activates).

| Pattern | Bad | Good |
|---------|-----|------|
| Vague purpose | "Helps with PRs" | "Rules for writing PR descriptions useful to human and agent reviewers" |
| Missing triggers | "Manages tests" | "Write tests following Testing Trophy methodology. Use when asked to write tests, add test coverage, or create test files" |
| No activation cues | "Code review skill" | "MUST BE USED when creating a new skill, editing an existing SKILL.md, or proposing skill changes" |

Rules:

1. **State what it does** — first clause, plain language
2. **List explicit triggers** — "Use when..." followed by concrete user intents
3. **Use assertive language** — "MUST BE USED when..." for skills that should always activate in specific contexts
4. **Include synonyms** — users say things differently ("PR comments", "review feedback", "reviewer requests")

## Instruction Body

The Markdown body below the frontmatter contains execution instructions.

### Language

- **Imperative, third-person:** "Analyze the source file", "Run the linter" — not "You should analyze..."
- **Objective:** State facts and rules, not opinions
- **Concise:** Dense information, minimal filler

### Degrees of Freedom

Match instruction specificity to task fragility:

| Freedom | When | Example |
|---------|------|---------|
| **Low** | Catastrophic failure risk, exact sequence required | Provide exact commands: `gh api repos/{owner}/{repo}/pulls/{number}/comments` |
| **Medium** | Pattern matters, details vary | Provide templates/pseudocode the agent adapts to context |
| **High** | Subjective judgment needed | Provide heuristics and principles, trust the model |

### Structure Conventions

- **Numbered steps** for sequential workflows (agents maintain state better with explicit ordering)
- **Tables** for reference data, field specs, signal types, comparisons
- **Code blocks** for output formats, commands, templates
- **Headers** to partition concerns (never nest deeper than H3 within a skill)
- **Cross-references** to other skills or rule files where relevant — don't duplicate

## Progressive Disclosure

The context window is a finite budget. Manage it aggressively:

| Content Type | Location | Loaded When |
|--------------|----------|-------------|
| Discovery metadata | SKILL.md frontmatter | Every session (auto) |
| Core workflow and rules | SKILL.md body | Skill activates |
| Detailed API schemas, long examples | `reference/` | Skill explicitly reads the file |
| Executable automation | `scripts/` | Skill invokes via Bash |
| Templates, static resources | `assets/` | Skill reads on demand |

**Rule of thumb:** If a reference doc exceeds 50 lines and is only needed for a subset of the skill's use cases, move it to `reference/`.

## Shared vs Agent-Specific

| Criteria | Location | Example |
|----------|----------|---------|
| Both agents use it identically | `shared/skills/` | autoskill, address-pr, pr-descriptions |
| Agent-specific workflow or tooling | `claude/skills/` or `codex/skills/` | task-workflow (Claude), planning (Codex) |
| References agent-specific paths or tools | Agent-specific | codex-transport, tmux-handler |

### Creating Shared Skills

1. Create the skill directory in `shared/skills/<name>/`
2. Create symlinks in both agent skill directories:
   ```bash
   ln -s ../../shared/skills/<name> claude/skills/<name>
   ln -s ../../shared/skills/<name> codex/skills/<name>
   ```
3. Commit the symlinks alongside the skill files

### Portability

- Never use absolute paths in shared skills — use relative paths or `{baseDir}` for bundled resources
- Never reference agent-specific config files (e.g., `~/.claude/rules/`) from shared skills
- If a shared skill needs agent-specific behavior, document both paths and let the agent resolve at runtime

## Verification Checklist

Before committing a new or edited skill, verify:

- [ ] `name` is kebab-case, max 64 characters
- [ ] `description` is under 1024 characters, includes trigger phrases
- [ ] `user-invocable` is set correctly (`true` only if direct invocation makes sense)
- [ ] `allowed-tools` restricts to minimum necessary (if specified)
- [ ] No hardcoded secrets, API keys, or PII
- [ ] No absolute paths in shared skills
- [ ] Instructions are imperative, not second-person
- [ ] Workflows use numbered steps
- [ ] Large reference material is in `reference/`, not inlined
- [ ] Symlinks created for shared skills (both `claude/skills/` and `codex/skills/`)

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|--------------|---------|-----|
| Kitchen-sink skill | Overloaded context, slow activation | Split into focused skills |
| Duplicated content | Drift between copies | Cross-reference with file paths |
| Missing triggers in description | Skill never activates | Add "Use when..." with explicit intents |
| Second-person instructions | POV inconsistency when injected into system prompt | Use imperative third-person |
| Hardcoded paths | Breaks across environments | Use relative paths or `{baseDir}` |
| Over-permissive tools | Security risk | Set `allowed-tools` to minimum needed |
| Inlined 200-line reference | Wastes context budget on every activation | Move to `reference/` subdirectory |
