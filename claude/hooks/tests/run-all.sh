#!/usr/bin/env bash
# Run all hook tests
# Usage: bash ~/.claude/hooks/tests/run-all.sh

set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
TOTAL_PASS=0
TOTAL_FAIL=0

for test_file in "$DIR"/test-*.sh; do
  echo ""
  echo "━━━ $(basename "$test_file") ━━━"
  echo ""
  if bash "$test_file"; then
    :
  else
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
  fi
done

echo ""
if [ "$TOTAL_FAIL" -eq 0 ]; then
  echo "All test suites passed."
else
  echo "$TOTAL_FAIL test suite(s) had failures."
  exit 1
fi
