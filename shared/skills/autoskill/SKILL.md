---
name: autoskill
description: Learns from session feedback to extract durable preferences and propose skill updates. Use when the user says "learn from this session", "remember this pattern", or invokes /autoskill.
user-invocable: true
---

# Autoskill

Extract durable preferences and create/update skills from session feedback or documents.

## Modes

- **Session** (`/autoskill`) — Learn from current conversation
- **Document** (`/autoskill [url|path]`) — Learn from external source

---

# Session Learning

Two lanes run on every activation:

1. **Preferences** — User corrections, repeated patterns, approvals → durable rules
2. **Flow Audit** — Sequence deviations, illegitimate pauses, stale evidence (only when workflow detected)

## Lane 1: Preferences

**Signal priority:** Corrections (highest) > Repeated patterns > Approvals (supporting)

Ignore one-offs, ambiguous, or contradictory signals.

**Capture when:** repeated or stated as general rule, applies to future sessions, specific and actionable, new beyond standard practices. Think project conventions, architectural decisions, workflow preferences.

**Skip:** General best practices, language/framework conventions, common library usage.

## Lane 2: Flow Audit

**Detect workflow:** Explicit skill invocation (authoritative) or heuristic — TASK*.md = task-workflow, bug + regression = bugfix-workflow (flag "inferred").

**Expected sequence** (M=mandatory, C=conditional):

```
/write-tests(C|M) → implement → GREEN → checkboxes(task only) → critics → codex → /pre-pr-verification → commit+PR
```

**Checks:**
1. **Step ordering** (HIGH) — Mandatory steps in order. Legitimate pauses (NEEDS_DISCUSSION, 2-strike cap, user-initiated) are valid terminals.
2. **Illegitimate pauses** (MED-HIGH) — "Should I continue?", stopping after partial completion without valid reason.
3. **Evidence freshness** (MED-HIGH) — Code edits after verification invalidate it. No tentative language as proof.

**Route violations to:** behavior drift → workflow SKILL.md, rule ambiguity → execution-core.md, enforcement gap → hook file.

---

# Document Learning

1. Read source → 2. Extract novel techniques/principles → 3. Propose skill updates or new skills

---

# Signal Routing

```
Signal about...
├── Workflow/process    → Skill
├── Agent behavior      → Agent definition or agent skill
├── Code style          → Rules
├── Global preferences  → CLAUDE.md
├── Flow violation      → Workflow skill / rule / hook
└── Doesn't fit (3+)   → New skill (TDD via skill-creator)
```

---

# New Skills (TDD)

3+ related signals not fitting existing skills → new skill per `skill-creator`.

1. **RED** — Document gap (problem, desired behavior)
2. **GREEN** — Minimal skill at `~/.<agent>/skills/<name>/SKILL.md` (shared: `shared/skills/` + symlinks)
3. **REFACTOR** — Close loopholes, run verification checklist

---

# Output Format

```
## Autoskill: [title]

### Signals
| # | Signal | Context |
|---|--------|---------|

Detected: N updates, N new skills, N violations

### Proposed Updates
▸ [1] SKILL-NAME — HIGH
  Signal: "quote"
  File: path
  Current: > existing
  Proposed: > new
  Rationale: one sentence

### Flow Report (if workflow detected)
| # | Check | Verdict | Confidence |
|---|-------|---------|------------|

Apply? [all / high-only / selective / none]
```

**Confidence:** HIGH (explicit/repeated) · MED (single, intentional) · LOW (lexical only — report, never edit)

---

# Constraints

- Never delete rules without instruction
- Prefer additive changes over rewrites
- Skip if no actionable signals
- Always wait for explicit approval before editing
