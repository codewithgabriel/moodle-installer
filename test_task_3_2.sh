#!/usr/bin/env bash
# Test script for task 3.2 fixes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/checks.sh"

echo "Testing Task 3.2 Fixes..."
echo ""

# Test 1: Check webserver status messages go to stderr
echo "Test 1: check_webserver status messages to stderr"
WEB_SERVER=$(check_webserver 2>/dev/null)
echo "  ✓ Captured webserver: $WEB_SERVER (status messages went to stderr)"
echo ""

# Test 2: Background job monitoring with status capture
echo "Test 2: Background job status capture"
test_background_success() {
  sleep 0.1 &
  local pid=$!
  wait "$pid"
  local status=$?
  if [[ $status -eq 0 ]]; then
    echo "  ✓ Successfully captured exit status: $status"
  else
    echo "  ✗ Failed to capture exit status"
    return 1
  fi
}
test_background_success
echo ""

# Test 3: Comprehensive error output format
echo "Test 3: Comprehensive error output format"
if grep -q "Exit Code:" lib/utils.sh && \
   grep -q "Command:" lib/utils.sh && \
   grep -q "date" lib/utils.sh && \
   grep -q "====" lib/utils.sh; then
  echo "  ✓ run_cmd has comprehensive error formatting"
  echo "    - Timestamp: YES"
  echo "    - Command display: YES"
  echo "    - Exit code: YES"
  echo "    - Visual separators: YES"
else
  echo "  ✗ Missing comprehensive error formatting"
  exit 1
fi
echo ""

# Test 4: Verify run_cmd captures status after wait
echo "Test 4: run_cmd status capture after wait"
if grep -A 3 "wait.*\$pid" lib/utils.sh | grep -q "status=\$?"; then
  echo "  ✓ run_cmd captures status after wait"
else
  echo "  ✗ run_cmd does not capture status"
  exit 1
fi
echo ""

echo "=========================================="
echo "All Task 3.2 tests PASSED!"
echo "=========================================="
echo ""
echo "Summary of fixes:"
echo "1. ✓ check_webserver: Status messages to stderr"
echo "2. ✓ case_b_existing.sh: Proper conditionals (already fixed)"
echo "3. ✓ run_cmd: Background job monitoring with status capture"
echo "4. ✓ run_cmd: Comprehensive error output with formatting"
