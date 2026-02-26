# TOON Handoff Migration Plan

## Goal
Migrate Codex↔Claude tmux handoff findings from JSON/markdown to TOON for both code-review and plan-review workflows, while preserving shell-consumed JSON artifacts that must remain JSON.

## In Scope
- Codex tmux-handler review findings format: JSON -> TOON
- Codex tmux-handler plan-review findings format: JSON -> TOON
- Claude tmux-handler guidance updated to consume TOON findings
- Claude outbound structured review/plan-review responses to Codex: markdown tables -> TOON findings schema
- `tmux-codex.sh` review findings extension change: `.json` -> `.toon`
- `tmux-codex.sh` plan-review transport path to produce `.toon` findings files (not `.md`)
- `tmux-codex.sh --review-complete` file existence checks compatible with `.toon`
- Hook interaction rules for `--plan-review` to keep approval evidence chain correct
- Prompt-template alignment so no competing markdown findings format remains
- Tests and docs updated for `.toon` findings conventions

## Out of Scope
- `agent-trace.jsonl`
- `~/.party-state/*.json`
- Claude Code hook JSON protocol payloads
- settings files requiring JSON

## Source Constraints
- TOON spec: https://github.com/toon-format/spec/blob/main/SPEC.md
- TOON LLM prompting guidance: https://toonformat.dev/guide/llm-prompts
- TOON repo guidance: https://github.com/toon-format/toon?tab=readme-ov-file#using-toon-with-llms

## Current-State Evidence
- `codex/skills/tmux-handler/SKILL.md` mandates findings JSON format for review and plan review.
- `claude/skills/tmux-handler/SKILL.md` reads findings but has no TOON-specific instructions.
- `claude/skills/codex-transport/scripts/tmux-codex.sh` creates `codex-findings-*.json` in `--review`, but `--prompt` emits `.md` response files.
- `codex/skills/claude-transport/references/prompt-templates.md` plan-review template requires markdown findings plus verdict, conflicting with tmux-handler findings model.
- `tests/test-hooks.sh` uses `.json` findings paths in trace tests.

## Canonical Findings TOON Schema

```toon
findings[N]{id,file,line,severity,category,description,suggestion}:
  F1,path/to/file.ts,42,blocking,correctness,"Description here","Suggestion here"
summary: One paragraph summary
stats:
  blocking_count: 0
  non_blocking_count: 0
  files_reviewed: 0
```

## TOON Rules To Encode in Skills
- Field order is fixed: `id,file,line,severity,category,description,suggestion`.
- `line` MUST be an unquoted integer.
- `description` and `suggestion` MUST be quoted when they contain delimiter-sensitive characters (commas, colons, quotes, backslashes, control chars).
- Quoted strings MUST use valid TOON escaping (`\\`, `\"`, `\n`, `\r`, `\t`).
- `findings[N]` MUST equal actual row count.
- `stats` remains nested key-value object.

## Transport Direction Contract (must be documented in both handlers)

| Agent calling | Script to use | Direction |
|---|---|---|
| Claude | `tmux-codex.sh` | Claude -> Codex |
| Codex | `tmux-claude.sh` | Codex -> Claude |

## Implementation Tasks

### Task 0: Audit all findings-format touchpoints (required pre-step)
Commands:
- `rg -n "findings|JSON format|codex-findings|review-complete|Plan review|Question from Codex|Response ready|--plan-review|\\.md\\b|\\.json\\b" codex claude tests session shared -S`

Output:
- Enumerated file list of every instruction/script/test mentioning findings format or `.json` findings naming.

Acceptance checks:
- Audit output captured in plan PR description.
- No touched path is outside explicit scope without rationale.

### Task 1: Update Codex tmux-handler skill to TOON
Files:
- `codex/skills/tmux-handler/SKILL.md`

Changes:
- Replace review findings JSON example with TOON example.
- Replace plan-review "same findings JSON format" wording with TOON schema requirement.
- Add outbound request rule: when Codex requests structured findings from Claude, Codex must provide `.toon` response path and expected TOON findings schema.
- Add quoting/escaping cautions for `description` and `suggestion`.
- Add explicit numeric rule for `line` (unquoted integer).
- Add TOON reference links (spec + LLM prompt guide).
- Add concise generation guardrails (show small example, enforce `[N]` count, fenced `toon` block).
- Add a short transport-direction table matching the contract above.

Acceptance checks:
- Skill no longer instructs JSON for findings output.
- Review and plan-review sections both point to identical TOON schema.
- Structured outbound responses from Codex request `.toon` paths when findings are expected.

### Task 2: Update Claude tmux-handler skill to consume and emit TOON + fallback
Files:
- `claude/skills/tmux-handler/SKILL.md`

Changes:
- Explicitly state findings files are TOON.
- In `Question from Codex`, add output rule:
  - when Codex requests structured findings, Claude MUST emit TOON with canonical schema (not markdown table).
  - when request is narrative Q&A, Claude may emit concise text format.
- Clarify path ownership: Claude writes TOON to the exact response path Codex provided; Claude does not change extension.
- Add triage checklist:
  - validate header + field list
  - verify `[N]` equals row count
  - read `summary` and `stats`
- Add failure handling for malformed TOON:
  - record validation issue
  - request re-emit from Codex OR triage manually as plain text if urgent
- Add TOON references (spec + LLM prompt guide).
- Add a short transport-direction table matching the contract above.

Acceptance checks:
- Skill is explicit about TOON for both review-complete and plan-review-complete.
- Skill is explicit about TOON for Claude outbound structured findings responses to Codex.
- Rule is explicit that Codex (requester) controls `.toon` extension for structured responses.
- Fallback path for malformed TOON is documented.

