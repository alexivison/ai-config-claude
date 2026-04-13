# Task 6 — Extend Tests

**Dependencies:** Task 2, Task 3

## Goal

Extend Go transport tests for multi-companion scenarios and update hook tests for the renamed hooks. Ensure backward compatibility and parameterization work correctly.

## Scope Boundary

**In scope:**
- `tools/party-cli/internal/transport/transport_test.go` — Add companion-parameterized test cases
- `tools/party-cli/internal/companion/` — Extend companion tests from Task 1 with multi-companion scenarios
- Hook tests: Rename and update `test-codex-gate.sh` → `test-companion-gate.sh`, etc.
- Update `test-pr-gate.sh` to test config-driven evidence requirements

**Out of scope:**
- Changing transport or hook logic (already done in Tasks 2, 3)
- Integration/e2e tests

**Design References:** N/A (non-UI task)

## Reference

- `tools/party-cli/internal/transport/transport_test.go` — Existing Go tests to extend
- `claude/hooks/tests/test-codex-gate.sh` — Existing hook tests to rename
- `claude/hooks/tests/test-codex-trace.sh` — Existing hook tests to rename
- `claude/hooks/tests/test-pr-gate.sh` — Existing PR gate tests to extend

## Files to Create/Modify

| File | Action |
|------|--------|
| `tools/party-cli/internal/companion/companion_test.go` | Modify — extend (created in Task 1) |
| `tools/party-cli/internal/transport/transport_test.go` | Modify — add companion-aware tests |
| `claude/hooks/tests/test-codex-gate.sh` | Rename to `test-companion-gate.sh` + update |
| `claude/hooks/tests/test-codex-trace.sh` | Rename to `test-companion-trace.sh` + update |
| `claude/hooks/tests/test-pr-gate.sh` | Modify — add config-driven tests |

## Requirements

**Functionality:**
- `companion_test.go`: Extend Task 1 tests with multi-companion registry scenarios (two companions, capability conflicts, missing companion graceful degradation)
- `transport_test.go`: Add test cases for: dispatch with `--to wizard`, dispatch with default companion resolution, `CompanionStatus` written to correct filename, `notify` completion detection via `ParseCompletion()`
- `test-companion-gate.sh`: Test `approve` blocked for any `--to` value. Test all other modes pass.
- `test-companion-trace.sh`: Test evidence recorded with companion name as type.
- `test-pr-gate.sh`: Add cases for: (a) no `.party.toml` → default evidence list with companion name; (b) custom `[evidence].required` → uses that list

**Key gotchas:**
- Go tests should use the `Runner` mock interface for tmux operations (no real tmux needed)
- Hook tests must set up mock `.party.toml` files in temp dirs for config-driven tests
- Existing test assertions about `"codex"` evidence type change to companion name
- CI config (`.github/workflows/ci.yml`) may need test path updates if filenames changed

## Tests

- All Go companion package tests pass
- All Go transport tests pass (existing + new)
- All renamed hook tests pass
- PR gate tests cover with/without `.party.toml`
- CI runs updated test paths

## Acceptance Criteria

- [ ] `companion_test.go` extended with multi-companion scenarios (base tests created in Task 1)
- [ ] Transport tests cover companion-parameterized dispatch
- [ ] Hook tests renamed and updated for companion-generic logic
- [ ] PR gate tests cover config-driven and default evidence requirements
- [ ] All tests pass in CI
