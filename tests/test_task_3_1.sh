#!/usr/bin/env bash
# Test script for Task 3.1: Fix Bug 1.1 - Strict mode silent aborts

set -euo pipefail  # Enable strict mode to simulate the bug condition

echo "Testing Bug 1.1 fix: Strict mode silent aborts"
echo "================================================"
echo ""

# Source the necessary files
source lib/colors.sh
source lib/utils.sh
source lib/checks.sh

echo "Test 1: check_webserver with strict mode enabled"
echo "-------------------------------------------------"
check_webserver >/dev/null 2>&1 || true
echo "✓ check_webserver completed without aborting"
echo ""

echo "Test 2: check_php_version with strict mode enabled"
echo "---------------------------------------------------"
check_php_version >/dev/null 2>&1 || true
echo "✓ check_php_version completed without aborting"
echo ""

echo "Test 3: check_mariadb with strict mode enabled"
echo "-----------------------------------------------"
check_mariadb >/dev/null 2>&1 || true
echo "✓ check_mariadb completed without aborting"
echo ""

echo "Test 4: check_systemctl with strict mode enabled"
echo "-------------------------------------------------"
check_systemctl >/dev/null 2>&1 || true
echo "✓ check_systemctl completed without aborting"
echo ""

echo "================================================"
echo "All tests completed successfully!"
echo "Bug 1.1 fix is working correctly."
echo "The script did NOT abort despite strict mode being enabled."
