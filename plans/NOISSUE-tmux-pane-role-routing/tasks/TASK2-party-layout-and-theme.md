# Task 2 — Rework Party Launch Layout And Pane Theming By Role

**Dependencies:** Task 1 | **Issue:** NOISSUE

---

## Goal

Update `party.sh` so new sessions launch with default pane order `codex -> claude -> shell`, set role metadata on panes, and render pane labels from role metadata rather than hardcoded pane indices.

## Scope Boundary (REQUIRED)

**In scope:**
- Change pane launch order and split sequence in `party_launch_agents`.
- Add role tagging (`@party_role`) for all party panes.
- Update pane titles and border format logic to derive labels from role.

**Out of scope (handled by other tasks):**
- Transport script routing changes (`tmux-codex.sh` / `tmux-claude.sh`).
- Hook behavior changes.
- README updates.

**Cross-task consistency check:**
- Roles emitted here must match task 1 resolver expectations exactly (`codex`, `claude`, `shell`).

## Reference

- `session/party.sh:88` — launch orchestration function
- `session/party.sh:126` — current pane respawn target assumptions
- `session/party.sh:129` — current pane title assignments
- `session/party.sh:72` — current index-based pane-border format
- `README.md:79` — current documented left/right assumptions

## Data Transformation Checklist (REQUIRED for shape changes)

Transformation shape here is pane metadata → visual/route identity:
- [x] Pane creation order defined (`0=codex`, `1=claude`, `2=shell`)
- [x] Role metadata assignment defined per pane
- [x] Border label mapping defined from role metadata
- [x] Session-id suffix behavior preserved for codex/claude labels

## Files to Create/Modify

| File | Action |
|------|--------|
| `session/party.sh` | Modify |

## Requirements

**Functionality:**
- Launch Codex in pane `0`, Claude in pane `1`, and shell in pane `2`.
- Set `@party_role` on each pane immediately after pane creation.
- Update `configure_party_theme` so label text is role-driven.
- Keep session cleanup hook and attach behavior intact.

**Key gotchas:**
- Keep behavior deterministic on both fresh start and `--continue` paths.
- Do not break `CLAUDE_SESSION_ID` / `CODEX_THREAD_ID` display on borders.
- Preserve shell safety (`set -euo pipefail`) and current command quoting patterns.

## Tests

Test cases:
- New session shows three panes with expected role labels.
- Launch/resume paths both assign role metadata.
- Pane labels remain correct after manual pane reorder (`swap-pane`) operations.

Verification commands:

```bash
./session/party.sh --raw
# manual: tmux display-message -p -t <session>:0.0 '#{@party_role}'
# manual: tmux display-message -p -t <session>:0.1 '#{@party_role}'
# manual: tmux display-message -p -t <session>:0.2 '#{@party_role}'
```

## Acceptance Criteria

- [x] Default layout and role tags match specification.
- [x] Theme labels use role metadata, not index assumptions.
- [x] No regression in startup/attach flow.
