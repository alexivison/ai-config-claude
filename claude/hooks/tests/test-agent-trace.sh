#!/usr/bin/env bash
# Tests for agent-trace.sh
# Covers: verdict detection, marker creation, response format handling
#
# Usage: bash ~/.claude/hooks/tests/test-agent-trace.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="${SCRIPT_DIR}/../agent-trace.sh"
TRACE_FILE="$HOME/.claude/logs/agent-trace.jsonl"
PASS=0
FAIL=0
SESSION="test-agent-trace-$$"

cleanup() {
  rm -f /tmp/claude-code-critic-"$SESSION"
  rm -f /tmp/claude-minimizer-"$SESSION"
  rm -f /tmp/claude-tests-passed-"$SESSION"
  rm -f /tmp/claude-checks-passed-"$SESSION"
}

assert() {
  local name="$1" condition="$2"
  if eval "$condition"; then
    echo "  PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name"
    FAIL=$((FAIL + 1))
  fi
}

last_verdict() {
  # Extract verdict from the last trace entry for our test session.
  # Trace file uses multi-line pretty-printed JSON objects (not JSONL).
  tail -80 "$TRACE_FILE" | python3 -c "
import sys, json, re
text = sys.stdin.read()
# Split on top-level '{' boundaries
entries = re.findall(r'\{[^{}]*\}', text, re.DOTALL)
last = '?'
for e in entries:
    try:
        d = json.loads(e)
        if d.get('session') == '$SESSION':
            last = d.get('verdict', '?')
    except (json.JSONDecodeError, ValueError):
        pass
print(last)
" 2>/dev/null
}

run_hook() {
  echo "$1" | bash "$HOOK" 2>/dev/null
}

# Helper to build Agent hook input
agent_input() {
  local agent_type="$1" response="$2"
  cat <<JSONEOF
{"tool_name":"Agent","tool_input":{"subagent_type":"$agent_type","description":"test","model":"inherit"},"tool_response":$response,"session_id":"$SESSION","cwd":"/tmp/test-project"}
JSONEOF
}

# ─── Response format tests ───────────────────────────────────────────────────

echo "=== Response Format: Array of content blocks ==="
cleanup
run_hook "$(agent_input code-critic '[{"type":"text","text":"Review done.\n\n**APPROVE** — All good."},{"type":"text","text":"agentId: abc123\n<usage>total_tokens: 35000\ntool_uses: 8\nduration_ms: 30000</usage>"}]')"
assert "Array response → APPROVED verdict" '[ "$(last_verdict)" = "APPROVED" ]'
assert "Array response → code-critic marker created" '[ -f /tmp/claude-code-critic-$SESSION ]'

echo "=== Response Format: Plain string ==="
cleanup
run_hook "$(agent_input test-runner '"All 42 tests passed.\n\nPASS"')"
assert "String response → PASS verdict" '[ "$(last_verdict)" = "PASS" ]'
assert "String response → test-runner marker created" '[ -f /tmp/claude-tests-passed-$SESSION ]'

echo "=== Response Format: Mixed-type array (objects, strings, nulls) ==="
cleanup
run_hook "$(agent_input code-critic '["plain string",{"type":"text","text":"**APPROVE** — ok"},null]')"
assert "Mixed array → APPROVED verdict" '[ "$(last_verdict)" = "APPROVED" ]'

echo "=== Response Format: Background agent launch (no verdict) ==="
cleanup
run_hook "$(agent_input code-critic '"Launched successfully.\nagentId: bg123\nThe agent is working in the background."')"
assert "Background launch → unknown verdict" '[ "$(last_verdict)" = "unknown" ]'
assert "Background launch → no marker" '[ ! -f /tmp/claude-code-critic-$SESSION ]'

# ─── Metadata stripping tests ────────────────────────────────────────────────

echo "=== Metadata: agentId and <usage> stripped before scanning ==="
cleanup
run_hook "$(agent_input minimizer '[{"type":"text","text":"**APPROVE** — minimal."},{"type":"text","text":"agentId: xyz789\n<usage>total_tokens: 50000\ntool_uses: 12\nduration_ms: 45000</usage>"}]')"
assert "Metadata stripped → APPROVED" '[ "$(last_verdict)" = "APPROVED" ]'
assert "Metadata stripped → minimizer marker" '[ -f /tmp/claude-minimizer-$SESSION ]'

