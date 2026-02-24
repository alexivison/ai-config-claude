#!/usr/bin/env bash
# tmux-codex.sh — Claude's direct interface to Codex via tmux
# Replaces call_codex.sh + codex-verdict.sh
set -euo pipefail

MODE="${1:?Usage: tmux-codex.sh --review|--prompt|--review-complete|--approve|--re-review|--needs-discussion}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../../session/party-lib.sh"

# Session discovery only for modes that need tmux (--review, --prompt).
# Verdict/evidence modes (--approve, --re-review, --needs-discussion, --review-complete)
# only emit sentinel strings and work without a party session.
_require_session() {
  discover_session
  CODEX_PANE="$SESSION_NAME:work.1"
}

case "$MODE" in

  --review)
    _require_session
    BASE="${2:-main}"
    TITLE="${3:-Code review}"
    WORK_DIR="${4:-$(pwd)}"
    FINDINGS_FILE="$STATE_DIR/codex-findings-$(date +%s%N).json"

    # Resolve tmux-claude.sh path for the notification callback
    NOTIFY_SCRIPT="$(cd "$SCRIPT_DIR/../../../../codex/skills/claude-cli/scripts" && pwd)/tmux-claude.sh"

    tmux_send "$CODEX_PANE" \
      "cd $WORK_DIR && Review the changes on this branch against $BASE. Title: $TITLE. Write findings to: $FINDINGS_FILE — When done, run: $NOTIFY_SCRIPT \"Review complete. Findings at: $FINDINGS_FILE\""

    echo "CODEX_REVIEW_REQUESTED"
    echo "Findings will be written to: $FINDINGS_FILE"
    echo "Working directory: $WORK_DIR"
    echo "Claude is NOT blocked. Codex will notify via tmux when complete."
    ;;

  --prompt)
    _require_session
    PROMPT_TEXT="${2:?Missing prompt text}"
    WORK_DIR="${3:-$(pwd)}"
    RESPONSE_FILE="$STATE_DIR/codex-response-$(date +%s%N).md"

    NOTIFY_SCRIPT="$(cd "$SCRIPT_DIR/../../../../codex/skills/claude-cli/scripts" && pwd)/tmux-claude.sh"

    tmux_send "$CODEX_PANE" \
      "cd $WORK_DIR && $PROMPT_TEXT — Write response to: $RESPONSE_FILE — When done, run: $NOTIFY_SCRIPT \"Task complete. Response at: $RESPONSE_FILE\""

    echo "CODEX_TASK_REQUESTED"
    echo "Response will be written to: $RESPONSE_FILE"
    echo "Working directory: $WORK_DIR"
    echo "Codex will notify via tmux when complete."
    ;;

  --review-complete)
    FINDINGS_FILE="${2:?Missing findings file path}"
    if [[ ! -f "$FINDINGS_FILE" ]]; then
      echo "Error: Findings file not found: $FINDINGS_FILE" >&2
      exit 1
    fi
    echo "CODEX_REVIEW_RAN"
    ;;

  --approve)
    echo "CODEX APPROVED"
    ;;

  --re-review)
    REASON="${2:-Blocking findings fixed}"
    echo "CODEX REQUEST_CHANGES — $REASON"
    ;;

  --needs-discussion)
    REASON="${2:-Multiple valid approaches or unresolvable findings}"
    echo "CODEX NEEDS_DISCUSSION — $REASON"
    ;;

  *)
    echo "Error: Unknown mode '$MODE'" >&2
    echo "Usage: tmux-codex.sh --review|--prompt|--review-complete|--approve|--re-review|--needs-discussion" >&2
    exit 1
    ;;
esac
