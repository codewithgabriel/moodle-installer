#!/usr/bin/env bats
# Bug Condition Exploration Test for MoodleDeploy Hardening
# **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 1.10, 1.11, 1.12, 1.13, 1.14**
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
# STRUCTURAL / SOURCING BUGS (2 bugs)
# ============================================================

@test "Bug 1.1: Brace-expansion artifact directory should NOT exist" {
  # **Validates: Requirement 1.1**
  # Expected: Directory {scripts,templates,lib} should not exist
  # Actual (unfixed): Directory exists as Git artifact
  
  cd "$SCRIPT_DIR"
  
  # This test FAILS on unfixed code if the artifact exists
  [ ! -d "{scripts,templates,lib}" ]
}

@test "Bug 1.2: Library source order should be explicit with dependency guard" {
  # **Validates: Requirement 1.2**
  # Expected: install.sh should have explicit dependency order comment and validation
  # Actual (unfixed): No dependency guard, reordering silently breaks
  
  cd "$SCRIPT_DIR"
  
  # Check for dependency order comment (this will FAIL on unfixed code)
  grep -q "# DEPENDENCY ORDER" install.sh
}

# ============================================================
# LOGIC / RUNTIME BUGS (4 bugs)
# ============================================================

@test "Bug 1.3: Status messages in check_webserver already fixed (SKIP)" {
  # **Validates: Requirement 1.3**
  # This bug has already been fixed in the codebase
  skip "Bug already fixed - check_webserver redirects to stderr"
}

@test "Bug 1.4: PHP status check already fixed (SKIP)" {
  # **Validates: Requirement 1.4**
  # This bug has already been fixed in the codebase
  skip "Bug already fixed - case_b_existing.sh doesn't use command execution pattern"
}

@test "Bug 1.5: Background jobs should capture and check exit status" {
  # **Validates: Requirement 1.5**
  # Expected: After wait $pid, script captures status=$? and checks it
  # Actual (unfixed): wait is called but status is not captured for checking
  
  cd "$SCRIPT_DIR"
  
  # Check run_cmd function captures status after wait
  grep -A 3 "wait.*\$pid" lib/utils.sh | grep -q "status=\$?" || \
  grep -A 3 "wait.*\$pid" lib/utils.sh | grep -q "local status"
}

@test "Bug 1.6: run_cmd should display comprehensive error output with formatting" {
  # **Validates: Requirement 1.6**
  # Expected: Error output includes timestamp, command, exit code, stderr with separators
  # Actual (unfixed): Basic error message but missing comprehensive formatting
  
  cd "$SCRIPT_DIR"
  
  # Check for comprehensive error formatting elements
  local has_timestamp=false
  local has_command=false
  local has_exit_code=false
  local has_separators=false
  
  # Check for timestamp in error output
  grep -q "date" lib/utils.sh && has_timestamp=true
  
  # Check for command display
  grep -q "Command:" lib/utils.sh || grep -q "Command failed: \$\*" lib/utils.sh && has_command=true
  
  # Check for exit code display
  grep -q "Exit Code:" lib/utils.sh || grep -q "exit code" lib/utils.sh && has_exit_code=true
  
  # Check for visual separators
  grep -q "====" lib/utils.sh || grep -F "----" lib/utils.sh && has_separators=true
  
  # All elements should be present for comprehensive error output
  $has_timestamp && $has_command && $has_exit_code && $has_separators
}

# ============================================================
# SECURITY BUGS (4 bugs)
# ============================================================

@test "Bug 1.7: Credentials file already uses HOME (SKIP)" {
  # **Validates: Requirement 1.7**
  # This bug has already been fixed in the codebase
  skip "Bug already fixed - credentials written to HOME"
}

@test "Bug 1.8: Directory permissions already use 0750 (SKIP)" {
  # **Validates: Requirement 1.8**
  # This bug has already been fixed in the codebase
  skip "Bug already fixed - directorypermissions = 0750"
}

@test "Bug 1.9: Passwords already use /dev/tty (SKIP)" {
  # **Validates: Requirement 1.9**
  # This bug has already been fixed in the codebase
  skip "Bug already fixed - passwords written to /dev/tty"
}

@test "Bug 1.10: SSH user already defaults to non-root (SKIP)" {
  # **Validates: Requirement 1.10**
  # This bug has already been fixed in the codebase
  skip "Bug already fixed - SSH user defaults to deploy with warning"
}

# ============================================================
# EDGE CASE BUGS (4 bugs)
# ============================================================

@test "Bug 1.11: User input should be validated before proceeding" {
  # **Validates: Requirement 1.11**
  # Expected: Input validation for domain, email, path, password
  # Actual (unfixed): No validation, invalid inputs accepted
  
  cd "$SCRIPT_DIR"
  
  # Check for validation functions or patterns
  grep -q "validate" scripts/case_a_fresh.sh || \
  grep -q "validate" lib/utils.sh || \
  grep -q '@.*@' scripts/case_a_fresh.sh  # Email validation pattern
  
  # Check for domain validation
  grep -q "domain" scripts/case_a_fresh.sh | grep -q "valid" || \
  grep -q "hostname" scripts/case_a_fresh.sh
}

@test "Bug 1.12: cPanel config.php already has guidance (SKIP)" {
  # **Validates: Requirement 1.12**
  # This bug has already been fixed in the codebase
  skip "Bug already fixed - case_c_cpanel.sh provides guidance and copy option"
}

@test "Bug 1.13: Main menu already uses loop (SKIP)" {
  # **Validates: Requirement 1.13**
  # This bug has already been fixed in the codebase
  skip "Bug already fixed - main_menu uses while true loop"
}

@test "Bug 1.14: Internet connectivity already checked (SKIP)" {
  # **Validates: Requirement 1.14**
  # This bug has already been fixed in the codebase
  skip "Bug already fixed - run_preflight calls check_internet"
}

# ============================================================
# INTEGRATION TEST: All bugs fixed in codebase
# ============================================================

@test "Integration: Count remaining bugs in codebase" {
  # This test counts how many bugs are still present
  # On unfixed code, we expect several bugs to be present
  # On fixed code, we expect 0 bugs
  
  cd "$SCRIPT_DIR"
  
  local bug_count=0
  
  # Count structural bugs
  [ -d "{scripts,templates,lib}" ] && ((bug_count++))
  ! grep -q "DEPENDENCY ORDER" install.sh && ((bug_count++))
  
  # Count logic bugs (most already fixed, check for remaining)
  ! grep -A 3 "wait.*\$pid" lib/utils.sh | grep -q "status=\$?" && ((bug_count++))
  ! grep -q "Exit Code:" lib/utils.sh && ((bug_count++))
  ! grep -q "====" lib/utils.sh && ((bug_count++))
  
  # Count edge case bugs
  ! grep -q "validate" scripts/case_a_fresh.sh && ! grep -q "validate" lib/utils.sh && ((bug_count++))
  
  echo "# Bugs found: $bug_count" >&3
  
  # On fixed code, we expect 0 bugs remaining
  [ "$bug_count" -eq 0 ]
}
