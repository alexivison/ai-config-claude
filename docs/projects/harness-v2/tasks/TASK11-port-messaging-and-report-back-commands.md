# Task 11 — Port Messaging And Report-Back Commands

**Dependencies:** Task 8, Task 9, Task 10 | **Issue:** TBD

---

## Goal

Port the full live messaging surface into `party-cli`: relay, broadcast, read, report-back, and worker enumeration. The plan must not repeat the earlier mistake of porting only the obvious operator commands while leaving report-back stranded in shell.

## Scope Boundary (REQUIRED)

**In scope:**
- Add `relay`, `broadcast`, `read`, `report`, and `workers` subcommands
- Reuse shared delivery-confirmed tmux service
- Preserve large-message handling semantics where temp-file indirection still buys reliability
- Keep shell wrappers working during coexistence

**Out of scope (handled by other tasks):**
- `tmux-codex.sh` ownership or Codex transport migration
- Final tracker widgets
- Final wrapper retirement

**Cross-task consistency check:**
- Report-back behavior ported here must satisfy the current worker workflow documented in `claude/skills/party-dispatch/SKILL.md`
- Task 12 and Task 13 should invoke the messaging services created here rather than shelling out directly

## Reference

Files to study before implementing:

- `session/party-relay.sh` — current messaging and report-back surface
- `claude/CLAUDE.md` — documented relay usage
- `claude/skills/party-dispatch/SKILL.md` — current worker report-back contract
- `tools/party-cli/internal/tmux/*` — delivery-confirmed send and capture helpers

## Design References (REQUIRED for UI/component tasks)

N/A (non-UI task)

## Data Transformation Checklist (REQUIRED for shape changes)

- [ ] Proto definition (N/A unless a typed file contract is introduced)
- [ ] Proto -> Domain converter (N/A unless a typed file contract is introduced)
- [ ] Domain model struct
- [ ] Params struct(s) — check ALL variants
- [ ] Params conversion functions
- [ ] Any adapters between param types

## Files to Create/Modify

| File | Action |
|------|--------|
| `tools/party-cli/cmd/relay.go` | Create |
| `tools/party-cli/cmd/broadcast.go` | Create |
| `tools/party-cli/cmd/read.go` | Create |
| `tools/party-cli/cmd/report.go` | Create |
| `tools/party-cli/cmd/workers.go` | Create |
| `tools/party-cli/internal/message/*` | Create or modify |
| `tools/party-cli/internal/message/*_test.go` | Create |
| `session/party-relay.sh` | Modify if wrapper delegation is added incrementally |

## Requirements

**Functionality:**
- All current party-relay command families have Go equivalents
- Delivery failures are explicit and surfaced to the caller
- Long or multi-line messages still work reliably
- Worker report-back remains supported for current automated workflows

**Key gotchas:**
- Do not silently narrow the semantics of `--report` or `--list`; the live docs prove those flows matter
- Keep shell wrapper behavior aligned with the Go implementation during coexistence

## Tests

Test cases:
- Relay and broadcast success/failure
- Read output and line-count variants
- Report-back delivery to masters
- Worker enumeration output
- Large-message file indirection or equivalent fallback behavior

## Acceptance Criteria

- [ ] `party-cli` owns relay, broadcast, read, report, and worker enumeration
- [ ] Report-back remains compatible with current worker workflows
- [ ] Messaging commands use delivery-confirmed tmux services
- [ ] Messaging tests pass
