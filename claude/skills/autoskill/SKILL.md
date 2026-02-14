---
name: autoskill
description: Learns from session feedback to extract durable preferences and propose skill updates. Use when the user says "learn from this session", "remember this pattern", or invokes /autoskill.
user-invocable: true
---

# Autoskill

Extract durable preferences and create/update skills from multiple sources.

## Modes

| Mode | Trigger | Source |
|------|---------|--------|
| **Session** | `/autoskill`, "learn from this session" | Current conversation |
| **Document** | `/autoskill [url or path]`, "learn from this doc" | Book, article, codebase |

---

# Mode 1: Session Learning

Session learning operates in two independent lanes, both triggered by the same activation conditions:

| Lane | Focus | Signals |
|------|-------|---------|
| **Lane 1: Preference Signals** | User corrections, patterns, approvals | Existing behavior — extract durable preferences |
| **Lane 2: Flow Violations** | Sequence deviations, illegitimate pauses, stale evidence | Audit whether the session followed autonomous flow correctly |

Both lanes are evaluated on every activation (Lane 2 may be skipped if no workflow detected — see Flow audit scope below). Findings are reported separately in the output.

## When to Activate

Trigger on explicit requests:
- `/autoskill`
- "learn from this session"
- "remember this pattern"

**Do NOT activate** for one-off corrections or declined modifications.

**Flow audit scope:** Lane 2 (Flow Violations) runs only when a workflow was detected via the two-tier predicate in Lane 2 § Workflow Identification (explicit invocation preferred, heuristic fallback with lower confidence). If no workflow detected, Lane 2 is skipped silently — preference signals (Lane 1) still execute normally.

## Lane 1: Preference Signals

### Signal Detection

Scan the current session for feedback signals:

| Signal Type | Value | Examples |
|-------------|-------|----------|
| **Corrections** | Highest | "No, use X instead of Y", "We always do it this way" |
| **Repeated patterns** | High | Same feedback given 2+ times |
| **Approvals** | Supporting | "Yes, that's right", "Perfect" |

**Ignore:**
- Context-specific one-offs
- Ambiguous feedback
- Contradictory signals

### Signal Quality Filter

Before proposing changes, confirm:

1. Was the correction repeated or stated as a general rule?
2. Would it apply to future sessions?
3. Is it specific enough to be actionable?
4. Is it new information beyond standard best practices?

#### Worth Capturing

- Project-specific conventions
- Custom component/file locations
- Team preferences differing from defaults
- Domain-specific terminology
- Architectural decisions
- Stack-specific integrations
- Workflow preferences

#### Not Worth Capturing

- General best practices
- Language/framework conventions
- Common library usage
- Universal security practices
- Standard accessibility guidelines

## Lane 2: Flow Violations

Audit whether the session followed the autonomous flow correctly.

### Workflow Identification

Determine which workflow was active before running any checks. Use a two-tier predicate:

**Tier 1 (authoritative):** Check for explicit workflow skill invocations in the session — scan conversation for `task-workflow`, `bugfix-workflow`, or `plan-workflow` skill calls, or check `~/.claude/logs/skill-trace.jsonl` for entries in the current session.

**Tier 2 (fallback, lower confidence):** Only if Tier 1 finds nothing, use heuristic indicators. Flag any heuristic-detected workflow with a note: "Workflow inferred (not explicitly invoked) — audit findings may be less reliable."

| Indicator | Workflow |
|-----------|----------|
| TASK*.md referenced + implementation code written | task-workflow |
| Bug/error context + regression test written | bugfix-workflow |
| SPEC/DESIGN/PLAN docs created, no implementation | plan-workflow |
| None of the above | **Skip Lane 2** |

If neither tier matches → skip Lane 2 silently (ad-hoc sessions have no flow to audit).

### Expected Sequences

| Step | task | bugfix | plan |
|------|:----:|:------:|:----:|
| /brainstorm | C | -- | C |
| /write-tests | C | M | -- |
| implement | M | M | -- |
| GREEN verification (test-runner) | M | M | -- |
| /plan-workflow | -- | -- | M |
| checkboxes (TASK+PLAN) | M | -- | -- |
| code-critic | M | M | -- |
| codex | M | M | M |
| code-critic rerun (if codex made changes) | C | C | -- |
| /pre-pr-verification | M | M | -- |
| commit + PR | M | M | M |

