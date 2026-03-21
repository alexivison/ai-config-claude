# Task 1 — Prune Dead Code And Docs Debt

**Dependencies:** none | **Issue:** TBD

---

## Goal

Remove the low-value debris left by recent rapid development so later migration work doth not preserve dead branches by accident. This task is deliberately small and should be a quick-fix candidate if the final diff stays tight.

## Scope Boundary (REQUIRED)

**In scope:**
- Remove dead marker cleanup from `claude/hooks/session-cleanup.sh`
- Remove obsolete backward-compat positional handling from `claude/skills/codex-transport/scripts/tmux-codex.sh`
- Merge `claude/rules/general.md` into `claude/CLAUDE.md` and delete the redundant file
- Clean stale completed task metadata under `claude/tasks/` if confirmed inert

**Out of scope (handled by other tasks):**
- `jq` checks, tmux-send diagnostics, or routing changes
- Hook-library extraction and new hook tests
- Any Go or TUI work

**Cross-task consistency check:**
- This task may delete dead compatibility seams, but it must not remove behavior later tasks still need for `tmux-codex.sh`
- If stale task metadata is removed, no later task should rely on those files as runtime state

## Reference

Files to study before implementing:

- `claude/hooks/session-cleanup.sh` — dead transition cleanup to remove
- `claude/skills/codex-transport/scripts/tmux-codex.sh` — obsolete positional-arg handling
- `claude/CLAUDE.md` — destination for merged general guidance
- `claude/rules/general.md` — too-thin source content to fold in

## Design References (REQUIRED for UI/component tasks)

N/A (non-UI task)

## Data Transformation Checklist (REQUIRED for shape changes)

N/A (no persisted or public shape change in this task)

## Files to Create/Modify

| File | Action |
|------|--------|
| `claude/hooks/session-cleanup.sh` | Modify |
| `claude/skills/codex-transport/scripts/tmux-codex.sh` | Modify |
| `claude/CLAUDE.md` | Modify |
| `claude/rules/general.md` | Delete |
| `claude/tasks/*` | Modify or delete stale completed metadata if confirmed unused |

## Requirements

**Functionality:**
- Remove only code and docs paths that are provably dead or superseded
- Preserve current `tmux-codex.sh` command semantics aside from the obsolete positional form
- Keep the resulting style guidance discoverable in one canonical place

**Key gotchas:**
- Do not delete any `claude/tasks/` entry still referenced by active tooling or scripts
- Keep file deletions narrow so this stays quick-fix eligible if possible

## Tests

Test cases:
- Run the relevant hook and transport script help or smoke paths after cleanup
- Confirm no references remain to `claude/rules/general.md`
- Confirm stale task metadata removals do not break task discovery commands, if any exist

## Acceptance Criteria

- [ ] Dead transition cleanup is removed from `session-cleanup.sh`
- [ ] `tmux-codex.sh` no longer accepts or depends on the obsolete positional compatibility path
- [ ] `general.md` content lives in `claude/CLAUDE.md` and the redundant file is removed
- [ ] Any stale completed task metadata removed by this task is verified to be non-runtime
- [ ] Relevant smoke tests pass
