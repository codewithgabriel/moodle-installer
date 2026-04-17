#!/usr/bin/env bash
# Test script for task 3.2 functions

set -euo pipefail

# Source required libraries
source lib/colors.sh
source lib/utils.sh
source lib/version_config.sh
source lib/checks.sh

echo "=========================================="
echo "Testing Task 3.2 Functions"
echo "=========================================="
echo ""

# Test 1: Verify functions exist
echo "Test 1: Verifying functions exist..."
if declare -f add_mariadb_repository &>/dev/null; then
  echo "✓ add_mariadb_repository() exists"
else
  echo "✗ add_mariadb_repository() NOT FOUND"
  exit 1
fi

if declare -f install_compatible_database &>/dev/null; then
  echo "✓ install_compatible_database() exists"
else
  echo "✗ install_compatible_database() NOT FOUND"
  exit 1
fi

if declare -f verify_database_version &>/dev/null; then
  echo "✓ verify_database_version() exists"
else
  echo "✗ verify_database_version() NOT FOUND"
  exit 1
fi

echo ""
echo "Test 2: Testing parse_db_requirements()..."
req_output=$(parse_db_requirements "MOODLE_501_STABLE")
mariadb_min=$(echo "$req_output" | grep "mariadb_min=" | cut -d= -f2)
mysql_min=$(echo "$req_output" | grep "mysql_min=" | cut -d= -f2)

echo "  Moodle 5.0.1 requirements:"
echo "    MariaDB minimum: $mariadb_min"
echo "    MySQL minimum: $mysql_min"

if [[ "$mariadb_min" == "10.11.0" ]]; then
  echo "✓ MariaDB version requirement correct"
else
  echo "✗ MariaDB version requirement incorrect (expected 10.11.0, got $mariadb_min)"
  exit 1
fi

if [[ "$mysql_min" == "8.4.0" ]]; then
  echo "✓ MySQL version requirement correct"
else
  echo "✗ MySQL version requirement incorrect (expected 8.4.0, got $mysql_min)"
  exit 1
fi

echo ""
echo "Test 3: Testing version_compare() with database versions..."
if version_compare "10.11.6" ">=" "10.11.0"; then
  echo "✓ version_compare: 10.11.6 >= 10.11.0 (correct)"
else
  echo "✗ version_compare: 10.11.6 >= 10.11.0 (failed)"
  exit 1
fi

if version_compare "10.6.18" ">=" "10.11.0"; then
  echo "✗ version_compare: 10.6.18 >= 10.11.0 (should be false)"
  exit 1
else
  echo "✓ version_compare: 10.6.18 < 10.11.0 (correct)"
fi

if version_compare "8.4.0" ">=" "8.4.0"; then
  echo "✓ version_compare: 8.4.0 >= 8.4.0 (correct)"
else
  echo "✗ version_compare: 8.4.0 >= 8.4.0 (failed)"
  exit 1
fi

echo ""
echo "Test 4: Testing get_repository_database_version()..."
# This test may fail if not run on a system with apt-cache
if command -v apt-cache &>/dev/null; then
  repo_version=$(get_repository_database_version "mariadb-server" 2>/dev/null || echo "")
  if [[ -n "$repo_version" ]]; then
    echo "✓ get_repository_database_version() returned: $repo_version"
  else
    echo "⚠ get_repository_database_version() returned empty (may be expected if package not in cache)"
  fi
else
  echo "⚠ apt-cache not available, skipping repository version test"
fi

echo ""
echo "=========================================="
echo "All basic function tests passed!"
echo "=========================================="
echo ""
echo "Note: Full integration tests (add_mariadb_repository, install_compatible_database,"
echo "      verify_database_version) require root privileges and will be tested during"
echo "      actual installation scenarios."