- `M` = mandatory
- `C` = conditional (required when condition applies — see guard clauses for specifics)
- `--` = not applicable

### Violation Checks

#### Check 1: Step Ordering & Completeness (HIGH confidence)

Verify mandatory steps for the identified workflow executed in correct order.

What to look for:
- Mandatory step missing entirely (e.g., code-critic never invoked)
- Steps executed out of order (e.g., codex before code-critic)
- Checkboxes not updated (task-workflow: both TASK*.md AND PLAN.md)
- GREEN verification missing after implementation

Guard clauses:
- task-workflow: `/brainstorm` conditional — only if requirements unclear (per task-workflow:17 "Requirements unclear?")
- task-workflow: `/write-tests` conditional — only required if task needs tests (per task-workflow:16 "Does task require tests?")
- task-workflow: code-critic rerun conditional — only after codex makes changes (per task-workflow:39)
- bugfix-workflow: code-critic rerun conditional — only after codex makes changes (per bugfix-workflow:43)
- bugfix-workflow: no PLAN.md checkbox requirement (per bugfix-workflow:34)
- plan-workflow: `/brainstorm` conditional — only if requirements unclear (per plan-workflow:19)
- plan-workflow: no code-critic, test-runner, check-runner, or /pre-pr-verification required

Guard clause — valid terminal states:
- If session ends at any legitimate pause point, stop completeness checking at that step. Do NOT flag downstream missing steps as violations — the flow was correctly paused, not abandoned.
- Legitimate pause points: NEEDS_DISCUSSION verdict, 3-strikes, investigation findings (codex debugging/gemini), explicit blockers, HIGH/CRITICAL security findings (execution-core.md:32), plan-workflow "wait for user review" (plan-workflow:47), brainstorm pause (plan-workflow:19), user-initiated pause or question.

Enforcement note: pr-gate.sh already catches missing markers at PR creation time. This check adds value by catching violations that don't reach PR stage (flow abandoned mid-session without valid pause) and by detecting ordering violations (which markers can't capture).

#### Check 2: Illegitimate Pauses (MED-HIGH confidence)

Detect **assistant-initiated** pauses outside valid pause conditions. Only flag when the assistant (not user) stopped the flow.

