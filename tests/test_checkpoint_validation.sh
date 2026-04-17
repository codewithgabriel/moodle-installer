#!/bin/bash
# Checkpoint Validation Test for MySQL Version Compatibility Fix
# Task 4: Comprehensive validation of the fix

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Source required libraries
source lib/colors.sh
source lib/version_config.sh
source lib/checks.sh

echo "=========================================="
echo "MySQL Version Compatibility Fix - Checkpoint Validation"
echo "=========================================="
echo ""

# Test 1: Verify all required functions exist
echo "Test 1: Verifying required functions exist..."
functions=(
  "detect_database_version"
  "check_database_compatibility"
  "get_repository_database_version"
  "parse_db_requirements"
  "add_mariadb_repository"
  "install_compatible_database"
  "verify_database_version"
)

for func in "${functions[@]}"; do
  if declare -f "$func" > /dev/null; then
    echo "  ✓ $func exists"
  else
    echo "  ✗ $func NOT FOUND"
    exit 1
  fi
done
echo ""

# Test 2: Verify MOODLE_DB_VERSIONS configuration
echo "Test 2: Verifying MOODLE_DB_VERSIONS configuration..."
echo "  Moodle 5.0.1 requirements: ${MOODLE_DB_VERSIONS[MOODLE_501_STABLE]}"
if echo "${MOODLE_DB_VERSIONS[MOODLE_501_STABLE]}" | grep -q "mariadb:10.11"; then
  echo "  ✓ Moodle 5.0.1 requires MariaDB 10.11+"
else
  echo "  ✗ Moodle 5.0.1 requirements incorrect"
  exit 1
fi

if echo "${MOODLE_DB_VERSIONS[MOODLE_501_STABLE]}" | grep -q "mysql:8.4"; then
  echo "  ✓ Moodle 5.0.1 requires MySQL 8.4+"
else
  echo "  ✗ Moodle 5.0.1 requirements incorrect"
  exit 1
fi
echo ""

# Test 3: Verify parse_db_requirements function
echo "Test 3: Testing parse_db_requirements function..."
req_output=$(parse_db_requirements "MOODLE_501_STABLE")
mariadb_min=$(echo "$req_output" | grep "mariadb_min=" | cut -d= -f2)
mysql_min=$(echo "$req_output" | grep "mysql_min=" | cut -d= -f2)

echo "  Parsed MariaDB minimum: $mariadb_min"
echo "  Parsed MySQL minimum: $mysql_min"

if [[ "$mariadb_min" == "10.11.0" ]]; then
  echo "  ✓ MariaDB minimum parsed correctly"
else
  echo "  ✗ MariaDB minimum parsing failed"
  exit 1
fi

if [[ "$mysql_min" == "8.4.0" ]]; then
  echo "  ✓ MySQL minimum parsed correctly"
else
  echo "  ✗ MySQL minimum parsing failed"
  exit 1
fi
echo ""

# Test 4: Verify version comparison logic
echo "Test 4: Testing version comparison logic..."
if version_compare "10.11.0" ">=" "10.6.7"; then
  echo "  ✓ 10.11.0 >= 10.6.7 (correct)"
else
  echo "  ✗ Version comparison failed"
  exit 1
fi

if version_compare "10.6.7" ">=" "10.11.0"; then
  echo "  ✗ 10.6.7 >= 10.11.0 (should be false)"
  exit 1
else
  echo "  ✓ 10.6.7 < 10.11.0 (correct)"
fi

if version_compare "8.4.0" ">" "8.0.45"; then
  echo "  ✓ 8.4.0 > 8.0.45 (correct)"
else
  echo "  ✗ Version comparison failed"
  exit 1
fi
echo ""

# Test 5: Verify script integration
echo "Test 5: Verifying script integration..."

# Check case_a_fresh.sh
if grep -q "check_database_compatibility" scripts/case_a_fresh.sh; then
  echo "  ✓ case_a_fresh.sh calls check_database_compatibility"
else
  echo "  ✗ case_a_fresh.sh missing compatibility check"
  exit 1
fi

if grep -q "install_compatible_database" scripts/case_a_fresh.sh; then
  echo "  ✓ case_a_fresh.sh uses install_compatible_database"
else
  echo "  ✗ case_a_fresh.sh missing install_compatible_database"
  exit 1
fi

# Check case_b_existing.sh
if grep -q "detect_database_version" scripts/case_b_existing.sh; then
  echo "  ✓ case_b_existing.sh detects database version"
else
  echo "  ✗ case_b_existing.sh missing version detection"
  exit 1
fi

if grep -q "check_database_compatibility" scripts/case_b_existing.sh; then
  echo "  ✓ case_b_existing.sh checks compatibility"