### Task 3: Transport script changes for both review types
Files:
- `claude/skills/codex-transport/scripts/tmux-codex.sh`

Changes:
- `--review`: change `codex-findings-*.json` -> `codex-findings-*.toon`.
- Add explicit `--plan-review` mode that generates `codex-plan-findings-*.toon` and sends a plan-review request message to Codex that expects TOON findings output.
- Keep `--prompt` for general tasks; do not overload plan-review onto `.md` responses.
- Keep `--review-complete` existence gate authoritative and extension-agnostic (works with `.toon`).
- Add hook-interaction spec for `--plan-review`:
  - `codex-gate.sh`: intentionally ungated by critic markers (plan review is advisory, not code-merge evidence).
  - Evidence chain: `--plan-review` completion MUST NOT create or reuse `codex-ran` marker used by `--approve` gate.
  - Notification template: plan review must notify with `Plan review complete. Findings at: <path>` so Claude routes to plan-review triage path.

Acceptance checks:
- `--review` prints `.toon` path.
- `--plan-review` prints `.toon` path.
- `--review-complete <existing .toon file>` returns `CODEX_REVIEW_RAN`.
- Plan-review completion does not unlock `--approve` via `codex-ran` side effects.

### Task 4: Align templates and docs to remove format conflicts
Files:
- `codex/skills/claude-transport/references/prompt-templates.md`
- `claude/skills/codex-transport/SKILL.md`
- `claude/CLAUDE.md` (G1)
- `claude/skills/task-workflow/SKILL.md` (G2)
- `codex/skills/claude-transport/SKILL.md` (G4)
- Any additional files found in Task 0 audit that still prescribe JSON/markdown findings for this flow

Changes:
- Update plan-review prompt template to require TOON findings schema (no verdict field from Codex).
- Ensure transport skill examples/documentation reflect `.toon` findings conventions and explicit `--plan-review` mode semantics (G3).
- Fix `claude/CLAUDE.md` plan-dispatch command to use `tmux-codex.sh --plan-review` (G1).
- Update `claude/skills/task-workflow/SKILL.md` mode list and dispatch guidance to include `--plan-review` (G2).
- Add explicit plan-review completion notification template to `codex/skills/claude-transport/SKILL.md` (`Plan review complete. Findings at: <path>`) (G4).

Acceptance checks:
- No conflicting markdown or JSON findings instructions remain for Codex plan/code review findings handoffs.
- G1-G4 documentation gaps are closed in the listed files (not merely audit-detected).

### Task 5: Tests and verification coverage
Files:
- `tests/test-hooks.sh`
- Additional test helpers if needed

Changes:
- Replace `/tmp/f.json` with `/tmp/f.toon` in review-complete trace fixtures.
- Add a lightweight TOON-format sanity check fixture for findings shape validation (header fields + row count consistency), implemented without changing hook JSON protocol.
- Add explicit hook test that `--plan-review` is intentionally ungated by critic markers and does not create/reuse `codex-ran` approval marker (G5).

Acceptance checks:
- `bash tests/run-tests.sh` passes.
- New sanity check fails on row-count mismatch and passes on valid sample.
- Hook test fails if `--plan-review` becomes gated or mutates approval marker behavior.

## Sequencing and Delivery Constraint
Tasks 1-4 must land atomically in one PR/merge unit to avoid transient mismatch states (TOON in `.json`, JSON in `.toon`, or markdown-vs-TOON instruction conflicts).

## Risks and Mitigations
- Risk: Comma-heavy descriptions produce malformed rows.
  - Mitigation: mandatory quoting guidance + explicit escape rules in both handlers.
- Risk: `[N]` row-count mismatch.
  - Mitigation: producer instructions + consumer validation checklist + sanity test.
- Risk: residual conflicting guidance in templates/docs.
  - Mitigation: Task 0 audit + Task 4 conflict cleanup.
- Risk: malformed TOON stalls triage.
  - Mitigation: explicit fallback path in Claude tmux-handler (re-emit or manual triage).

## Verification Plan
1. Static/doc verification:
   - `rg -n "JSON format|same findings JSON|codex-findings-.*json|\\.json\\b|--prompt.*plan|--plan-review|Plan review complete\\. Findings at:" codex claude tests shared -S`
   - Confirm findings-handoff guidance now points to TOON where intended.
2. Test suite:
   - `bash tests/run-tests.sh`
3. Manual party E2E (code review):
   - Start party session.
   - Make a small change in a test worktree.
   - Trigger review via `tmux-codex.sh --review ...`.
   - Confirm generated findings file ends with `.toon` and content follows schema.
   - Confirm Claude triages and can proceed through `--review-complete` + verdict flow.
4. Manual party E2E (plan review):
   - Trigger plan review via new `tmux-codex.sh --plan-review ...` mode.
   - Confirm plan findings land in `.toon` with canonical schema.
   - Confirm Claude triages with same TOON rules.
   - Confirm plan-review completion does not create `/tmp/claude-codex-ran-<session_id>`.
5. Manual party E2E (Claude -> Codex structured response):
   - Have Codex ask Claude for structured findings output and provide a `.toon` response path.
   - Confirm response follows canonical TOON findings schema at that exact provided path.
   - Confirm Codex consumes it without markdown parsing fallback.

## Done Criteria
- All in-scope files updated and internally consistent.
- No contradictory markdown/JSON findings instructions remain for Codex findings handoffs.
- Tests pass.
- Both manual E2E flows (code review + plan review) succeed with TOON findings.
- Out-of-scope JSON artifacts remain unchanged.
