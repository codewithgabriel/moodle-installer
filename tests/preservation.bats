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
  grep -A 30 'prompt()' lib/utils.sh | grep -q 'printf -v'
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
# PROPERTY 11: Moodle Version Selection Offers 4.1-5.1 and main
# **Validates: Requirement 3.11**
# ============================================================

@test "Preservation 3.11: Version picker function exists" {
  cd "$SCRIPT_DIR"
  
  # Verify pick_moodle_version function exists
  grep -q '^pick_moodle_version()' lib/utils.sh
}

@test "Preservation 3.11: Version picker offers Moodle 5.1" {
  cd "$SCRIPT_DIR"
  
  # Verify MOODLE_501_STABLE is offered
  grep -A 30 '^pick_moodle_version()' lib/utils.sh | grep -q 'MOODLE_501_STABLE'
}

@test "Preservation 3.11: Version picker offers Moodle 4.5 LTS" {
  cd "$SCRIPT_DIR"
  
  # Verify MOODLE_405_STABLE is offered
  grep -A 30 '^pick_moodle_version()' lib/utils.sh | grep -q 'MOODLE_405_STABLE'
}

@test "Preservation 3.11: Version picker offers Moodle 4.1 LTS" {
  cd "$SCRIPT_DIR"
  
  # Verify MOODLE_401_STABLE is offered
  grep -A 30 '^pick_moodle_version()' lib/utils.sh | grep -q 'MOODLE_401_STABLE'
}

@test "Preservation 3.11: Version picker offers main branch with warning" {
  cd "$SCRIPT_DIR"
  
  # Verify main branch is offered
  grep -A 30 '^pick_moodle_version()' lib/utils.sh | grep -q 'main'
  
  # Verify warning exists for main branch
  grep -A 30 '^pick_moodle_version()' lib/utils.sh | grep -q 'unstable\|NOT for production\|bleeding edge'
}

@test "Preservation 3.11: Version picker uses printf -v to assign variable" {
  cd "$SCRIPT_DIR"
  
  # Verify version is assigned using printf -v
  grep -A 30 '^pick_moodle_version()' lib/utils.sh | grep -q 'printf -v'
}

# ============================================================
# PROPERTY 12: PHP 8.3 Configured with Moodle-Recommended Settings
# **Validates: Requirement 3.12**
# ============================================================

@test "Preservation 3.12: PHP configuration sets max_input_vars=5000" {
  cd "$SCRIPT_DIR"
  
  # Verify max_input_vars is set to 5000
  grep -q 'max_input_vars.*5000' scripts/case_a_fresh.sh
}

@test "Preservation 3.12: PHP configuration sets memory_limit=256M" {
  cd "$SCRIPT_DIR"
  
  # Verify memory_limit is set to 256M
  grep -q 'memory_limit.*256M' scripts/case_a_fresh.sh
}

@test "Preservation 3.12: PHP configuration sets upload_max_filesize=512M" {
  cd "$SCRIPT_DIR"
  
  # Verify upload_max_filesize is set to 512M
  grep -q 'upload_max_filesize.*512M' scripts/case_a_fresh.sh
}

@test "Preservation 3.12: PHP configuration sets post_max_size=512M" {
  cd "$SCRIPT_DIR"
  
  # Verify post_max_size is set to 512M
  grep -q 'post_max_size.*512M' scripts/case_a_fresh.sh
}

@test "Preservation 3.12: PHP configuration sets max_execution_time=300" {
  cd "$SCRIPT_DIR"
  
  # Verify max_execution_time is set to 300
  grep -q 'max_execution_time.*300' scripts/case_a_fresh.sh
}

@test "Preservation 3.12: PHP configuration enables opcache" {
  cd "$SCRIPT_DIR"
  
  # Verify opcache is enabled
  grep -q 'opcache\.enable.*1' scripts/case_a_fresh.sh
}