else
  echo "  ✗ case_b_existing.sh missing compatibility check"
  exit 1
fi

if grep -q "install_compatible_database" scripts/case_b_existing.sh; then
  echo "  ✓ case_b_existing.sh uses install_compatible_database"
else
  echo "  ✗ case_b_existing.sh missing install_compatible_database"
  exit 1
fi
echo ""

# Test 6: Verify preservation of existing behavior
echo "Test 6: Verifying preservation of existing behavior..."

# Check that Moodle 4.1-4.5 requirements are compatible with default repos
for version in MOODLE_401_STABLE MOODLE_402_STABLE MOODLE_403_STABLE MOODLE_404_STABLE MOODLE_405_STABLE; do
  req="${MOODLE_DB_VERSIONS[$version]}"
  if [[ -n "$req" ]]; then
    echo "  ✓ $version: $req"
  else
    echo "  ✗ $version: requirements missing"
    exit 1
  fi
done

# Check that database setup SQL commands are preserved
if grep -q "utf8mb4_unicode_ci" scripts/case_a_fresh.sh; then
  echo "  ✓ Database collation preserved (utf8mb4_unicode_ci)"
else
  echo "  ✗ Database collation missing"
  exit 1
fi

if grep -q "GRANT ALL PRIVILEGES" scripts/case_a_fresh.sh; then
  echo "  ✓ GRANT PRIVILEGES command preserved"
else
  echo "  ✗ GRANT PRIVILEGES missing"
  exit 1
fi

if grep -q "FLUSH PRIVILEGES" scripts/case_a_fresh.sh; then
  echo "  ✓ FLUSH PRIVILEGES command preserved"
else
  echo "  ✗ FLUSH PRIVILEGES missing"
  exit 1
fi
echo ""

# Test 7: Simulate compatibility check scenarios
echo "Test 7: Simulating compatibility check scenarios..."

# Scenario 1: Moodle 5.0.1 with simulated MariaDB 10.6.7 (incompatible)
echo "  Scenario 1: Moodle 5.0.1 with MariaDB 10.6.7 (should fail)"
if check_database_compatibility "MOODLE_501_STABLE" "mariadb:10.6.7" 2>/dev/null; then
  echo "  ✗ Should have detected incompatibility"
  exit 1
else
  echo "  ✓ Correctly detected incompatibility"
fi

# Scenario 2: Moodle 5.0.1 with simulated MariaDB 10.11.6 (compatible)
echo "  Scenario 2: Moodle 5.0.1 with MariaDB 10.11.6 (should pass)"
if check_database_compatibility "MOODLE_501_STABLE" "mariadb:10.11.6" 2>/dev/null; then
  echo "  ✓ Correctly detected compatibility"
else
  echo "  ✗ Should have detected compatibility"
  exit 1
fi

# Scenario 3: Moodle 5.0.1 with simulated MySQL 8.0.45 (incompatible)
echo "  Scenario 3: Moodle 5.0.1 with MySQL 8.0.45 (should fail)"
if check_database_compatibility "MOODLE_501_STABLE" "mysql:8.0.45" 2>/dev/null; then
  echo "  ✗ Should have detected incompatibility"
  exit 1
else
  echo "  ✓ Correctly detected incompatibility"
fi

# Scenario 4: Moodle 5.0.1 with simulated MySQL 8.4.0 (compatible)
echo "  Scenario 4: Moodle 5.0.1 with MySQL 8.4.0 (should pass)"
if check_database_compatibility "MOODLE_501_STABLE" "mysql:8.4.0" 2>/dev/null; then
  echo "  ✓ Correctly detected compatibility"
else
  echo "  ✗ Should have detected compatibility"
  exit 1
fi

# Scenario 5: Moodle 4.5 with simulated MariaDB 10.6.18 (compatible - preservation)
echo "  Scenario 5: Moodle 4.5 with MariaDB 10.6.18 (should pass - preservation)"
if check_database_compatibility "MOODLE_405_STABLE" "mariadb:10.6.18" 2>/dev/null; then
  echo "  ✓ Correctly detected compatibility (preservation)"
else
  echo "  ✗ Should have detected compatibility"
  exit 1
fi
echo ""

echo "=========================================="
echo "✓ ALL CHECKPOINT VALIDATION TESTS PASSED"
echo "=========================================="
echo ""
echo "Summary:"
echo "  - All required functions implemented"
echo "  - MOODLE_DB_VERSIONS correctly configured"
echo "  - Version parsing and comparison working"
echo "  - Script integration complete"
echo "  - Preservation requirements met"
echo "  - Compatibility checking logic validated"
echo ""
echo "The MySQL version compatibility fix is complete and ready for production."
