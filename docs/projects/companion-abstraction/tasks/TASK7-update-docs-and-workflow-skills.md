# Task 7 — Update Docs and Workflow Skills

**Dependencies:** Task 2, Task 3, Task 4

## Goal

Update all human-readable docs and workflow skill prompts to use role-based language. "Codex" becomes the default companion persona ("The Wizard"), and all plumbing references use generic companion terminology. Natural language like "ask the Wizard" continues to work.

## Scope Boundary

**In scope:**
- `claude/CLAUDE.md` — replace plumbing references (`party-cli transport` examples use `--to wizard`; "Codex review" → "companion review") while keeping persona flavor ("The Wizard")
- `claude/rules/execution-core.md` — replace `codex` in sequence descriptions with `companion`
- Workflow skills: `task-workflow`, `bugfix-workflow`, `plan-workflow` — update transport invocations and companion references
- `codex/AGENTS.md` — add note that Codex is one companion implementation; its review conventions (TOON, verdicts) are the standard
- `claude/skills/companion-transport/SKILL.md` — final consistency pass

**Out of scope:**
- Changing execution-core logic or sequence (just wording)
- Changing sub-agent prompts (critic, minimizer, scribe, sentinel — they don't reference Codex)
- Adding OpenSpec-specific language
- `quick-fix-workflow` (already skips companion review)

**Design References:** N/A (non-UI task)

**Note:** If `source-agnostic-workflow` Task 3 has already landed, coordinate with its CLAUDE.md and execution-core changes to avoid conflicts.

## Reference

- `claude/CLAUDE.md` — Current Wizard communication rules and `party-cli transport` references
- `claude/rules/execution-core.md` — Canonical sequence mentioning "codex"
- `claude/skills/task-workflow/SKILL.md` — Transport dispatch references
- `claude/skills/bugfix-workflow/SKILL.md` — Transport dispatch references
- `claude/skills/plan-workflow/SKILL.md` — Transport dispatch references

## Files to Create/Modify

| File | Action |
|------|--------|
| `claude/CLAUDE.md` | Modify — role-based plumbing language |
| `claude/rules/execution-core.md` | Modify — generic companion in sequence |
| `claude/skills/task-workflow/SKILL.md` | Modify — companion transport references |
| `claude/skills/bugfix-workflow/SKILL.md` | Modify — companion transport references |
| `claude/skills/plan-workflow/SKILL.md` | Modify — companion transport references |
| `claude/skills/companion-transport/SKILL.md` | Modify — final consistency pass |
| `codex/AGENTS.md` | Modify — note companion adapter context |

## Requirements

**Functionality:**
- CLAUDE.md persona section: Keep "The Wizard" as the default companion persona. Add a mapping block:
  ```
  ## Your Companions
  - **The Wizard** (analyzer) — code review, planning, investigation
    Default CLI: Codex. Configured via `.party.toml`.
  Dispatch via `party-cli transport --to wizard <mode>`.
  ```
- CLAUDE.md plumbing rules: Replace `party-cli transport review` → `party-cli transport --to wizard review` in examples. Replace "Codex review" → "companion review" in gate descriptions.
- execution-core.md: In the canonical sequence, replace `codex` with `companion`. In the tiered table, replace "codex" evidence with "companion". Keep the non-negotiable rules (no iteration cap, VERDICT: APPROVED required) — they apply to any companion.
- Workflow skills: Replace transport invocation examples with `--to wizard` pattern. Replace "dispatch to Codex" → "dispatch to companion" or "dispatch to The Wizard".
- AGENTS.md: Add brief note at top explaining that Codex operates as a companion within the party harness, and its review conventions (TOON, verdicts) are the standard all companions follow.

**Key gotchas:**
- "The Wizard" is a persona Claude understands from CLAUDE.md. It should NOT be removed — it's how the user naturally refers to the companion. The persona maps to a companion name in the registry.
- Don't over-genericize the prose. "Ask the Wizard to review this" is better UX than "ask the companion with the analyzer role to review this." Keep the flavor, genericize the plumbing.
- Sub-agents (critic, minimizer, scribe, sentinel) don't reference Codex — no changes needed.

## Tests

- CLAUDE.md contains no hardcoded `codex-transport` or `tmux-codex.sh` references
- CLAUDE.md still contains "The Wizard" as persona
- execution-core.md canonical sequence uses "companion" not "codex"
- Workflow SKILL.md files reference `companion-transport` and use `--to wizard`
- AGENTS.md mentions companion role

## Acceptance Criteria

- [ ] CLAUDE.md uses `party-cli transport --to wizard` for all plumbing references
- [ ] CLAUDE.md preserves "The Wizard" persona for natural language interaction
- [ ] execution-core.md sequence and evidence references are companion-generic
- [ ] All workflow skills dispatch via `companion-transport`, not `codex-transport`
- [ ] AGENTS.md contextualizes Codex as a companion implementation
- [ ] No sub-agent files changed
