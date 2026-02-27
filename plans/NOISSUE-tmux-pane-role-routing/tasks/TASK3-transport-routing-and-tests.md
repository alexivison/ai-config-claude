# Task 3 — Migrate Transport Scripts To Role-Based Routing And Add Tests

**Dependencies:** Task 1, Task 2 | **Issue:** NOISSUE

---

## Goal

Replace hardcoded pane targets in both transport scripts with shared role-based lookup, then add automated tests that lock in this behavior and legacy fallback semantics.

## Scope Boundary (REQUIRED)

**In scope:**
- Modify `tmux-codex.sh` and `tmux-claude.sh` to resolve pane targets via shared helper(s).
- Keep transport message payloads and sentinel outputs unchanged.
- Add/extend shell tests for role-first routing and fallback behavior.
- Wire new tests into `tests/run-tests.sh`.

**Out of scope (handled by other tasks):**
- Changing launcher pane layout logic.
- Documentation text updates.

**Cross-task consistency check:**
- Scripts must use the same role tokens created by Task 2 and resolved by Task 1.

## Reference

- `claude/skills/codex-transport/scripts/tmux-codex.sh:13` — current `_require_session` hookpoint
- `claude/skills/codex-transport/scripts/tmux-codex.sh:15` — current hardcoded `0.1`
- `codex/skills/claude-transport/scripts/tmux-claude.sh:19` — current hardcoded `0.0`
- `session/party-lib.sh:226` — existing `tmux_send` API to keep
- `tests/run-tests.sh:28` — main test suite registration point

## Data Transformation Checklist (REQUIRED for shape changes)

Transformation shape here is role token → tmux target:
- [x] `codex` role maps to runtime pane target
- [x] `claude` role maps to runtime pane target
- [x] Fallback path tested for sessions lacking metadata
- [x] Error path tested for unresolved routing

## Files to Create/Modify

| File | Action |
|------|--------|
| `claude/skills/codex-transport/scripts/tmux-codex.sh` | Modify |
| `codex/skills/claude-transport/scripts/tmux-claude.sh` | Modify |
| `tests/test-party-routing.sh` | Create/Modify |
| `tests/run-tests.sh` | Modify |

## Requirements

**Functionality:**
- `tmux-codex.sh` resolves `CODEX_PANE` by role (`codex`) before sending.
- `tmux-claude.sh` resolves `CLAUDE_PANE` by role (`claude`) before sending.
- Scripts preserve existing output tokens (`CODEX_*`, `CLAUDE_*`) to avoid hook breakage.

**Key gotchas:**
- Do not alter mode semantics in `tmux-codex.sh` (`--review`, `--prompt`, etc.).
- Do not alter session discovery behavior.
- Keep failures explicit and observable in stdout/stderr.

## Tests

Test cases:
- Routing by role succeeds when role metadata exists.
- Routing falls back to legacy indices when metadata absent.
- Routing fails with explicit error when neither lookup nor fallback resolves.
- Existing hook tests still pass.

Verification commands:

```bash
bash tests/test-party-routing.sh
bash tests/run-tests.sh
```

## Acceptance Criteria

- [ ] Both transports are role-routed, not index-routed.
- [ ] Routing regression tests are green.
- [ ] Existing hook/state test suites remain green.
