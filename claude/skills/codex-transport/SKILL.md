---
name: codex-transport
description: >-
  Transport layer for communicating with Codex CLI via tmux. Provides modes for
  code review (--review), plan review (--plan-review), ad-hoc tasks (--prompt),
  review evidence (--review-complete), and escalation (--needs-discussion).
  Codex approval flows through the findings file verdict — workers cannot
  self-approve. Use whenever dispatching work to Codex, recording review
  evidence, or signaling escalation.
user-invocable: false
---

# codex-transport — Communicate with Codex via tmux

## When to contact Codex

- **For code review**: After implementing changes and passing sub-agent critics, request Codex review
- **For tasks**: When you need Codex to investigate or work on something in parallel
- **For verdict**: After triaging Codex's findings, signal your decision

## How to contact Codex

Use the transport script:
```bash
~/.claude/skills/codex-transport/scripts/tmux-codex.sh <mode> [args...]
```

## Modes

### Request code review (non-blocking)
After implementing changes and passing sub-agent critics:
```bash
~/.claude/skills/codex-transport/scripts/tmux-codex.sh --review <work_dir> [base_branch] ["PR title"]
```
`work_dir` is **REQUIRED** — the absolute path to the worktree or repo where changes live. The script will error if omitted. Codex's pane is in a different directory; it needs this to `cd` into the correct location. `base_branch` defaults to `main`, `PR title` defaults to `Code review`.

This sends a message to Codex's pane. You are NOT blocked — continue with non-edit work while Codex reviews. Codex will notify you via `[CODEX] Review complete. Findings at: <path>` when done. Findings are raw TOON (`.toon` file, no markdown fences). Handle that message per your `tmux-handler` skill.

### Request plan review (non-blocking)
After creating a plan:
```bash
~/.claude/skills/codex-transport/scripts/tmux-codex.sh --plan-review "<plan_path>" <work_dir>
```
`work_dir` is **REQUIRED**. Plan review is advisory — it is intentionally ungated by critic markers and does NOT create or reuse the `codex-ran` approval marker. Codex will notify via `[CODEX] Plan review complete. Findings at: <path>` when done. Findings are raw TOON (`.toon` file, no markdown fences).

### Send a task (non-blocking)
**IMPORTANT:** Prompts with quotes, backticks, or >500 characters risk `unmatched '` shell errors when passed inline. Write to a temp file first:
```bash
cat > /tmp/codex-prompt.md << 'EOF'
Your long prompt here...
EOF
~/.claude/skills/codex-transport/scripts/tmux-codex.sh --prompt "$(cat /tmp/codex-prompt.md)" /path/to/repo
```

Short prompts can be passed directly:
```bash
~/.claude/skills/codex-transport/scripts/tmux-codex.sh --prompt "<task description>" <work_dir>
```
`work_dir` is **REQUIRED**. Returns immediately. Codex will notify via `[CODEX] Task complete. Response at: <path>` when done. The response path uses `.toon` by convention. If you requested structured findings, expect canonical TOON; if you asked for narrative analysis, plain text is acceptable unless you explicitly required TOON.

### Record review completion and verdict
**CRITICAL:** The argument is the **full path to the `.toon` findings file** from the `[CODEX] Review complete. Findings at: <path>` notification — NOT a worktree path. Passing a worktree path will fail with "Findings file not found."

```bash
~/.claude/skills/codex-transport/scripts/tmux-codex.sh --review-complete "<findings_file>"
```

This reads the findings file and extracts the verdict Codex wrote:
- If findings contain `VERDICT: APPROVED` → creates both `codex-ran` and `codex APPROVED` evidence
- If findings contain `VERDICT: REQUEST_CHANGES` → creates only `codex-ran` evidence
- If no verdict line found → creates only `codex-ran` evidence (warning emitted)

**You CANNOT call `--approve` directly.** The gate hard-blocks it. Approval can only come from Codex via the verdict line in the findings file. This prevents workers from self-approving their own fixes.

### Signal escalation
```bash
# Unresolvable after max iterations
~/.claude/skills/codex-transport/scripts/tmux-codex.sh --needs-discussion "reason"
```

**Blocking findings?** Fix the code, re-run critics, then dispatch a new `--review`. Editing code invalidates all evidence (diff_hash changes), so the full cascade re-runs naturally. There is no shortcut — the gates enforce it.

## Important

- `--review`, `--plan-review`, and `--prompt` are NON-BLOCKING. Continue working while Codex processes.
- `--review-complete` emits `CODEX_REVIEW_RAN` only after findings exist.
- `--needs-discussion` is instant — outputs a sentinel for hook detection.
- **You cannot self-approve.** Codex decides the verdict via the `VERDICT:` line in the findings file.
- Before calling `--review`, ensure sub-agent critics have passed (codex-gate.sh enforces this).
- `--plan-review` is ungated — no critic markers or codex-ran markers required or affected.
- **Blocking codex findings:** fix code → (evidence auto-invalidated via diff_hash) → re-run critics → new `--review` → `--review-complete`. No special flag needed.
