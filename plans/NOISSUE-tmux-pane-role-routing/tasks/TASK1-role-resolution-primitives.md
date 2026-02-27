# Task 1 — Add Role Resolution Primitives In Shared tmux Library

**Dependencies:** none | **Issue:** NOISSUE

---

## Goal

Add shared, testable helper functions in `session/party-lib.sh` that resolve pane targets from stable role metadata (`@party_role`) and provide an explicit legacy fallback path for pre-change sessions.

## Scope Boundary (REQUIRED)

**In scope:**
- Add role lookup helper(s) in `session/party-lib.sh`.
- Add fallback helper for `claude`/`codex` legacy pane indices.
- Add clear exit behavior when role cannot be resolved.

**Out of scope (handled by other tasks):**
- Changing pane creation order in `party.sh`.
- Updating transport scripts to call new helpers.
- README or user docs.

**Cross-task consistency check:**
- Task 2 must set `@party_role` metadata for panes.
- Task 3 must consume the resolver in both routing directions.

## Reference

- `session/party-lib.sh:170` — existing session discovery entrypoint
- `session/party-lib.sh:226` — existing send helper API that consumes a pane target
- `codex/skills/claude-transport/scripts/tmux-claude.sh:19` — current hardcoded Claude target to replace later
- `claude/skills/codex-transport/scripts/tmux-codex.sh:15` — current hardcoded Codex target to replace later

## Data Transformation Checklist (REQUIRED for shape changes)

Transformation shape here is tmux pane listing text → routing target:
- [x] Source rows identified (`tmux list-panes` format)
- [x] Parsing rules defined (`role` match + target extraction)
- [x] Fallback mapping specified (`claude=>0.0`, `codex=>0.1`)
- [x] Unresolved/error behavior specified

## Files to Create/Modify

| File | Action |
|------|--------|
| `session/party-lib.sh` | Modify |
| `tests/test-party-routing.sh` | Create (or update, if created first) |

## Requirements

**Functionality:**
- Add `party_role_pane_target <session> <role>` helper (exact name may vary, behavior must match DESIGN).
- Add fallback wrapper helper to resolve legacy targets for `claude`/`codex` when role metadata is missing.
- Return non-zero and print actionable error on unresolved role.

**Key gotchas:**
- Do not change `discover_session()` behavior.
- Do not duplicate `tmux_send` logic in new helpers.
- Keep helpers free of side effects beyond lookup.

## Tests

Test cases:
- Role exists and resolves correctly.
- Role missing, legacy fallback available.
- Role missing and no fallback available (error path).

Verification commands:

```bash
bash tests/test-party-routing.sh
```

## Acceptance Criteria

- [ ] Shared resolver helper(s) exist in `party-lib.sh` and are callable from scripts.
- [ ] Resolver behavior matches role-first, fallback-second policy.
- [ ] Routing tests for resolver pass.