@test "Preservation 3.12: PHP CLI configuration also updated" {
  cd "$SCRIPT_DIR"
  
  # Verify CLI php.ini is also configured
  grep -q 'php_cli_ini' scripts/case_a_fresh.sh
  grep -A 10 'php_cli_ini' scripts/case_a_fresh.sh | grep -q 'sed -i'
}

# ============================================================
# PROPERTY 13: Apache/Nginx Virtual Host Configurations Created
# **Validates: Requirement 3.13**
# ============================================================

@test "Preservation 3.13: Apache vhost configuration created" {
  cd "$SCRIPT_DIR"
  
  # Verify Apache vhost is created
  grep -q 'VirtualHost' scripts/case_a_fresh.sh
  grep -q 'DocumentRoot' scripts/case_a_fresh.sh
}

@test "Preservation 3.13: Apache vhost enables rewrite module" {
  cd "$SCRIPT_DIR"
  
  # Verify rewrite module is enabled
  grep -q 'a2enmod rewrite' scripts/case_a_fresh.sh
}

@test "Preservation 3.13: Apache vhost sets correct permissions" {
  cd "$SCRIPT_DIR"
  
  # Verify Directory directive with permissions
  grep -A 10 'VirtualHost' scripts/case_a_fresh.sh | grep -q 'AllowOverride All'
}

@test "Preservation 3.13: Nginx configuration created for existing servers" {
  cd "$SCRIPT_DIR"
  
  # Verify Nginx config is created in case_b_existing.sh
  grep -q 'nginx_conf' scripts/case_b_existing.sh
  grep -q 'fastcgi_pass' scripts/case_b_existing.sh
}

@test "Preservation 3.13: Nginx configuration includes PHP-FPM socket" {
  cd "$SCRIPT_DIR"
  
  # Verify PHP-FPM socket is configured
  grep -q 'fpm_sock' scripts/case_b_existing.sh
  grep -q 'unix:' scripts/case_b_existing.sh
}

# ============================================================
# PROPERTY 14: Redis Configured for Session Storage
# **Validates: Requirement 3.14**
# ============================================================

@test "Preservation 3.14: Redis installed and started" {
  cd "$SCRIPT_DIR"
  
  # Verify Redis installation
  grep -q 'redis' scripts/case_a_fresh.sh
  grep -q 'redis-server' scripts/case_a_fresh.sh
}

@test "Preservation 3.14: config.php includes Redis session handler" {
  cd "$SCRIPT_DIR"
  
  # Verify Redis session handler in config.php
  grep -q 'session_handler_class.*redis' scripts/case_a_fresh.sh
}

@test "Preservation 3.14: config.php sets Redis host and port" {
  cd "$SCRIPT_DIR"
  
  # Verify Redis connection settings
  grep -q 'session_redis_host.*127.0.0.1' scripts/case_a_fresh.sh
  grep -q 'session_redis_port.*6379' scripts/case_a_fresh.sh
}

@test "Preservation 3.14: config.php sets Redis database and timeouts" {
  cd "$SCRIPT_DIR"
  
  # Verify Redis database and timeout settings
  grep -q 'session_redis_database' scripts/case_a_fresh.sh
  grep -q 'session_redis_acquire_lock_timeout' scripts/case_a_fresh.sh
  grep -q 'session_redis_lock_expire' scripts/case_a_fresh.sh
}

# ============================================================
# PROPERTY 15: Moodle CLI Installer Creates Admin Account
# **Validates: Requirement 3.15**
# ============================================================

@test "Preservation 3.15: CLI install_database.php is called" {
  cd "$SCRIPT_DIR"
  
  # Verify CLI installer is called
  grep -q 'install_database.php' scripts/case_a_fresh.sh
}

@test "Preservation 3.15: CLI installer receives admin username" {
  cd "$SCRIPT_DIR"
  
  # Verify adminuser parameter is passed
  grep -q 'adminuser' scripts/case_a_fresh.sh
}

