#!/usr/bin/env bash
# tmux-codex.sh — Claude's direct interface to Codex via tmux
set -euo pipefail

MODE="${1:?Usage: tmux-codex.sh --review|--plan-review|--prompt|--review-complete|--needs-discussion}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../../session/party-lib.sh"

# Session discovery only for modes that need tmux (--review, --prompt).
# Evidence/escalation modes (--review-complete, --needs-discussion)
# only emit sentinel strings and work without a party session.
_require_session() {
  discover_session
  # Master sessions have no Codex pane — guard early
  if party_is_master "$SESSION_NAME" 2>/dev/null; then
    echo "CODEX_NOT_AVAILABLE: Master sessions have no Codex pane. Route review work through a worker session." >&2
    exit 1
  fi
  CODEX_PANE=$(party_role_pane_target_with_fallback "$SESSION_NAME" "codex") || {
    echo "Error: Cannot resolve Codex pane in session '$SESSION_NAME'" >&2
    exit 1
  }
}

case "$MODE" in

  --review)
    _require_session
    WORK_DIR="${2:?Missing work_dir — pass the worktree/repo path as 2nd argument}"
    BASE="${3:-main}"
    TITLE="${4:-Code review}"
    FINDINGS_FILE="$STATE_DIR/codex-findings-$(date +%s%N).toon"

    # Resolve tmux-claude.sh path for the notification callback
    NOTIFY_SCRIPT="$(cd "$SCRIPT_DIR/../../../../codex/skills/claude-transport/scripts" && pwd)/tmux-claude.sh"

    MSG="[CLAUDE] cd '$WORK_DIR' && Review the changes on this branch against $BASE. Title: $TITLE. Write TOON findings to: $FINDINGS_FILE. Emit raw TOON file contents only; no markdown fences. IMPORTANT: End the findings file with a verdict line — exactly 'VERDICT: APPROVED' if no blocking findings, or 'VERDICT: REQUEST_CHANGES' if there are blocking findings. — When done, run: $NOTIFY_SCRIPT \"Review complete. Findings at: $FINDINGS_FILE\""
    if tmux_send "$CODEX_PANE" "$MSG" "tmux-codex.sh:review"; then
      echo "CODEX_REVIEW_REQUESTED"
      echo "Claude is NOT blocked. Codex will notify via tmux when complete."
    else
      echo "CODEX_REVIEW_DROPPED"
      echo "Codex pane is busy. Message dropped (best-effort delivery)."
    fi
    echo "Findings will be written to: $FINDINGS_FILE"
    echo "Working directory: $WORK_DIR"
    ;;

  --plan-review)
    _require_session
    PLAN_PATH="${2:?Missing plan path}"
    WORK_DIR="${3:?Missing work_dir — pass the worktree/repo path as 3rd argument}"
    FINDINGS_FILE="$STATE_DIR/codex-plan-findings-$(date +%s%N).toon"

    NOTIFY_SCRIPT="$(cd "$SCRIPT_DIR/../../../../codex/skills/claude-transport/scripts" && pwd)/tmux-claude.sh"

    MSG="[CLAUDE] cd '$WORK_DIR' && Review '$PLAN_PATH' for architecture soundness and execution feasibility. Write TOON findings to: $FINDINGS_FILE. Emit raw TOON file contents only; no markdown fences. — When done, run: $NOTIFY_SCRIPT \"Plan review complete. Findings at: $FINDINGS_FILE\""
    if tmux_send "$CODEX_PANE" "$MSG" "tmux-codex.sh:plan-review"; then
      echo "CODEX_PLAN_REVIEW_REQUESTED"
      echo "Claude is NOT blocked. Codex will notify via tmux when complete."
    else
      echo "CODEX_PLAN_REVIEW_DROPPED"
      echo "Codex pane is busy. Message dropped (best-effort delivery)."
    fi
    echo "Findings will be written to: $FINDINGS_FILE"
    echo "Working directory: $WORK_DIR"
    ;;

  --prompt)
    _require_session
    PROMPT_TEXT="${2:?Missing prompt text}"
    WORK_DIR="${3:?Missing work_dir — pass the worktree/repo path as 3rd argument}"
    RESPONSE_FILE="$STATE_DIR/codex-response-$(date +%s%N).toon"

    NOTIFY_SCRIPT="$(cd "$SCRIPT_DIR/../../../../codex/skills/claude-transport/scripts" && pwd)/tmux-claude.sh"

    MSG="[CLAUDE] cd '$WORK_DIR' && $PROMPT_TEXT — Write response to: $RESPONSE_FILE — When done, run: $NOTIFY_SCRIPT \"Task complete. Response at: $RESPONSE_FILE\""
    if tmux_send "$CODEX_PANE" "$MSG" "tmux-codex.sh:prompt"; then
      echo "CODEX_TASK_REQUESTED"
      echo "Codex will notify via tmux when complete."
    else
      echo "CODEX_TASK_DROPPED"
      echo "Codex pane is busy. Message dropped (best-effort delivery)."
    fi
    echo "Response will be written to: $RESPONSE_FILE"
    echo "Working directory: $WORK_DIR"
    ;;

  --review-complete)
    FINDINGS_FILE="${2:?Missing findings file path}"
    if [[ ! -f "$FINDINGS_FILE" ]]; then
      echo "Error: Findings file not found: $FINDINGS_FILE" >&2
      exit 1
    fi
    echo "CODEX_REVIEW_RAN"
    # Parse verdict from findings file (written by Codex, not the worker).
    # Only Codex writes the findings file, so this verdict is trustworthy.
    if grep -qx 'VERDICT: APPROVED' "$FINDINGS_FILE"; then
      echo "CODEX APPROVED"
    elif grep -qx 'VERDICT: REQUEST_CHANGES' "$FINDINGS_FILE"; then
      echo "CODEX REQUEST_CHANGES"
    else
      echo "WARNING: No verdict line found in findings file. Review ran but no approval granted." >&2
      echo "CODEX VERDICT_MISSING"
    fi
    ;;

  --approve)
    echo "Error: --approve is deprecated. Codex approval flows through --review-complete," >&2
    echo "which reads the VERDICT line from the findings file Codex wrote." >&2
    echo "Do not self-approve. Use: tmux-codex.sh --review-complete <findings_file>" >&2
    exit 1
    ;;

  --needs-discussion)
    REASON="${2:-Multiple valid approaches or unresolvable findings}"
    echo "CODEX NEEDS_DISCUSSION — $REASON"
    ;;

  *)
    echo "Error: Unknown mode '$MODE'" >&2
    echo "Usage: tmux-codex.sh --review|--plan-review|--prompt|--review-complete|--needs-discussion" >&2
    exit 1
    ;;
esac
