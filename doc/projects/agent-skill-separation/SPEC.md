# Agent-Skill Separation Specification

## Problem Statement

Current agents (codex.md, gemini.md) mix declarative "what" with procedural "how":
- **codex.md**: 157 lines — CLI commands, bash rules, cleanup protocols embedded
- **gemini.md**: 375 lines — Mode detection, CLI resolution, error handling embedded

This violates separation of concerns and makes agents hard to maintain.

## Goal

Separate agent definitions into:
- **Agents** = Declarative (what capabilities, when to invoke, boundaries)
- **Skills** = Procedural (CLI details, bash commands, prompts, output formats)

Use the `skills:` frontmatter field to preload procedural content into agents at startup.

## Requirements

### Functional

1. **Codex agent** references `codex-cli` skill for procedural content
2. **Gemini agent** references `gemini-cli` skill for procedural content
3. Skills contain all CLI invocation details, error handling, output formats
4. Agents remain thin (~20-30 lines) with clear capability descriptions
5. Behavior remains identical after refactor

### Non-Functional

1. Skills are `user-invocable: false` (internal use only)
2. No duplication between agent and skill content
3. Clear separation: agent says "what to do", skill says "how to do it"

## Acceptance Criteria

- [x] codex.md reduced to <40 lines (37 lines, declarative only)
- [x] gemini.md reduced to <40 lines (32 lines, declarative only)
- [x] codex-cli/SKILL.md contains all CLI procedures (138 lines)
- [x] gemini-cli/SKILL.md contains all CLI procedures (361 lines)
- [x] Both agents use `skills:` field to preload their respective skill
- [ ] Existing workflows (plan-workflow, task-workflow) work unchanged
- [x] Codex agent still returns structured verdicts (APPROVE/REQUEST_CHANGES)
- [x] Gemini agent still handles log analysis and web search modes

## Out of Scope

- Other agents (test-runner, check-runner, code-critic, security-scanner)
- Changing CLI tool behavior (codex, gemini CLIs themselves)
- Modifying workflows that invoke these agents