Violation signals (assistant-initiated only):
- "Should I continue?" / "Shall I proceed?"
- "Would you like me to..."
- "Ready to create PR." (without actually creating it)
- "Tests pass. GREEN phase complete." [stop] (didn't continue to checkboxes/critics)
- "Code-critic approved." [stop] (didn't continue to codex)
- "All checks pass." [stop] (didn't continue to commit/PR)
- Any assistant question to user between consecutive mandatory steps without a valid reason

Guard clauses — legitimate pauses:
- Investigation findings: codex agent (debugging task) and gemini agent always require user review (bugfix-workflow:17-18, 22)
- NEEDS_DISCUSSION verdict from code-critic or codex (execution-core.md)
- Three failed fix attempts on same issue (execution-core.md)
- Explicit blockers: missing dependencies, unclear requirements
- HIGH/CRITICAL security findings require user approval (execution-core.md:32)
- Brainstorm pause in plan-workflow (plan-workflow:19) or task-workflow (task-workflow:17)
- Plan-workflow "wait for user review" after planning phase completes (plan-workflow:47)
- User explicitly requested a pause or asked a question

Confidence: HIGH if assistant clearly stopped between two mandatory steps with no valid reason; MED if lexical match only (could be quoting violation patterns or in investigation context).

Note: The legitimate pause list above extends execution-core.md:41-45 with workflow-specific pauses documented in each workflow's SKILL.md. The core list is authoritative; workflow-specific pauses are additive.

Enforcement note: not caught by pr-gate.sh — this is unique value from the audit.

#### Check 3: Evidence Freshness (MED-HIGH confidence)

Verify that verification claims are backed by evidence that hasn't been invalidated.

**Core rule:** Any code edit after a verification step invalidates that verification. Re-verification is mandatory before claims can be made. (Per execution-core.md:59-69 (verification principle) and autonomous-flow.md:88 (post-PR case))

What to look for:
- "Tests pass" without test-runner invocation after the latest code change
- "All checks pass" referencing output from before the latest code modification
- `/pre-pr-verification` passed but code was edited afterward without re-running
- Tentative language used as verification claim: "should work", "should be fine", "I believe this passes"

Guard clauses:
- Verification is fresh if the relevant agent ran AFTER the last code edit in the session
- Freshness is scoped by evidence type:
  - `test-runner` → test evidence
  - `check-runner` → lint/type evidence
  - `code-critic` → style evidence
  - `/pre-pr-verification` → composite evidence (test + lint + security, since it runs test-runner + check-runner + security-scanner internally)
  - `security-scanner` → security evidence
  - A code-critic rerun does NOT freshen test, lint, or security evidence
- Tentative language in casual explanation or investigation context (not a verification claim) is not a violation

Confidence: HIGH if claim made with no evidence at all, or verification clearly predates code changes; MED if evidence exists but temporal ordering is ambiguous; LOW for tentative language alone (lexical heuristic — report-only, never propose edits).

Enforcement note: pr-gate.sh checks marker existence but not temporal validity. This check catches mid-session staleness (e.g., "tests pass" after modifying code but before re-running tests) and post-verification edits before PR creation.

### Routing Triage

When a flow violation warrants a durable fix, classify to determine target:

| Violation Class | Example | Target File |
|-----------------|---------|-------------|
| Behavior drift | Agent skipped code-critic | Workflow skill SKILL.md |
| Rule ambiguity | Unclear when pausing is legitimate | autonomous-flow.md or execution-core.md |
| Enforcement gap | Hook should have caught this but didn't | Hook file (agent-trace.sh, pr-gate.sh, skill-marker.sh) |

**Scope limitation:** Lane 2 does NOT re-check what pr-gate.sh already enforces (marker presence). Focus on sequence ordering, evidence freshness, and pause legitimacy — the gaps that markers can't capture.

### Edge Cases

| Scenario | Handling |
|----------|----------|
| Task-workflow without TASK*.md file | Route as enforcement gap — workflow precondition validation should prevent this |
| Bugfix where no bug found | Valid terminal state — codex investigation concluded, not a violation |
| Plan-workflow with 3x codex failures | Log as recurring pattern; valid pause (3-strikes rule) |
| Post-verification edit before PR | Freshness violation (HIGH) — re-verification mandatory |
| Session with multiple workflows | Audit each workflow segment independently; produce separate Flow Adherence Report per segment |

---

# Mode 2: Document Learning

## When to Activate

Trigger on:
- `/autoskill [url]` or `/autoskill [file path]`
- "learn from this book/article/doc"
- "extract skills from [source]"

## Process

1. **Read the source** — Fetch URL or read file(s)
2. **Extract techniques** — Identify patterns, methodologies, principles not already in your skills
3. **Filter for novelty** — Skip what you already know or is standard practice
4. **Propose skills** — Either updates to existing skills OR new skill creation

## What to Extract

- Methodologies (e.g., debugging approaches, testing strategies)
- Workflows (e.g., review processes, deployment patterns)
- Principles with concrete rules (e.g., "always X before Y")
- Red flags / anti-patterns with alternatives

## What to Skip

- General advice without actionable rules
- Content already covered by existing skills
- Context-specific examples that don't generalize
- Opinion without methodology

---

# Creating New Skills (TDD Approach)

When signals suggest a new skill (3+ related signals not fitting existing skills), use test-driven skill development.

## The Process

### 1. RED — Document the Failure

Before writing the skill, identify what goes wrong without it:

```markdown
## Skill Gap: [name]

**Problem observed:**
- [What happened without this skill]
- [Specific failure or suboptimal behavior]

**Desired behavior:**
- [What should happen instead]
```

### 2. GREEN — Write Minimal Skill

Create `~/.claude/skills/<skill-name>/SKILL.md` addressing **only** the documented failures.

```yaml
---
name: [skill-name]
description: [triggering conditions only — when to use, not what it does]
user-invocable: [true if callable via /skill-name]
---
```

Skill content should be minimal — just enough to fix the observed problem.

### 3. REFACTOR — Test and Iterate

After creating the skill:
1. Consider: "How might I rationalize ignoring this skill?"
2. Add rules to close those loopholes
3. Keep the skill focused — resist scope creep

## Skill Structure

```markdown
# [Skill Name]

[One sentence: what this skill does]

## When to Use
[Triggering conditions]

## Workflow / Process
[Steps or phases]

## Key Rules
[Non-negotiable constraints]

## Output Format (if applicable)
[Expected deliverable structure]
```

---

# Mapping Signals to Locations

## Skill Locations

- Skills: `~/.claude/skills/<skill-name>/SKILL.md`
- Reference docs: `~/.claude/skills/<skill-name>/reference/`
- Sub-agents: `~/.claude/agents/<agent-name>.md`
- Rules: `~/.claude/rules/<category>.md`
- Global config: `~/.claude/CLAUDE.md`

## Decision Tree

```
Signal about...
├── Workflow/process → Skill
├── Agent declarative (boundaries, capabilities) → Agent definition (agents/*.md)
├── Agent procedural (CLI, output format, mode detection) → Agent skill (skills/*-cli/SKILL.md)
├── Code style/patterns → Rules
├── Global preferences → CLAUDE.md
├── Flow violation (behavior drift) → Workflow skill file
├── Flow violation (rule ambiguity) → autonomous-flow.md or execution-core.md
├── Flow violation (enforcement gap) → Hook file (agent-trace.sh, pr-gate.sh, skill-marker.sh)
└── Doesn't fit → Consider new skill (TDD)
```

**Note:** The agent declarative/procedural split anticipates the upcoming agent-skill separation refactor (see `doc/projects/agent-skill-separation/`). Before that refactor, both targets resolve to the same monolithic agent file.

---

# Output Format

```markdown
## Autoskill: [session name / document title]

### Signals

| #  | Type       | Quote/Context              |
|----|------------|----------------------------|
| 1  | Correction | "No, use X instead of Y"   |
| 2  | Process    | "We always do it this way" |

**Detected:** 2 updates, 0 new skills, 1 flow violation

### Proposed Updates

#### ▸ [1] SKILL-NAME — `HIGH`

**Signal:** "exact quote or paraphrase"
**File:** `~/.claude/skills/skill-name/SKILL.md`
**Section:** Section name or "new section"

**Current:**
> existing text, if modifying

**Proposed:**
> new or replacement text

**Rationale:** One sentence explanation.

> |

#### ▸ [2] SKILL-NAME — `MED`

**Signal:** "another quote"
**File:** `~/.claude/rules/category.md`
**Section:** New section

**Proposed:**
> new text (no current if adding new)

**Rationale:** One sentence explanation.

### Flow Adherence Report

**Workflow(s) detected:** {task-workflow | bugfix-workflow | plan-workflow | none (skipped)}
(If multiple workflows in one session, produce a separate report per workflow segment.)

| # | Check | Verdict | Confidence |
|---|-------|---------|------------|
| 1 | Step ordering & completeness | {PASS / VIOLATION: details} | {HIGH/MED} |
| 2 | Illegitimate pauses | {PASS / VIOLATION: details} | {HIGH/MED} |
| 3 | Evidence freshness | {PASS / VIOLATION: details} | {HIGH/MED/LOW} |

**Violations found:** {N}

(For each violation warranting a durable fix:)

#### ▸ Flow [1] — {target-file} — `{confidence}`

**Violation:** {description}
**Root cause:** {behavior drift | rule ambiguity | enforcement gap}
**File:** `{exact target path}`
**Proposed:** > {change to prevent recurrence}
**Rationale:** One sentence.

(LOW confidence violations: report-only, no proposed edits.)
(If no violations: "Flow adherence: CLEAN")


**Apply changes?** [all / high-only / selective / none]
```

## Confidence Levels

- **HIGH** — Explicit rule stated, repeated 2+ times, or clearly generalizable. For flow: explicit step skipped or sequence broken.
- **MED** — Single instance but appears intentional, or slightly ambiguous scope. For flow: pattern heuristic (stale evidence via timing, ambiguous pause).
- **LOW** — Lexical match only, likely false positive. For flow: tentative language detected without concrete evidence of skipped steps. **Report-only — never propose edits at LOW confidence.** Always downgrade when a guard clause partially applies.

Always wait for explicit approval before editing.

---

# Applying Changes

On approval:

1. Make minimal, focused edits
2. One concept per change (easier to revert)
3. Preserve existing file structure and tone
4. **Check related files:** Update templates, reference docs, and examples in the skill folder to match new guidelines
5. If git available, commit: `chore(autoskill): [description]`
6. Report changes made

---

# Constraints

- **Never delete** existing rules without explicit instruction
- **Prefer additive changes** over rewrites
- **Downgrade to MEDIUM** when uncertain about scope
- **Skip** if no actionable signals detected
- **New skills require RED phase** — Document the gap before writing
