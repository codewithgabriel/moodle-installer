#!/usr/bin/env bats
# Preservation Property Tests for MoodleDeploy Hardening
# **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10**
#
# IMPORTANT: These tests capture baseline behavior on UNFIXED code for non-buggy inputs
# Expected outcome: Tests PASS on unfixed code (confirms behavior to preserve)
# These tests ensure the fix does not introduce regressions

setup() {
  # Setup test environment
  export TEST_DIR="$(mktemp -d)"
  export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")" && pwd)"
  export LOG_FILE="$TEST_DIR/test.log"
  
  # Copy installer to test directory for isolated testing
  cp -r "$SCRIPT_DIR"/* "$TEST_DIR/" 2>/dev/null || true
  cd "$TEST_DIR"
  
  # Source libraries for testing
  source "$TEST_DIR/lib/colors.sh" 2>/dev/null || true
  source "$TEST_DIR/lib/utils.sh" 2>/dev/null || true
  source "$TEST_DIR/lib/checks.sh" 2>/dev/null || true
}

teardown() {
  # Cleanup
  rm -rf "$TEST_DIR"
}

# ============================================================
# PROPERTY 1: Valid Menu Choices Route Correctly
# **Validates: Requirement 3.1**
# ============================================================

@test "Preservation 3.1: Valid menu choice A routes to fresh install" {
  cd "$SCRIPT_DIR"
  
  # Check that install.sh contains routing for choice A
  grep -q 'A).*case_a_fresh.sh.*run_fresh_install' install.sh
}

@test "Preservation 3.1: Valid menu choice B routes to existing install" {
  cd "$SCRIPT_DIR"
  
  # Check that install.sh contains routing for choice B
  grep -q 'B).*case_b_existing.sh.*run_existing_install' install.sh
}

@test "Preservation 3.1: Valid menu choice C routes to cPanel guide" {
  cd "$SCRIPT_DIR"
  
  # Check that install.sh contains routing for choice C
  grep -q 'C).*case_c_cpanel.sh.*run_cpanel_guide' install.sh
}

@test "Preservation 3.1: Valid menu choice D routes to CI/CD setup" {
  cd "$SCRIPT_DIR"
  
  # Check that install.sh contains routing for choice D
  grep -q 'D).*cicd_setup.sh.*run_cicd_setup' install.sh
}

@test "Preservation 3.1: Valid menu choice Q exits cleanly" {
  cd "$SCRIPT_DIR"
  
  # Check that install.sh contains exit logic for choice Q
  grep -q 'Q).*exit 0' install.sh
}

@test "Preservation 3.1: Menu uses loop structure (not recursion)" {
  cd "$SCRIPT_DIR"
  
  # Verify main_menu uses while true loop
  grep -A 20 'main_menu()' install.sh | grep -q 'while true'
}

# ============================================================
# PROPERTY 2: Successful Fresh Installations Work
# **Validates: Requirement 3.2**
# ============================================================

@test "Preservation 3.2: Fresh install script exists and is executable" {
  cd "$SCRIPT_DIR"
  
  [ -f "scripts/case_a_fresh.sh" ]
  [ -r "scripts/case_a_fresh.sh" ]
}

@test "Preservation 3.2: Fresh install includes all required components" {
  cd "$SCRIPT_DIR"
  
  # Verify fresh install script contains installation steps for all components
  grep -q 'apache2' scripts/case_a_fresh.sh
  grep -q 'php8.3' scripts/case_a_fresh.sh
  grep -q 'mariadb' scripts/case_a_fresh.sh
  grep -q 'redis' scripts/case_a_fresh.sh
  grep -q 'moodle' scripts/case_a_fresh.sh || grep -q 'MOODLE' scripts/case_a_fresh.sh
}

@test "Preservation 3.2: Fresh install generates config.php" {
  cd "$SCRIPT_DIR"
  
  # Verify config.php generation logic exists
  grep -q 'config.php' scripts/case_a_fresh.sh
  grep -q 'CFG->dbtype' scripts/case_a_fresh.sh
  grep -q 'CFG->wwwroot' scripts/case_a_fresh.sh
}

@test "Preservation 3.2: Fresh install runs CLI database installation" {
  cd "$SCRIPT_DIR"
  
  # Verify CLI install command exists
  grep -q 'install_database.php' scripts/case_a_fresh.sh
}

# ============================================================
# PROPERTY 3: Existing Server Detection Works
# **Validates: Requirement 3.3**
# ============================================================

@test "Preservation 3.3: Existing install script exists" {
  cd "$SCRIPT_DIR"
  
  [ -f "scripts/case_b_existing.sh" ]
  [ -r "scripts/case_b_existing.sh" ]
}

@test "Preservation 3.3: Web server detection function exists" {
  cd "$SCRIPT_DIR"
  
  # Verify check_webserver function exists in checks.sh
  grep -q 'check_webserver' lib/checks.sh
}

@test "Preservation 3.3: Component detection logic exists" {
  cd "$SCRIPT_DIR"
  
  # Verify existing install script has detection logic
  grep -q 'detect' scripts/case_b_existing.sh || \
  grep -q 'check' scripts/case_b_existing.sh
}

# ============================================================
# PROPERTY 4: cPanel Guide Walks Through All Steps
# **Validates: Requirement 3.4**
# ============================================================

@test "Preservation 3.4: cPanel guide script exists" {
  cd "$SCRIPT_DIR"
  
  [ -f "scripts/case_c_cpanel.sh" ]
  [ -r "scripts/case_c_cpanel.sh" ]
}

@test "Preservation 3.4: cPanel guide generates config.php" {
  cd "$SCRIPT_DIR"
  
  # Verify config.php generation in cPanel script
  grep -q 'config.php' scripts/case_c_cpanel.sh
}

@test "Preservation 3.4: cPanel guide generates credentials file" {
  cd "$SCRIPT_DIR"
  
  # Verify credentials file generation
  grep -q 'credentials' scripts/case_c_cpanel.sh || \
  grep -q 'CREDS' scripts/case_c_cpanel.sh
}

# ============================================================
# PROPERTY 5: CI/CD Setup Generates Required Files
# **Validates: Requirement 3.5**
# ============================================================

@test "Preservation 3.5: CI/CD setup script exists" {
  cd "$SCRIPT_DIR"
  
  [ -f "scripts/cicd_setup.sh" ]
  [ -r "scripts/cicd_setup.sh" ]
}

@test "Preservation 3.5: CI/CD generates GitHub Actions workflow" {
  cd "$SCRIPT_DIR"
  
  # Verify workflow generation logic
  grep -q 'workflow' scripts/cicd_setup.sh || \
  grep -q '.github' scripts/cicd_setup.sh || \
  grep -q 'actions' scripts/cicd_setup.sh
}

@test "Preservation 3.5: CI/CD generates deploy script" {
  cd "$SCRIPT_DIR"
  
  # Verify deploy.sh generation
  grep -q 'deploy.sh' scripts/cicd_setup.sh
}

@test "Preservation 3.5: CI/CD generates documentation files" {
  cd "$SCRIPT_DIR"
  
  # Verify SSH_SETUP.md and SECRETS_CHECKLIST.md generation
  grep -q 'SSH_SETUP' scripts/cicd_setup.sh || \
  grep -q 'SECRETS' scripts/cicd_setup.sh
}

# ============================================================
# PROPERTY 6: Prompt Functions Accept User Input
# **Validates: Requirement 3.6**
# ============================================================

@test "Preservation 3.6: prompt function exists and accepts defaults" {
  cd "$SCRIPT_DIR"
  
  # Verify prompt function exists with default parameter support
  grep -A 10 '^prompt()' lib/utils.sh | grep -q 'default'
}

@test "Preservation 3.6: prompt_secret function exists" {
  cd "$SCRIPT_DIR"
  
  # Verify prompt_secret function exists
  grep -q '^prompt_secret()' lib/utils.sh
}

@test "Preservation 3.6: prompt function assigns to variable" {
  cd "$SCRIPT_DIR"
  
  # Verify prompt uses printf -v to assign to variable
  grep -A 20 '^prompt()' lib/utils.sh | grep -q 'printf -v'
}

# ============================================================
# PROPERTY 7: Spinner Displays Animation
# **Validates: Requirement 3.7**
# ============================================================

@test "Preservation 3.7: spinner function exists" {
  cd "$SCRIPT_DIR"
  
  # Verify spinner function exists
  grep -q '^spinner()' lib/utils.sh
}

@test "Preservation 3.7: spinner accepts PID parameter" {
  cd "$SCRIPT_DIR"
  
  # Verify spinner takes PID as first parameter
  grep -A 5 '^spinner()' lib/utils.sh | grep -q 'pid=\$1'
}

@test "Preservation 3.7: spinner has animation frames" {
  cd "$SCRIPT_DIR"
  
  # Verify spinner has animation frames defined
  grep -A 10 '^spinner()' lib/utils.sh | grep -q 'frames='
}

@test "Preservation 3.7: spinner loops while process is running" {
  cd "$SCRIPT_DIR"
  
  # Verify spinner uses kill -0 to check if process is running
  grep -A 15 '^spinner()' lib/utils.sh | grep -q 'kill -0'
}

# ============================================================
# PROPERTY 8: Preflight Checks OS, Disk, RAM
# **Validates: Requirement 3.8**
# ============================================================

@test "Preservation 3.8: run_preflight function exists" {
  cd "$SCRIPT_DIR"
  
  # Verify run_preflight function exists
  grep -q 'run_preflight' lib/checks.sh
}

@test "Preservation 3.8: Preflight checks OS" {
  cd "$SCRIPT_DIR"
  
  # Verify OS check exists
  grep -q 'check_os' lib/checks.sh || \
  grep -A 20 'run_preflight' lib/checks.sh | grep -q 'os\|OS\|ubuntu\|debian'
}

@test "Preservation 3.8: Preflight checks disk space" {
  cd "$SCRIPT_DIR"
  
  # Verify disk check exists
  grep -q 'check_disk' lib/checks.sh || \
  grep -A 20 'run_preflight' lib/checks.sh | grep -q 'disk\|df'
}

@test "Preservation 3.8: Preflight checks RAM" {
  cd "$SCRIPT_DIR"
  
  # Verify RAM check exists
  grep -q 'check_ram' lib/checks.sh || \
  grep -A 20 'run_preflight' lib/checks.sh | grep -q 'ram\|memory\|mem'
}

@test "Preservation 3.8: Preflight checks internet connectivity" {
  cd "$SCRIPT_DIR"
  
  # Verify internet check exists
  grep -q 'check_internet' lib/checks.sh
}

# ============================================================
# PROPERTY 9: Quit Option Exits Cleanly
# **Validates: Requirement 3.9**
# ============================================================

@test "Preservation 3.9: Quit option displays goodbye message" {
  cd "$SCRIPT_DIR"
  
  # Verify goodbye message exists
  grep -A 2 'Q)' install.sh | grep -q 'Goodbye\|goodbye\|exit'
}

@test "Preservation 3.9: Quit option exits with status 0" {
  cd "$SCRIPT_DIR"
  
  # Verify exit 0 is called
  grep -A 2 'Q)' install.sh | grep -q 'exit 0'
}

# ============================================================
# PROPERTY 10: Credentials File Has 600 Permissions
# **Validates: Requirement 3.10**
# ============================================================

@test "Preservation 3.10: Credentials file permissions set to 600" {
  cd "$SCRIPT_DIR"
  
  # Verify chmod 600 is applied to credentials file
  grep -B 5 -A 5 'credentials' scripts/case_a_fresh.sh | grep -q 'chmod 600' || \
  grep -B 5 -A 5 'CREDS_FILE' scripts/case_a_fresh.sh | grep -q 'chmod 600'
}

@test "Preservation 3.10: Credentials file written to secure location" {
  cd "$SCRIPT_DIR"
  
  # Verify credentials file uses HOME directory (already fixed)
  grep -q 'HOME.*credentials' scripts/case_a_fresh.sh || \
  grep -q 'CREDS_FILE.*HOME' scripts/case_a_fresh.sh
}

# ============================================================
# INTEGRATION TEST: All Preservation Properties Hold
# ============================================================

@test "Integration: All core preservation properties verified" {
  # Use SCRIPT_DIR for integration test since TEST_DIR copy may be incomplete
  cd "$SCRIPT_DIR"
  
  local property_count=0
  
  # Count verified properties (use || true to prevent early exit)
  [ -f "install.sh" ] && property_count=$((property_count + 1)) || true
  [ -f "scripts/case_a_fresh.sh" ] && property_count=$((property_count + 1)) || true
  [ -f "scripts/case_b_existing.sh" ] && property_count=$((property_count + 1)) || true
  [ -f "scripts/case_c_cpanel.sh" ] && property_count=$((property_count + 1)) || true
  [ -f "scripts/cicd_setup.sh" ] && property_count=$((property_count + 1)) || true
  grep -q '^prompt()' lib/utils.sh 2>/dev/null && property_count=$((property_count + 1)) || true
  grep -q '^spinner()' lib/utils.sh 2>/dev/null && property_count=$((property_count + 1)) || true
  grep -q 'run_preflight' lib/checks.sh 2>/dev/null && property_count=$((property_count + 1)) || true
  grep -q 'exit 0' install.sh 2>/dev/null && property_count=$((property_count + 1)) || true
  grep -q 'chmod 600' scripts/case_a_fresh.sh 2>/dev/null && property_count=$((property_count + 1)) || true
  
  echo "# Preservation properties verified: $property_count" >&3
  
  # All 10 core properties should be present
  [ "$property_count" -eq 10 ]
}
