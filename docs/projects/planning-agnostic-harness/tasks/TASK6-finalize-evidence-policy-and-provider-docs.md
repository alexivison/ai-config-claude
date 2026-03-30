# Task 6 - Finalize Evidence Policy And Provider Docs

**Dependencies:** Task 5 | **Issue:** TBD

---

## Goal

Close the remaining policy and documentation gaps after the simplified provider model works. This task makes provider-owned planning-file evidence behavior explicit and updates workflow docs so the harness is described as a planning-agnostic execution engine whose contract is only scope, requirements, and goal.

## Scope Boundary (REQUIRED)

**In scope:**
- Decide and codify evidence policy for provider-owned planning files
- Extend regression tests for provider-owned planning-only changes and mixed code-plus-planning changes
- Update workflow docs so plan-workflow, bugfix, and quick-fix guidance speak in provider terms
- Document the minimal provider contract: `scope`, `requirements`, and `goal`
- Document that any provider-side human-readable state sync is optional and ungated

**Out of scope (handled by other tasks):**
- Reworking the core execution sequence
- Adding more providers
- Rewriting OpenSpec or classic provider behavior

**Cross-task consistency check:**
- Evidence-policy changes must not weaken PR-gate behavior for code changes
- Final docs must preserve Task 1's minimal provider contract and Task 2's engine framing

## Reference

Files to study before implementing:

- `claude/hooks/lib/evidence.sh:99` - current Markdown exclusion policy
- `claude/hooks/pr-gate.sh:33` - current docs-only PR bypass
- `claude/skills/plan-workflow/SKILL.md:59` - current classic-only planning output language
- `claude/skills/bugfix-workflow/SKILL.md:18` - current bugfix routing assumptions
- `claude/skills/quick-fix-workflow/SKILL.md:27` - current non-feature shortcut rules

## Design References (REQUIRED for UI/component tasks)

N/A (non-UI task)

## Data Transformation Checklist (REQUIRED for shape changes)

- [ ] Proto definition (N/A)
- [ ] Proto -> Domain converter (N/A)
- [ ] Domain model struct for provider-owned planning-file policy, if introduced
- [ ] Params struct(s) for evidence-policy toggles or provider docs
- [ ] Params conversion functions from planning-file diffs to evidence-hash policy
- [ ] Any adapters between provider docs and workflow invocation guidance

## Files to Create/Modify

| File | Action |
|------|--------|
| `claude/hooks/lib/evidence.sh` | Modify |
| `claude/hooks/tests/test-evidence.sh` | Modify |
| `claude/hooks/tests/test-pr-gate.sh` | Modify |
| `claude/hooks/tests/test-provider-routing.sh` | Modify |
| `claude/skills/plan-workflow/SKILL.md` | Modify |
| `claude/skills/bugfix-workflow/SKILL.md` | Modify |
| `claude/skills/quick-fix-workflow/SKILL.md` | Modify |

## Requirements

**Functionality:**
- The harness has an explicit yes/no rule for whether provider-owned planning-file edits affect diff-hash gating
- Docs explain that plan-workflow produces classic provider inputs, not the engine's only valid planning format
- Docs explain what a new provider must supply: `scope`, `requirements`, and `goal`
- Docs explain that provider-side human-readable status sync is optional and ungated
- Regression tests cover planning-only provider-file changes and mixed code-plus-provider changes

**Key gotchas:**
- Do not let evidence policy silently change longstanding PR-gate behavior
- Do not let provider docs grow into a second planning schema beyond the minimal contract

## Tests

Test cases:
- Planning-only provider-file changes behave exactly as the chosen evidence policy says they should
- Mixed code + provider-file edits still require the normal full evidence spine
- Workflow docs describe classic/OpenSpec/future-provider responsibilities without TASK-native engine language
- Docs clarify that checkbox/state sync is provider-side optional behavior, not engine evidence

Verification commands:
- `bash claude/hooks/tests/test-evidence.sh`
- `bash claude/hooks/tests/test-pr-gate.sh`
- `bash claude/hooks/tests/test-provider-routing.sh`

## Acceptance Criteria

- [ ] Provider-owned planning-file evidence policy is explicit and regression-tested
- [ ] Workflow docs describe the harness as provider-based rather than TASK-native
- [ ] New providers have a documented minimal contract to implement
- [ ] Provider-side human-readable status sync is documented as optional and ungated