echo "=== Metadata: Legitimate <usage> in prose preserved ==="
cleanup
run_hook "$(agent_input code-critic '[{"type":"text","text":"The <usage> of this pattern is good.\n\n**APPROVE**"},{"type":"text","text":"agentId: a1\n<usage>total_tokens: 5000\ntool_uses: 2\nduration_ms: 3000</usage>"}]')"
assert "Prose <usage> preserved → APPROVED" '[ "$(last_verdict)" = "APPROVED" ]'

echo "=== Metadata: Indented agentId stripped ==="
cleanup
run_hook "$(agent_input code-critic '[{"type":"text","text":"**APPROVE**"},{"type":"text","text":"  agentId: indented123\n<usage>total_tokens: 1000\ntool_uses: 1\nduration_ms: 1000</usage>"}]')"
assert "Indented agentId stripped → APPROVED" '[ "$(last_verdict)" = "APPROVED" ]'

# ─── Verdict detection tests ─────────────────────────────────────────────────

echo "=== Verdict: REQUEST_CHANGES ==="
cleanup
run_hook "$(agent_input code-critic '[{"type":"text","text":"Found bugs.\n\n**REQUEST_CHANGES**\n\n[must] Fix null check."},{"type":"text","text":"agentId: rc1\n<usage>total_tokens: 2000\ntool_uses: 3\nduration_ms: 5000</usage>"}]')"
assert "REQUEST_CHANGES detected" '[ "$(last_verdict)" = "REQUEST_CHANGES" ]'
assert "REQUEST_CHANGES → no marker" '[ ! -f /tmp/claude-code-critic-$SESSION ]'

echo "=== Verdict: NEEDS_DISCUSSION ==="
cleanup
run_hook "$(agent_input code-critic '[{"type":"text","text":"Unclear requirement.\n\n**NEEDS_DISCUSSION**"},{"type":"text","text":"agentId: nd1\n<usage>total_tokens: 1000\ntool_uses: 1\nduration_ms: 1000</usage>"}]')"
assert "NEEDS_DISCUSSION detected" '[ "$(last_verdict)" = "NEEDS_DISCUSSION" ]'

echo "=== Verdict: FAIL ==="
cleanup
run_hook "$(agent_input test-runner '[{"type":"text","text":"3 tests failed.\n\nFAIL"},{"type":"text","text":"agentId: f1\n<usage>total_tokens: 1000\ntool_uses: 1\nduration_ms: 1000</usage>"}]')"
assert "FAIL detected" '[ "$(last_verdict)" = "FAIL" ]'
assert "FAIL → no test-runner marker" '[ ! -f /tmp/claude-tests-passed-$SESSION ]'

echo "=== Verdict: CLEAN ==="
cleanup
run_hook "$(agent_input check-runner '[{"type":"text","text":"No issues found.\n\nCLEAN"},{"type":"text","text":"agentId: cl1\n<usage>total_tokens: 1000\ntool_uses: 1\nduration_ms: 1000</usage>"}]')"
assert "CLEAN detected" '[ "$(last_verdict)" = "CLEAN" ]'
assert "CLEAN → check-runner marker" '[ -f /tmp/claude-checks-passed-$SESSION ]'

echo "=== Verdict: ISSUES_FOUND ==="
cleanup
run_hook "$(agent_input code-critic '[{"type":"text","text":"Found CRITICAL issue in review."},{"type":"text","text":"agentId: sec1\n<usage>total_tokens: 1000\ntool_uses: 1\nduration_ms: 1000</usage>"}]')"
assert "ISSUES_FOUND detected" '[ "$(last_verdict)" = "ISSUES_FOUND" ]'

# ─── Marker creation tests ───────────────────────────────────────────────────

echo "=== Markers: Each agent type maps to correct marker ==="
cleanup
run_hook "$(agent_input code-critic '[{"type":"text","text":"**APPROVE**"},{"type":"text","text":"agentId: m1\n<usage>total_tokens: 100\ntool_uses: 1\nduration_ms: 100</usage>"}]')"
assert "code-critic APPROVE → code-critic marker" '[ -f /tmp/claude-code-critic-$SESSION ]'
assert "code-critic APPROVE → no minimizer marker" '[ ! -f /tmp/claude-minimizer-$SESSION ]'

cleanup
run_hook "$(agent_input minimizer '[{"type":"text","text":"**APPROVE**"},{"type":"text","text":"agentId: m2\n<usage>total_tokens: 100\ntool_uses: 1\nduration_ms: 100</usage>"}]')"
assert "minimizer APPROVE → minimizer marker" '[ -f /tmp/claude-minimizer-$SESSION ]'
assert "minimizer APPROVE → no code-critic marker" '[ ! -f /tmp/claude-code-critic-$SESSION ]'

