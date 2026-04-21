#!/usr/bin/env bash
# PR Gate Hook — Enforces workflow completion before PR creation
# Uses JSONL evidence log with diff_hash matching (stale evidence auto-ignored).
#
# Opt-in model:
#   - Default: direct editing. No workflow skill invoked → no preset evidence →
#     gate allows PR creation.
#   - A workflow skill writes execution-preset (task|bugfix|quick|spec) via
#     skill-marker.sh. The preset maps to a required evidence set.
#   - `cfg.Evidence.Required` in party-cli config overrides the preset mapping
#     when explicitly configured.
#   - Docs-only PRs still bypass the gate regardless of preset.
#
# Triggered: PreToolUse on Bash tool
# Fails open on errors (allows operation if hook can't determine state).

source "$(dirname "$0")/lib/evidence.sh"
source "$(dirname "$0")/lib/party-cli.sh"

# Evidence set keyed by preset. Companion type comes from party-cli config
# — empty when no companion role is configured, so task/bugfix presets omit
# the companion evidence requirement.
preset_evidence_types() {
  local preset="$1"
  local companion
  companion=$(party_cli_query "$CWD" "companion-name" 2>/dev/null | head -n 1 | tr -d '[:space:]')
  case "$preset" in
    task)
      printf 'code-critic minimizer requirements-auditor'
      [ -n "$companion" ] && printf ' %s' "$companion"
      printf ' pr-verified test-runner check-runner'
      ;;
    bugfix)
      printf 'code-critic minimizer'
      [ -n "$companion" ] && printf ' %s' "$companion"
      printf ' pr-verified test-runner check-runner'
      ;;
    quick)
      echo "code-critic pr-verified test-runner check-runner"
      ;;
    spec)
      echo "pr-verified"
      ;;
    *)
      return 1
      ;;
  esac
}

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)

# Fail open if we can't parse input
if [ -z "$SESSION_ID" ]; then
  hook_log "pr-gate" "unknown" "allow" "no session_id — fail open"
  echo '{}'
  exit 0
fi

# Only check PR creation (not git push — allow pushing during development).
# Don't anchor with ^ since command may be chained (e.g., "cd ... && gh pr create")
if echo "$COMMAND" | grep -qE 'gh pr create'; then
  CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
  CWD=$(_resolve_cwd "$SESSION_ID" "$CWD")

  # Docs-only bypass: assume code PR unless we can prove docs-only.
  # Use working-tree diff (no ..HEAD) to match evidence.sh scope.
  IMPL_FILES="unknown"
  if [ -n "$CWD" ]; then
    if ! _resolve_merge_base "$CWD"; then
      IMPL_FILES="unknown"
    elif [ -n "$_EVIDENCE_MERGE_BASE" ]; then
      IMPL_FILES=$(cd "$CWD" 2>/dev/null && git diff --name-only "$_EVIDENCE_MERGE_BASE" 2>/dev/null \
        | grep -E '\.(sh|bash|go|py|ts|js|tsx|jsx|rs|rb|java|kt|swift|c|cpp|h|hpp|sql|proto|css|scss|html|vue|svelte|zig|hs|ex|exs|el|clj|lua|php|pl|pm|scala|groovy|tf|nix|cmake|gradle|xml|mod|sum|lock)$|(^|/)(Makefile|Dockerfile|Jenkinsfile|Vagrantfile|Rakefile|Gemfile|Taskfile|go\.sum|package-lock\.json|yarn\.lock|pnpm-lock\.yaml|Cargo\.lock|Gemfile\.lock|poetry\.lock|composer\.lock|requirements\.txt|constraints\.txt|pip\.conf|setup\.cfg|tox\.ini)$' || true)
    fi
  fi

  # Docs/config-only PRs skip the gate entirely (empty = no impl files found)
  if [ -z "$IMPL_FILES" ]; then
    hook_log "pr-gate" "$SESSION_ID" "allow" "docs-only PR — gate bypassed"
    echo '{}'
    exit 0
  fi

  # Evidence resolution: config override > preset > allow
  # cfg.Evidence.Required in party-cli config overrides preset when set.
  REQUIRED=""
  CONFIG_REQUIRED=$(party_cli_query "$CWD" "evidence-required" 2>/dev/null || true)
  if [ -n "$CONFIG_REQUIRED" ]; then
    REQUIRED=$(echo "$CONFIG_REQUIRED" | tr '\n' ' ')
    hook_log "pr-gate" "$SESSION_ID" "config-override" "required=$REQUIRED"
  else
    PRESET=$(get_session_preset "$SESSION_ID" 2>/dev/null || echo "")
    if [ -z "$PRESET" ]; then
      # Opt-in default: no workflow skill invoked → no enforcement.
      hook_log "pr-gate" "$SESSION_ID" "allow" "no preset — opt-in default"
      echo '{}'
      exit 0
    fi
    REQUIRED=$(preset_evidence_types "$PRESET" || true)
    if [ -z "$REQUIRED" ]; then
      hook_log "pr-gate" "$SESSION_ID" "allow" "unknown preset '$PRESET' — fail open"
      echo '{}'
      exit 0
    fi
    hook_log "pr-gate" "$SESSION_ID" "preset" "preset=$PRESET required=$REQUIRED"
  fi

  DIAG_FILE=$(mktemp 2>/dev/null || echo "/tmp/pr-gate-diag-$$")
  MISSING=$(check_all_evidence "$SESSION_ID" "$REQUIRED" "$CWD" 2>"$DIAG_FILE" || true)
  STALE_DIAG=""
  [ -f "$DIAG_FILE" ] && STALE_DIAG=$(cat "$DIAG_FILE") && rm -f "$DIAG_FILE"

  if [ -n "$MISSING" ]; then
    REASON="BLOCKED: PR gate requirements not met. Missing:$MISSING. Complete all workflow steps before creating PR."
    [ -n "$STALE_DIAG" ] && REASON="${REASON}${STALE_DIAG}"
    hook_log "pr-gate" "$SESSION_ID" "deny" "missing:$MISSING"
    jq -cn --arg reason "$REASON" \
      '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
    exit 0
  fi

  hook_log "pr-gate" "$SESSION_ID" "allow" "pr-create passed"
fi

# Allow by default
hook_log "pr-gate" "$SESSION_ID" "allow" ""
echo '{}'
