#!/usr/bin/env bats
# Bug Condition Exploration Test for Production Critical Fixes
# **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 1.10, 1.11, 1.12, 1.13, 1.14, 1.15**
#
# CRITICAL: This test MUST FAIL on unfixed code - failure confirms the bugs exist
# DO NOT attempt to fix the test or the code when it fails
# This test encodes the expected behavior - it will validate the fix when it passes after implementation

setup() {
  # Setup test environment
  export TEST_DIR="$(mktemp -d)"
  export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")" && pwd)"
  export LOG_FILE="$TEST_DIR/test.log"
  
  # Copy installer to test directory for isolated testing
  cp -r "$SCRIPT_DIR"/* "$TEST_DIR/" 2>/dev/null || true
  cd "$TEST_DIR"
}

teardown() {
  # Cleanup
  rm -rf "$TEST_DIR"
}

# ============================================================
# CRITICAL BUGS - Data Loss & Installation Failures (5 bugs)
# ============================================================

@test "Bug 1.1: Strict mode should NOT cause silent aborts on expected failures" {
  # **Validates: Requirement 1.1, 2.1**
  # Expected: Commands with expected non-zero exits should use set +e or || true
  # Actual (unfixed): Inherited set -euo pipefail causes silent aborts
  
  cd "$SCRIPT_DIR"
  
  # Check if install.sh has set -euo pipefail at the top
  # This WILL be present on unfixed code
  grep -q "^set -euo pipefail" install.sh
  
  # Check if lib/checks.sh functions wrap detection commands with set +e
  # This will FAIL on unfixed code (no set +e wrappers)
  grep -A 5 "check_webserver()" lib/checks.sh | grep -q "set +e" || \
  grep -A 5 "check_php_version()" lib/checks.sh | grep -q "set +e" || \
  grep -A 5 "check_mariadb()" lib/checks.sh | grep -q "set +e"
}

@test "Bug 1.2: Re-run should require confirmation before data loss" {
  # **Validates: Requirement 1.2, 2.2**
  # Expected: handle_moodle_dir checks for existing database and requires confirmation
  # Actual (unfixed): No database check, no double confirmation for DELETE
  
  cd "$SCRIPT_DIR"
  
  # Check if handle_moodle_dir checks for existing database
  # This will FAIL on unfixed code
  grep -A 20 "handle_moodle_dir()" lib/utils.sh | grep -q "mysql_root.*USE" && \
  grep -A 20 "handle_moodle_dir()" lib/utils.sh | grep -q "DELETE.*database"
}

@test "Bug 1.3: Disk space should be checked before installation" {
  # **Validates: Requirement 1.3, 2.3**
  # Expected: run_preflight calls check_moodle_disk_space
  # Actual (unfixed): No disk space check in preflight
  
  cd "$SCRIPT_DIR"
  
  # Check if run_preflight calls check_moodle_disk_space
  # This will FAIL on unfixed code
  grep -A 10 "run_preflight()" lib/checks.sh | grep -q "check_moodle_disk_space"
}

@test "Bug 1.4: Credentials file should be secure and outside web root" {
  # **Validates: Requirement 1.4, 2.4**
  # Expected: Credentials written to $HOME with chmod 600 and security warning
  # Actual (unfixed): Written to $SCRIPT_DIR with default permissions
  
  cd "$SCRIPT_DIR"
  
  # Check if credentials are written to $HOME instead of $SCRIPT_DIR
  # This will FAIL on unfixed code (uses $SCRIPT_DIR or current directory)
  ! grep -q 'CREDS_FILE=.*\$SCRIPT_DIR.*credentials' scripts/case_a_fresh.sh && \
  grep -q 'CREDS_FILE=.*\$HOME.*credentials' scripts/case_a_fresh.sh && \
  grep -A 5 'cat.*CREDS_FILE' scripts/case_a_fresh.sh | grep -q "SECURITY WARNING"
}

@test "Bug 1.5: Log files should be in .gitignore" {
  # **Validates: Requirement 1.5, 2.5**
  # Expected: moodle-install.log and *-credentials.txt in .gitignore
  # Actual (unfixed): Not in .gitignore, can be committed
  
  cd "$SCRIPT_DIR"
  
  # Check if .gitignore contains log and credential patterns
  # This will FAIL on unfixed code
  grep -q "moodle-install.log" .gitignore && \
  grep -q "credentials.txt" .gitignore
}

# ============================================================
# HIGH-RISK ISSUES - Reliability & Security (6 bugs)
# ============================================================

@test "Bug 1.6: Rollback mechanism should exist for failed installations" {
  # **Validates: Requirement 1.6, 2.6**
  # Expected: trap 'rollback_on_error' ERR and rollback log creation
  # Actual (unfixed): No rollback mechanism
  
  cd "$SCRIPT_DIR"
  
  # Check for rollback mechanism in case_a_fresh.sh
  # This will FAIL on unfixed code
  grep -q "trap.*rollback" scripts/case_a_fresh.sh && \
  grep -q "rollback.*log" scripts/case_a_fresh.sh
}

@test "Bug 1.7: Git clone should have integrity verification option" {
  # **Validates: Requirement 1.7, 2.7**
  # Expected: VERIFY_GIT_INTEGRITY option and git verify-commit
  # Actual (unfixed): No integrity verification
  
  cd "$SCRIPT_DIR"
  
  # Check if fetch_moodle has integrity verification
  # This will FAIL on unfixed code
  grep -A 10 "fetch_moodle()" lib/utils.sh | grep -q "VERIFY_GIT_INTEGRITY" && \
  grep -A 10 "fetch_moodle()" lib/utils.sh | grep -q "verify-commit"
}

@test "Bug 1.8: DEBIAN_FRONTEND should be set for CI environments" {
  # **Validates: Requirement 1.8, 2.8**
  # Expected: export DEBIAN_FRONTEND=noninteractive at start of installation
  # Actual (unfixed): Not set globally, causes hangs
  
  cd "$SCRIPT_DIR"
  
  # Check if DEBIAN_FRONTEND is exported in case_a_fresh.sh
  # This will FAIL on unfixed code (only used in some apt-get calls, not exported)
  grep -q "export DEBIAN_FRONTEND=noninteractive" scripts/case_a_fresh.sh
}

@test "Bug 1.9: OS detection should use correct PHP repository for Debian" {
  # **Validates: Requirement 1.9, 2.9**
  # Expected: Check $ID and use Sury repo for Debian, PPA for Ubuntu
  # Actual (unfixed): Always uses Ubuntu PPA, fails on Debian
  
  cd "$SCRIPT_DIR"
  
  # Check if case_a_fresh.sh detects OS before adding PPA
  # This will FAIL on unfixed code
  grep -B 5 "ppa:ondrej/php" scripts/case_a_fresh.sh | grep -q "source /etc/os-release" && \
  grep -A 5 "ppa:ondrej/php" scripts/case_a_fresh.sh | grep -q 'ID.*debian' && \
  grep -A 5 "ppa:ondrej/php" scripts/case_a_fresh.sh | grep -q "sury"
}

@test "Bug 1.10: Moodledata should have secure permissions (750) and .htaccess" {
  # **Validates: Requirement 1.10, 2.10**
  # Expected: chmod 750, ownership www-data:www-data, .htaccess with deny
  # Actual (unfixed): Insufficient hardening
  
  cd "$SCRIPT_DIR"
  
  # Check if moodledata is created with 750 permissions
  # This will FAIL on unfixed code (uses 770)
  grep -A 5 "MOODLE_DATA" scripts/case_a_fresh.sh | grep -q "chmod 750" && \
  grep -A 5 "MOODLE_DATA" scripts/case_a_fresh.sh | grep -q ".htaccess" && \
  grep -A 5 "MOODLE_DATA" scripts/case_a_fresh.sh | grep -q "Require all denied"
}

@test "Bug 1.11: Prompt commands should have timeout to prevent hangs" {
  # **Validates: Requirement 1.11, 2.11**
  # Expected: read -t 300 in prompt functions
  # Actual (unfixed): No timeout, infinite hangs possible
  
  cd "$SCRIPT_DIR"
  
  # Check if prompt function uses read -t
  # This will FAIL on unfixed code
  grep -A 5 "^prompt()" lib/utils.sh | grep -q "read -t" || \
  grep -A 5 "^prompt_secret()" lib/utils.sh | grep -q "read -t"
}

# ============================================================
# SECURITY VULNERABILITIES (4 bugs)
# ============================================================

@test "Bug 1.12: Passwords should use /dev/urandom not \$RANDOM" {
  # **Validates: Requirement 1.12, 2.12**
  # Expected: generate_password uses /dev/urandom
  # Actual (unfixed): Uses $RANDOM (weak)
  
  cd "$SCRIPT_DIR"
  
  # Check if generate_password uses /dev/urandom
  # This will FAIL on unfixed code (uses $RANDOM)
  grep -A 3 "generate_password()" lib/utils.sh | grep -q "/dev/urandom"
}

@test "Bug 1.13: MySQL root access should be verified after setup" {
  # **Validates: Requirement 1.13, 2.13**
  # Expected: verify_mysql_root_access function exists and is called
  # Actual (unfixed): No verification
  
  cd "$SCRIPT_DIR"
  
  # Check if verify_mysql_root_access function exists
  # This will FAIL on unfixed code
  grep -q "verify_mysql_root_access()" lib/checks.sh && \
  grep -q "verify_mysql_root_access" scripts/case_a_fresh.sh
}

@test "Bug 1.14: Firewall should be configured after installation" {
  # **Validates: Requirement 1.14, 2.14**
  # Expected: configure_firewall function exists and enables ufw
  # Actual (unfixed): No firewall configuration
  
  cd "$SCRIPT_DIR"
  
  # Check if configure_firewall function exists
  # This will FAIL on unfixed code
  grep -q "configure_firewall()" lib/checks.sh && \
  grep -q "ufw.*enable" lib/checks.sh && \
  grep -q "configure_firewall" scripts/case_a_fresh.sh
}

@test "Bug 1.15: CI/CD templates should have secret warnings" {
  # **Validates: Requirement 1.15, 2.15**
  # Expected: Generated files have WARNING comments about secrets
  # Actual (unfixed): No warnings, easy to commit secrets
  
  cd "$SCRIPT_DIR"
  
  # Check if cicd_setup.sh adds warnings to generated files
  # This will FAIL on unfixed code
  grep -A 10 "deploy.yml" scripts/cicd_setup.sh | grep -q "WARNING.*secrets" && \
  grep -A 10 "deploy.sh" scripts/cicd_setup.sh | grep -q "WARNING"
}

# ============================================================
# INTEGRATION TEST: Count remaining bugs
# ============================================================

@test "Integration: All 15 production critical bugs should be fixed" {
  # This test counts how many bugs are still present
  # On unfixed code, we expect ALL 15 bugs to be present
  # On fixed code, we expect 0 bugs
  
  cd "$SCRIPT_DIR"
  
  local bug_count=0
  
  # Bug 1.1: Strict mode without set +e wrappers
  if grep -q "^set -euo pipefail" install.sh && \
     ! grep -A 5 "check_webserver()" lib/checks.sh | grep -q "set +e"; then
    ((bug_count++))
  fi
  
  # Bug 1.2: No database confirmation
  if ! grep -A 20 "handle_moodle_dir()" lib/utils.sh | grep -q "mysql_root.*USE"; then
    ((bug_count++))
  fi
  
  # Bug 1.3: No disk space check in preflight
  if ! grep -A 10 "run_preflight()" lib/checks.sh | grep -q "check_moodle_disk_space"; then
    ((bug_count++))
  fi
  
  # Bug 1.4: Credentials not in $HOME
  if grep -q 'CREDS_FILE=.*\$SCRIPT_DIR' scripts/case_a_fresh.sh || \
     ! grep -q 'CREDS_FILE=.*\$HOME' scripts/case_a_fresh.sh; then
    ((bug_count++))
  fi
  
  # Bug 1.5: Logs not in .gitignore
  if ! grep -q "moodle-install.log" .gitignore; then
    ((bug_count++))
  fi
  
  # Bug 1.6: No rollback mechanism
  if ! grep -q "trap.*rollback" scripts/case_a_fresh.sh; then
    ((bug_count++))
  fi
  
  # Bug 1.7: No git integrity verification
  if ! grep -A 10 "fetch_moodle()" lib/utils.sh | grep -q "VERIFY_GIT_INTEGRITY"; then
    ((bug_count++))
  fi
  
  # Bug 1.8: DEBIAN_FRONTEND not exported
  if ! grep -q "export DEBIAN_FRONTEND=noninteractive" scripts/case_a_fresh.sh; then
    ((bug_count++))
  fi
  
  # Bug 1.9: No OS detection for PPA
  if ! grep -B 5 "ppa:ondrej/php" scripts/case_a_fresh.sh | grep -q "source /etc/os-release"; then
    ((bug_count++))
  fi
  
  # Bug 1.10: Moodledata not hardened with 750
  if ! grep -A 5 "MOODLE_DATA" scripts/case_a_fresh.sh | grep -q "chmod 750"; then
    ((bug_count++))
  fi
  
  # Bug 1.11: No timeout on prompts
  if ! grep -A 5 "^prompt()" lib/utils.sh | grep -q "read -t"; then
    ((bug_count++))
  fi
  
  # Bug 1.12: Password uses $RANDOM not /dev/urandom
  if ! grep -A 3 "generate_password()" lib/utils.sh | grep -q "/dev/urandom"; then
    ((bug_count++))
  fi
  
  # Bug 1.13: No MySQL verification
  if ! grep -q "verify_mysql_root_access()" lib/checks.sh; then
    ((bug_count++))
  fi
  
  # Bug 1.14: No firewall configuration
  if ! grep -q "configure_firewall()" lib/checks.sh; then
    ((bug_count++))
  fi
  
  # Bug 1.15: No CI/CD secret warnings
  if ! grep -A 10 "deploy.yml" scripts/cicd_setup.sh | grep -q "WARNING.*secrets"; then
    ((bug_count++))
  fi
  
  echo "# Production critical bugs found: $bug_count / 15" >&3
  
  # On fixed code, we expect 0 bugs remaining
  [ "$bug_count" -eq 0 ]
}