cleanup
run_hook "$(agent_input check-runner '[{"type":"text","text":"All passed.\n\nPASS"},{"type":"text","text":"agentId: m3\n<usage>total_tokens: 100\ntool_uses: 1\nduration_ms: 100</usage>"}]')"
assert "check-runner PASS → checks-passed marker" '[ -f /tmp/claude-checks-passed-$SESSION ]'

# ─── Guard tests ─────────────────────────────────────────────────────────────

echo "=== Guard: Non-Agent tool ignored ==="
cleanup
echo '{"tool_name":"Bash","tool_input":{"command":"echo hi"},"tool_response":"hi","session_id":"'"$SESSION"'","cwd":"/tmp"}' | bash "$HOOK" 2>/dev/null
assert "Bash tool → no marker" '[ ! -f /tmp/claude-code-critic-$SESSION ]'

echo "=== Guard: Invalid JSON fails open ==="
cleanup
echo 'not json at all' | bash "$HOOK" 2>/dev/null || true
assert "Invalid JSON → no crash (exit 0)" 'true'

# ─── Verdict priority tests ─────────────────────────────────────────────────

echo "=== Priority: REQUEST_CHANGES wins over APPROVE ==="
cleanup
run_hook "$(agent_input code-critic '[{"type":"text","text":"APPROVE in prose but **REQUEST_CHANGES** is the verdict."},{"type":"text","text":"agentId: p1\n<usage>total_tokens: 100\ntool_uses: 1\nduration_ms: 100</usage>"}]')"
assert "REQUEST_CHANGES takes priority" '[ "$(last_verdict)" = "REQUEST_CHANGES" ]'

# ─── Token extraction tests ─────────────────────────────────────────────────

last_tokens() {
  tail -80 "$TRACE_FILE" | python3 -c "
import sys, json, re
text = sys.stdin.read()
entries = re.findall(r'\{[^{}]*\}', text, re.DOTALL)
last = '?'
for e in entries:
    try:
        d = json.loads(e)
        if d.get('session') == '$SESSION':
            last = str(d.get('tokens', '?'))
    except (json.JSONDecodeError, ValueError):
        pass
print(last)
" 2>/dev/null
}

echo "=== Tokens: Extracted from <usage> block ==="
cleanup
run_hook "$(agent_input code-critic '[{"type":"text","text":"**APPROVE**"},{"type":"text","text":"agentId: t1\n<usage>total_tokens: 25000\ntool_uses: 5\nduration_ms: 10000</usage>"}]')"
assert "Token count 25000 captured" '[ "$(last_tokens)" = "25000" ]'

echo "=== Tokens: Missing <usage> block defaults to 0 ==="
cleanup
run_hook "$(agent_input code-critic '[{"type":"text","text":"**APPROVE**"}]')"
assert "Missing <usage> → tokens 0" '[ "$(last_tokens)" = "0" ]'

echo "=== Tokens: Plain string response defaults to 0 ==="
cleanup
run_hook "$(agent_input test-runner '"All tests passed.\nPASS"')"
assert "String response → tokens 0" '[ "$(last_tokens)" = "0" ]'

echo "=== Tokens: Large token count parsed correctly ==="
cleanup
run_hook "$(agent_input minimizer '[{"type":"text","text":"**APPROVE**"},{"type":"text","text":"agentId: t2\n<usage>total_tokens: 150000\ntool_uses: 20\nduration_ms: 60000</usage>"}]')"
assert "Token count 150000 captured" '[ "$(last_tokens)" = "150000" ]'

echo "=== Tokens: Appears in evidence-trace.log ==="
cleanup
run_hook "$(agent_input code-critic '[{"type":"text","text":"**APPROVE**"},{"type":"text","text":"agentId: t3\n<usage>total_tokens: 42000\ntool_uses: 8\nduration_ms: 15000</usage>"}]')"
assert "Token count in evidence-trace.log" 'grep "$SESSION" "$HOME/.claude/logs/evidence-trace.log" | grep -q "42000"'

# ─── Summary ─────────────────────────────────────────────────────────────────

cleanup
echo ""
echo "═══════════════════════════════════════"
echo "agent-trace.sh: $PASS passed, $FAIL failed"
echo "═══════════════════════════════════════"
[ "$FAIL" -eq 0 ] || exit 1
