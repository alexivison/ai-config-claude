#!/usr/bin/env bash
# Tests for master party session helpers: worker management, identity, jq gate.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/session/party-lib.sh"

PASS=0
FAIL=0

assert() {
  local desc="$1"
  if eval "$2"; then
    PASS=$((PASS + 1))
    echo "  [PASS] $desc"
  else
    FAIL=$((FAIL + 1))
    echo "  [FAIL] $desc"
  fi
}

if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found; skipping test-party-master.sh"
  exit 0
fi

MASTER="party-test-master-$$"
WORKER1="party-test-worker1-$$"
WORKER2="party-test-worker2-$$"
export PARTY_SESSION="$MASTER"
export PARTY_STATE_ROOT="/tmp/party-state-root-master-$$"

cleanup() {
  rm -rf "/tmp/$MASTER" "/tmp/$WORKER1" "/tmp/$WORKER2" "$PARTY_STATE_ROOT"
}
trap cleanup EXIT

echo "--- test-party-master.sh ---"

# Setup: create master manifest with session_type=master and workers=[]
ensure_party_state_dir "$MASTER" >/dev/null
party_state_upsert_manifest "$MASTER" "Master Test" "/tmp/project" "party (Master Test)" "/bin/claude" "/bin/codex" "/usr/bin"
party_state_set_field "$MASTER" "session_type" "master"

# ---- party_is_master ----
assert "party_is_master returns 0 for master session" \
  'party_is_master "$MASTER"'

assert "party_is_master returns 1 for non-master session" \
  '! party_is_master "$WORKER1"'

# Setup worker manifest (non-master)
ensure_party_state_dir "$WORKER1" >/dev/null
party_state_upsert_manifest "$WORKER1" "Worker 1" "/tmp/project" "party (Worker 1)" "/bin/claude" "/bin/codex" "/usr/bin"

assert "party_is_master returns 1 for regular session with manifest" \
  '! party_is_master "$WORKER1"'

# ---- party_state_add_worker / get_workers ----
party_state_add_worker "$MASTER" "$WORKER1"
assert "add_worker adds first worker" \
  '[ "$(party_state_get_workers "$MASTER" | wc -l | tr -d " ")" = "1" ]'
assert "get_workers returns correct worker ID" \
  '[ "$(party_state_get_workers "$MASTER")" = "$WORKER1" ]'

# Add second worker
ensure_party_state_dir "$WORKER2" >/dev/null
party_state_upsert_manifest "$WORKER2" "Worker 2" "/tmp/project" "party (Worker 2)" "/bin/claude" "/bin/codex" "/usr/bin"
party_state_add_worker "$MASTER" "$WORKER2"
assert "add_worker adds second worker" \
  '[ "$(party_state_get_workers "$MASTER" | wc -l | tr -d " ")" = "2" ]'

# Dedup: add same worker again
party_state_add_worker "$MASTER" "$WORKER1"
assert "add_worker deduplicates" \
  '[ "$(party_state_get_workers "$MASTER" | wc -l | tr -d " ")" = "2" ]'

# ---- party_state_remove_worker ----
party_state_remove_worker "$MASTER" "$WORKER1"
assert "remove_worker removes worker" \
  '[ "$(party_state_get_workers "$MASTER" | wc -l | tr -d " ")" = "1" ]'
assert "remaining worker is correct" \
  '[ "$(party_state_get_workers "$MASTER")" = "$WORKER2" ]'

# Remove last worker
party_state_remove_worker "$MASTER" "$WORKER2"
assert "remove_worker empties list" \
  '[ -z "$(party_state_get_workers "$MASTER")" ]'

# ---- Workers survive manifest upsert ----
party_state_add_worker "$MASTER" "$WORKER1"
party_state_add_worker "$MASTER" "$WORKER2"
party_state_upsert_manifest "$MASTER" "Master Test Updated" "/tmp/project" "party (Master Test)" "/bin/claude" "/bin/codex" "/usr/bin"
assert "workers survive manifest upsert" \
  '[ "$(party_state_get_workers "$MASTER" | wc -l | tr -d " ")" = "2" ]'

# ---- Deregistration via parent_session field ----
# Simulate the deregistration path: worker has parent_session, removing it cleans up master
party_state_add_worker "$MASTER" "$WORKER1"
party_state_set_field "$WORKER1" "parent_session" "$MASTER"
assert "worker registered before deregister test" \
  '[ "$(party_state_get_workers "$MASTER" | grep -c "$WORKER1")" = "1" ]'

# Deregister: read parent_session, remove from parent's workers (same logic as _party_deregister_from_parent)
_parent="$(party_state_get_field "$WORKER1" "parent_session")"
party_state_remove_worker "$_parent" "$WORKER1"
assert "deregister via parent_session removes worker from master" \
  '[ "$(party_state_get_workers "$MASTER" | grep -c "$WORKER1")" = "0" ]'

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
