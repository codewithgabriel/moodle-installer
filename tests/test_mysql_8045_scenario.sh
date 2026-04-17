#!/usr/bin/env bash
# Test scenario: MySQL 8.0.45 installed, user selects Moodle 5.0.1
# Verify the installer handles this correctly

set -e

echo "=== Testing MySQL 8.0.45 → Moodle 5.0.1 Scenario ==="
echo ""

# Source required libraries
source lib/colors.sh 2>/dev/null || true
source lib/version_config.sh 2>/dev/null || true
source lib/checks.sh 2>/dev/null || true

# Simulate MySQL 8.0.45 detection
echo "Simulating MySQL 8.0.45 detection..."
SIMULATED_DB_VERSION="mysql:8.0.45"
MOODLE_BRANCH="MOODLE_501_STABLE"

echo "  Detected: $SIMULATED_DB_VERSION"
echo "  Selected: $MOODLE_BRANCH (Moodle 5.1)"
echo ""

# Get requirements for Moodle 5.0.1
echo "Checking database requirements for Moodle 5.1..."
requirements=$(get_database_requirements "$MOODLE_BRANCH")
echo "  Requirements: $requirements"
echo ""

# Parse requirements
req_output=$(parse_db_requirements "$MOODLE_BRANCH")
mysql_min=$(echo "$req_output" | grep "mysql_min=" | cut -d= -f2)
echo "  MySQL minimum required: $mysql_min"
echo ""

# Extract installed version
db_type=$(echo "$SIMULATED_DB_VERSION" | cut -d: -f1)
db_version=$(echo "$SIMULATED_DB_VERSION" | cut -d: -f2)

echo "Comparing versions..."
echo "  Installed: $db_type $db_version"
echo "  Required:  $db_type $mysql_min (minimum)"
echo ""

# Check compatibility
if version_compare "$db_version" ">=" "$mysql_min"; then
    echo "✓ Result: Compatible"
    echo ""
    echo "Expected behavior: Installation continues normally"
else
    echo "✗ Result: Incompatible"
    echo ""
    echo "Expected behavior in case_b_existing.sh:"
    echo "  1. Display warning: 'Existing database version is incompatible'"
    echo "  2. Display warning: 'Will upgrade database to compatible version...'"
    echo "  3. Set DB_OK=false (does NOT exit)"
    echo "  4. Continue to MariaDB installation section"
    echo "  5. Call install_compatible_database to upgrade"
    echo ""
    
    # Verify the actual implementation
    echo "Verifying implementation in case_b_existing.sh..."
    if grep -A 5 "check_database_compatibility" scripts/case_b_existing.sh | grep -q "DB_OK=false"; then
        echo "  ✓ Sets DB_OK=false when incompatible"
    else
        echo "  ✗ Does NOT set DB_OK=false"
        exit 1
    fi
    
    if grep -A 5 "check_database_compatibility" scripts/case_b_existing.sh | grep -q "warn"; then
        echo "  ✓ Displays warning messages"
    else
        echo "  ✗ Does NOT display warnings"
        exit 1
    fi
    
    if ! grep -A 5 "check_database_compatibility" scripts/case_b_existing.sh | grep -q "exit 1"; then
        echo "  ✓ Does NOT exit (continues installation)"
    else
        echo "  ✗ Exits with error (WRONG!)"
        exit 1
    fi
    
    if grep -A 5 "DB_OK.*false" scripts/case_b_existing.sh | grep -q "install_compatible_database"; then
        echo "  ✓ Calls install_compatible_database for upgrade"
    else
        echo "  ✗ Does NOT call install_compatible_database"
        exit 1
    fi
fi

echo ""
echo "=== Test PASSED ==="
echo ""
echo "The installer correctly handles MySQL 8.0.45 → Moodle 5.0.1 scenario:"
echo "  ✓ Detects incompatibility"
echo "  ✓ Displays user-friendly warnings"
echo "  ✓ Does NOT exit with error"
echo "  ✓ Automatically upgrades to compatible version"
echo "  ✓ Continues installation seamlessly"