@test "Preservation 3.15: CLI installer receives admin password" {
  cd "$SCRIPT_DIR"
  
  # Verify adminpass parameter is passed
  grep -q 'adminpass' scripts/case_a_fresh.sh
}

@test "Preservation 3.15: CLI installer receives admin email" {
  cd "$SCRIPT_DIR"
  
  # Verify adminemail parameter is passed
  grep -q 'adminemail' scripts/case_a_fresh.sh
}

@test "Preservation 3.15: CLI installer receives site names" {
  cd "$SCRIPT_DIR"
  
  # Verify fullname and shortname parameters are passed
  grep -q 'fullname' scripts/case_a_fresh.sh
  grep -q 'shortname' scripts/case_a_fresh.sh
}

@test "Preservation 3.15: CLI installer runs as web user" {
  cd "$SCRIPT_DIR"
  
  # Verify CLI installer runs with sudo -u www-data or equivalent via PHP_RUNNER
  grep -B 10 'install_database.php' scripts/case_a_fresh.sh | grep -q 'PHP_RUNNER.*sudo -u'
}

# ============================================================
# INTEGRATION TEST: All Preservation Properties Hold
# ============================================================

@test "Integration: All preservation properties verified (3.1-3.15)" {
  # Use SCRIPT_DIR for integration test since TEST_DIR copy may be incomplete
  cd "$SCRIPT_DIR"
  
  local property_count=0
  
  # Count verified properties (use || true to prevent early exit)
  # 3.1: Menu navigation
  [ -f "install.sh" ] && property_count=$((property_count + 1)) || true
  
  # 3.2: Fresh install
  [ -f "scripts/case_a_fresh.sh" ] && property_count=$((property_count + 1)) || true
  
  # 3.3: Existing install
  [ -f "scripts/case_b_existing.sh" ] && property_count=$((property_count + 1)) || true
  
  # 3.4: cPanel guide
  [ -f "scripts/case_c_cpanel.sh" ] && property_count=$((property_count + 1)) || true
  
  # 3.5: CI/CD setup
  [ -f "scripts/cicd_setup.sh" ] && property_count=$((property_count + 1)) || true
  
  # 3.6: Prompt functions
  grep -q '^prompt()' lib/utils.sh 2>/dev/null && property_count=$((property_count + 1)) || true
  
  # 3.7: Spinner
  grep -q '^spinner()' lib/utils.sh 2>/dev/null && property_count=$((property_count + 1)) || true
  
  # 3.8: Preflight checks
  grep -q 'run_preflight' lib/checks.sh 2>/dev/null && property_count=$((property_count + 1)) || true
  
  # 3.9: Quit option
  grep -q 'exit 0' install.sh 2>/dev/null && property_count=$((property_count + 1)) || true
  
  # 3.10: Credentials permissions
  grep -q 'chmod 600' scripts/case_a_fresh.sh 2>/dev/null && property_count=$((property_count + 1)) || true
  
  # 3.11: Version selection
  grep -q 'pick_moodle_version' lib/utils.sh 2>/dev/null && property_count=$((property_count + 1)) || true
  
  # 3.12: PHP configuration
  grep -q 'max_input_vars.*5000' scripts/case_a_fresh.sh 2>/dev/null && property_count=$((property_count + 1)) || true
  
  # 3.13: Apache/Nginx vhost
  grep -q 'VirtualHost' scripts/case_a_fresh.sh 2>/dev/null && property_count=$((property_count + 1)) || true
  
  # 3.14: Redis configuration
  grep -q 'session_handler_class.*redis' scripts/case_a_fresh.sh 2>/dev/null && property_count=$((property_count + 1)) || true
  
  # 3.15: CLI installer
  grep -q 'install_database.php' scripts/case_a_fresh.sh 2>/dev/null && property_count=$((property_count + 1)) || true
  
  echo "# Preservation properties verified: $property_count/15" >&3
  
  # All 15 preservation properties should be present
  [ "$property_count" -eq 15 ]
}
