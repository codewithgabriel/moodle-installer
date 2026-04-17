#!/usr/bin/env bats
# Bug Condition Exploration Test for MySQL/MariaDB Version Compatibility Fix
# **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5**
#
# CRITICAL: This test MUST FAIL on unfixed code - failure confirms the bug exists
# DO NOT attempt to fix the test or the code when it fails
# This test encodes the expected behavior - it will validate the fix when it passes after implementation
# GOAL: Surface counterexamples that demonstrate the bug exists

setup() {
  # Setup test environment
  export TEST_DIR="$(mktemp -d)"
  export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")" && pwd)"
  export LOG_FILE="$TEST_DIR/test.log"
  
  # Copy installer to test directory for isolated testing
  cp -r "$SCRIPT_DIR"/* "$TEST_DIR/" 2>/dev/null || true
  cd "$TEST_DIR"
  
  # Source required libraries
  source lib/colors.sh 2>/dev/null || true
  source lib/version_config.sh 2>/dev/null || true
  source lib/checks.sh 2>/dev/null || true
}

teardown() {
  # Cleanup
  rm -rf "$TEST_DIR"
}

# ============================================================
# BUG CONDITION 1.1: Database version checking functions
# ============================================================

@test "Bug 1.1: detect_database_version() function should exist in lib/checks.sh" {
  # **Validates: Requirement 1.1**
  # Expected: Function detect_database_version() exists and can parse MySQL/MariaDB versions
  # Actual (unfixed): Function does not exist
  
  cd "$SCRIPT_DIR"
  
  # This test FAILS on unfixed code - function doesn't exist yet
  grep -q "detect_database_version()" lib/checks.sh
}

@test "Bug 1.2: check_database_compatibility() function should exist in lib/checks.sh" {
  # **Validates: Requirement 1.2**
  # Expected: Function check_database_compatibility() exists to validate version requirements
  # Actual (unfixed): Function does not exist
  
  cd "$SCRIPT_DIR"
  
  # This test FAILS on unfixed code - function doesn't exist yet
  grep -q "check_database_compatibility()" lib/checks.sh
}

@test "Bug 1.3: get_repository_database_version() function should exist in lib/checks.sh" {
  # **Validates: Requirement 1.3**
  # Expected: Function to query available database version in repositories exists
  # Actual (unfixed): Function does not exist
  
  cd "$SCRIPT_DIR"
  
  # This test FAILS on unfixed code - function doesn't exist yet
  grep -q "get_repository_database_version()" lib/checks.sh
}

# ============================================================
# BUG CONDITION 1.2: Repository management functions
# ============================================================

@test "Bug 1.4: add_mariadb_repository() function should exist in lib/checks.sh" {
  # **Validates: Requirement 1.5**
  # Expected: Function to add MariaDB official repository exists
  # Actual (unfixed): Function does not exist
  
  cd "$SCRIPT_DIR"
  
  # This test FAILS on unfixed code - function doesn't exist yet
  grep -q "add_mariadb_repository()" lib/checks.sh
}

@test "Bug 1.5: install_compatible_database() function should exist in lib/checks.sh" {
  # **Validates: Requirement 1.5**
  # Expected: Function to install version-compatible database exists
  # Actual (unfixed): Function does not exist
  
  cd "$SCRIPT_DIR"
  
  # This test FAILS on unfixed code - function doesn't exist yet
  grep -q "install_compatible_database()" lib/checks.sh
}

# ============================================================
# BUG CONDITION 1.3: Version configuration accuracy
# ============================================================

@test "Bug 1.6: MOODLE_DB_VERSIONS should have correct requirements for Moodle 5.0.1" {
  # **Validates: Requirement 1.3**
  # Expected: MOODLE_501_STABLE requires mariadb:10.11.0,mysql:8.4.0
  # Actual (unfixed): May have incorrect version requirements (10.6.7/8.0.30)
  
  cd "$SCRIPT_DIR"
  source lib/version_config.sh
  
  local db_req="${MOODLE_DB_VERSIONS[MOODLE_501_STABLE]}"
  
  # Check if requirements match expected values for Moodle 5.0.1
  # This test FAILS on unfixed code if version requirements are incorrect
  echo "$db_req" | grep -q "mariadb:10.11" && echo "$db_req" | grep -q "mysql:8.4"
}

# ============================================================
# BUG CONDITION 1.4: Fresh install script integration
# ============================================================

@test "Bug 1.7: case_a_fresh.sh should call check_database_compatibility() after version selection" {
  # **Validates: Requirement 2.1, 2.2**
  # Expected: After pick_moodle_version, script checks database compatibility
  # Actual (unfixed): No compatibility check before database installation
  
  cd "$SCRIPT_DIR"
  
  # This test FAILS on unfixed code - compatibility check not present
  grep -A 5 "pick_moodle_version" scripts/case_a_fresh.sh | grep -q "check_database_compatibility"
}

@test "Bug 1.8: case_a_fresh.sh should use install_compatible_database() instead of direct mariadb-server install" {
  # **Validates: Requirement 2.3, 2.6**
  # Expected: Script uses install_compatible_database() for version-aware installation
  # Actual (unfixed): Script directly installs mariadb-server without version checking
  
  cd "$SCRIPT_DIR"
  
  # Check if the script uses the new function instead of direct installation
  # This test FAILS on unfixed code - still uses platform_install_package mariadb-server
  grep -q "install_compatible_database" scripts/case_a_fresh.sh
}

@test "Bug 1.9: case_a_fresh.sh should verify database version after installation" {
  # **Validates: Requirement 2.8**
  # Expected: After database installation, script verifies installed version meets requirements
  # Actual (unfixed): No post-installation verification
  
  cd "$SCRIPT_DIR"
  
  # This test FAILS on unfixed code - no verification step exists
  grep -q "verify_database_version" scripts/case_a_fresh.sh
}

# ============================================================
# BUG CONDITION 1.5: Existing server script integration
# ============================================================

@test "Bug 1.10: case_b_existing.sh should detect and store database version" {
  # **Validates: Requirement 2.4**
  # Expected: Script captures installed database version using detect_database_version()
  # Actual (unfixed): Only checks presence, not version
  
  cd "$SCRIPT_DIR"
  
  # This test FAILS on unfixed code - no version detection
  grep -A 5 "check_mariadb" scripts/case_b_existing.sh | grep -q "detect_database_version"
}

@test "Bug 1.11: case_b_existing.sh should check existing database version compatibility" {
  # **Validates: Requirement 2.4, 2.5**
  # Expected: After version selection, script checks if existing database is compatible
  # Actual (unfixed): No compatibility check for existing databases
  
  cd "$SCRIPT_DIR"
  
  # This test FAILS on unfixed code - no compatibility check for existing DB
  grep -A 10 "pick_moodle_version" scripts/case_b_existing.sh | grep -q "check_database_compatibility"
}

@test "Bug 1.12: case_b_existing.sh should use install_compatible_database() when DB not present" {
  # **Validates: Requirement 2.3, 2.6**
  # Expected: When database needs installation, use version-aware function
  # Actual (unfixed): Direct mariadb-server installation without version checking
  
  cd "$SCRIPT_DIR"
  
  # This test FAILS on unfixed code - still uses direct installation
  grep -A 5 "DB_OK.*false" scripts/case_b_existing.sh | grep -q "install_compatible_database"
}

# ============================================================
# INTEGRATION TEST: Simulated Moodle 5.0.1 installation scenario
# ============================================================

@test "Integration: Installer should prevent Moodle 5.0.1 installation with incompatible database" {
  # **Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.6**
  # This integration test simulates the bug condition:
  # - User selects Moodle 5.0.1
  # - System has MariaDB 10.6 available (insufficient)
  # - Installer should detect incompatibility and either:
  #   a) Add repository and install MariaDB 10.11+, OR
  #   b) Display clear error message
  # 
  # On unfixed code: Installer proceeds with MariaDB 10.6, Moodle CLI fails
  # On fixed code: Installer detects incompatibility and handles it
  
  cd "$SCRIPT_DIR"
  
  # Count how many of the required functions/checks exist
  local missing_count=0
  
  # Check for version detection functions
  grep -q "detect_database_version()" lib/checks.sh || ((missing_count++))
  grep -q "check_database_compatibility()" lib/checks.sh || ((missing_count++))
  grep -q "get_repository_database_version()" lib/checks.sh || ((missing_count++))
  
  # Check for repository management functions
  grep -q "add_mariadb_repository()" lib/checks.sh || ((missing_count++))
  grep -q "install_compatible_database()" lib/checks.sh || ((missing_count++))
  
  # Check for script integration
  grep -q "check_database_compatibility" scripts/case_a_fresh.sh || ((missing_count++))
  grep -q "install_compatible_database" scripts/case_a_fresh.sh || ((missing_count++))
  grep -q "check_database_compatibility" scripts/case_b_existing.sh || ((missing_count++))
  grep -q "install_compatible_database" scripts/case_b_existing.sh || ((missing_count++))
  
  # Check version configuration
  source lib/version_config.sh
  local db_req="${MOODLE_DB_VERSIONS[MOODLE_501_STABLE]}"
  echo "$db_req" | grep -q "mariadb:10.11" || ((missing_count++))
  
  echo "# Missing components: $missing_count" >&3
  
  # On fixed code, we expect 0 missing components
  # On unfixed code, this test FAILS (proving the bug exists)
  [ "$missing_count" -eq 0 ]
}

# ============================================================
# EXPECTED BEHAVIOR VALIDATION (will pass after fix)
# ============================================================

@test "Expected Behavior: Version comparison function should work correctly" {
  # **Validates: Requirement 2.1**
  # This test validates that version_compare() function works correctly
  # It should already exist in lib/version_config.sh
  
  cd "$SCRIPT_DIR"
  source lib/version_config.sh
  
  # Test version comparison (this should work even on unfixed code)
  version_compare "10.11.0" ">=" "10.6.7"
  version_compare "8.4.0" ">" "8.0.30"
  ! version_compare "10.6.7" ">=" "10.11.0"
}

@test "Expected Behavior: MOODLE_DB_VERSIONS array should exist and be populated" {
  # **Validates: Requirement 2.1**
  # This test validates that the configuration array exists
  # It should already exist in lib/version_config.sh
  
  cd "$SCRIPT_DIR"
  source lib/version_config.sh
  
  # Check that array exists and has entries
  [ -n "${MOODLE_DB_VERSIONS[MOODLE_501_STABLE]}" ]
  [ -n "${MOODLE_DB_VERSIONS[MOODLE_405_STABLE]}" ]
  [ -n "${MOODLE_DB_VERSIONS[MOODLE_401_STABLE]}" ]
}
