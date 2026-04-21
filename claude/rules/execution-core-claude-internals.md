# Claude Execution-Core Internals

Claude's hook chain is the concrete implementation behind the shared execution-core rules. These details are Claude-specific and do not apply to Codex.

## Preset and PR Gate Enforcement

- `skill-marker.sh` writes `execution-preset = <name>` when a workflow skill is invoked.
- `pr-gate.sh` reads the latest preset and enforces the required evidence set at the current committed `diff_hash`.
- Operators can override the required evidence types with `cfg.Evidence.Required` in `~/.config/party-cli/config.toml`.

## Evidence Plumbing

- Evidence is recorded in the per-session JSONL log at `/tmp/claude-evidence-{session_id}.jsonl`.
- `agent-trace-stop.sh` records critic and runner evidence.
- `companion-trace.sh` records companion-review evidence from `--review-complete`.
- `companion-gate.sh` blocks direct `--approve`; approval must flow through the companion findings verdict.

## Oscillation Handling

- `agent-trace-stop.sh` performs same-hash oscillation detection.
- Cross-hash repeated-finding suppression applies to the minimizer only.

## Review Metrics

- Review metrics are defined in `claude/reference/review-metrics.md` (installed at `~/.claude/reference/review-metrics.md`).
- Metrics are written under `~/.claude/logs/review-metrics/` when Claude hooks are active.
