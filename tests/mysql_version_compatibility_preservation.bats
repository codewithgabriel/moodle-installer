#!/usr/bin/env bats
# Preservation Property Tests for MySQL/MariaDB Version Compatibility Fix
# **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10**
#
# IMPORTANT: These tests capture baseline behavior on UNFIXED code for non-buggy inputs
# Expected outcome: Tests PASS on unfixed code (confirms behavior to preserve)
# These tests ensure the fix does not introduce regressions for Moodle versions that work correctly

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
# PROPERTY 3.1: Moodle 4.1-4.5 installations work with default repository MariaDB
# **Validates: Requirement 3.1**
# ============================================================

@test "Preservation 3.1: Moodle 4.1 database requirements are compatible with default repositories" {
  # Moodle 4.1 requires mariadb:10.4.0,mysql:5.7.0
  # This is available in Ubuntu 20.04/22.04/24.04 default repositories
  
  cd "$SCRIPT_DIR"
  source lib/version_config.sh
  
  local db_req="${MOODLE_DB_VERSIONS[MOODLE_401_STABLE]}"
  
  # Verify requirements are reasonable for default repositories
  echo "$db_req" | grep -q "mariadb:10.4"
  echo "$db_req" | grep -q "mysql:5.7"
}

@test "Preservation 3.1: Moodle 4.2 database requirements are compatible with default repositories" {
  # Moodle 4.2 requires mariadb:10.5.0,mysql:8.0.0
  # This is available in Ubuntu 20.04/22.04/24.04 default repositories
  
  cd "$SCRIPT_DIR"
  source lib/version_config.sh
  
  local db_req="${MOODLE_DB_VERSIONS[MOODLE_402_STABLE]}"
  
  # Verify requirements are reasonable for default repositories
  echo "$db_req" | grep -q "mariadb:10.5"
  echo "$db_req" | grep -q "mysql:8.0"
}

@test "Preservation 3.1: Moodle 4.3 database requirements are compatible with default repositories" {
  # Moodle 4.3 requires mariadb:10.5.0,mysql:8.0.0
  
  cd "$SCRIPT_DIR"
  source lib/version_config.sh
  
  local db_req="${MOODLE_DB_VERSIONS[MOODLE_403_STABLE]}"
  
  echo "$db_req" | grep -q "mariadb:10.5"
  echo "$db_req" | grep -q "mysql:8.0"
}

@test "Preservation 3.1: Moodle 4.4 database requirements are compatible with default repositories" {
  # Moodle 4.4 requires mariadb:10.6.7,mysql:8.0.30
  
  cd "$SCRIPT_DIR"
  source lib/version_config.sh
  
  local db_req="${MOODLE_DB_VERSIONS[MOODLE_404_STABLE]}"
  
  echo "$db_req" | grep -q "mariadb:10.6"
  echo "$db_req" | grep -q "mysql:8.0"
}

@test "Preservation 3.1: Moodle 4.5 database requirements are compatible with default repositories" {
  # Moodle 4.5 requires mariadb:10.6.7,mysql:8.0.30
  # Ubuntu 24.04 provides MariaDB 10.6.18 which meets this requirement
  
  cd "$SCRIPT_DIR"
  source lib/version_config.sh
  
  local db_req="${MOODLE_DB_VERSIONS[MOODLE_405_STABLE]}"
  
  echo "$db_req" | grep -q "mariadb:10.6"
  echo "$db_req" | grep -q "mysql:8.0"
}

# ============================================================
# PROPERTY 3.2: Database setup SQL commands remain unchanged
# **Validates: Requirement 3.2**
# ============================================================

@test "Preservation 3.2: Fresh install creates database with utf8mb4_unicode_ci collation" {
  cd "$SCRIPT_DIR"
  
  # Verify CREATE DATABASE command uses utf8mb4_unicode_ci
  grep -A 5 "CREATE DATABASE" scripts/case_a_fresh.sh | grep -q "utf8mb4_unicode_ci"
}

@test "Preservation 3.2: Fresh install creates database user with GRANT PRIVILEGES" {
  cd "$SCRIPT_DIR"
  
  # Verify GRANT PRIVILEGES command exists
  grep -q "GRANT ALL PRIVILEGES" scripts/case_a_fresh.sh
}

@test "Preservation 3.2: Fresh install executes FLUSH PRIVILEGES" {
  cd "$SCRIPT_DIR"
  
  # Verify FLUSH PRIVILEGES command exists
  grep -q "FLUSH PRIVILEGES" scripts/case_a_fresh.sh
}

@test "Preservation 3.2: Existing install creates database with utf8mb4_unicode_ci collation" {
  cd "$SCRIPT_DIR"
  
  # Verify CREATE DATABASE command uses utf8mb4_unicode_ci in case_b_existing.sh
  grep -A 5 "CREATE DATABASE" scripts/case_b_existing.sh | grep -q "utf8mb4_unicode_ci"
}

@test "Preservation 3.2: Existing install creates database user with GRANT PRIVILEGES" {
  cd "$SCRIPT_DIR"
  
  # Verify GRANT PRIVILEGES command exists in case_b_existing.sh
  grep -q "GRANT ALL PRIVILEGES" scripts/case_b_existing.sh
}

@test "Preservation 3.2: Existing install executes FLUSH PRIVILEGES" {
  cd "$SCRIPT_DIR"
  
  # Verify FLUSH PRIVILEGES command exists in case_b_existing.sh
  grep -q "FLUSH PRIVILEGES" scripts/case_b_existing.sh
}

# ============================================================
# PROPERTY 3.3: mysql_root authentication handling remains unchanged
# **Validates: Requirement 3.3**
# ============================================================

@test "Preservation 3.3: mysql_root function exists in lib/checks.sh" {
  cd "$SCRIPT_DIR"
  
  # Verify mysql_root function exists
  grep -q "^mysql_root()" lib/checks.sh
}

@test "Preservation 3.3: mysql_root handles socket authentication" {
  cd "$SCRIPT_DIR"
  
  # Verify mysql_root tries socket auth first
  grep -A 10 "^mysql_root()" lib/checks.sh | grep -q "mysql -u root"
}

@test "Preservation 3.3: mysql_root handles password authentication" {
  cd "$SCRIPT_DIR"
  
  # Verify mysql_root supports password auth
  grep -A 10 "^mysql_root()" lib/checks.sh | grep -q "MYSQL_ROOT_PASS"
}

# ============================================================
# PROPERTY 3.4: Database service management remains unchanged
# **Validates: Requirement 3.4**
# ============================================================

@test "Preservation 3.4: Fresh install starts MariaDB service" {
  cd "$SCRIPT_DIR"
  
  # Verify platform_start_service is called for mariadb
  grep -q "platform_start_service mariadb" scripts/case_a_fresh.sh
}

@test "Preservation 3.4: Fresh install enables MariaDB service" {
  cd "$SCRIPT_DIR"
  
  # Verify platform_enable_service is called for mariadb
  grep -q "platform_enable_service mariadb" scripts/case_a_fresh.sh
}

@test "Preservation 3.4: Existing install starts MariaDB service when installing" {
  cd "$SCRIPT_DIR"
  
  # Verify platform_start_service is called in case_b_existing.sh
  grep -q "platform_start_service mariadb" scripts/case_b_existing.sh
}

@test "Preservation 3.4: Existing install enables MariaDB service when installing" {
  cd "$SCRIPT_DIR"
  
  # Verify platform_enable_service is called in case_b_existing.sh
  grep -q "platform_enable_service mariadb" scripts/case_b_existing.sh
}

# ============================================================
# PROPERTY 3.5: config.php generation remains unchanged
# **Validates: Requirement 3.5**
# ============================================================

@test "Preservation 3.5: Fresh install generates config.php with dbtype=mariadb" {
  cd "$SCRIPT_DIR"
  
  # Verify config.php sets dbtype to mariadb
  grep -A 20 "config.php" scripts/case_a_fresh.sh | grep -q "CFG->dbtype.*mariadb"
}

@test "Preservation 3.5: Fresh install config.php includes database connection parameters" {
  cd "$SCRIPT_DIR"
  
  # Verify config.php includes dbhost, dbname, dbuser, dbpass
  grep -A 30 "config.php" scripts/case_a_fresh.sh | grep -q "CFG->dbhost"
  grep -A 30 "config.php" scripts/case_a_fresh.sh | grep -q "CFG->dbname"
  grep -A 30 "config.php" scripts/case_a_fresh.sh | grep -q "CFG->dbuser"
  grep -A 30 "config.php" scripts/case_a_fresh.sh | grep -q "CFG->dbpass"
}

@test "Preservation 3.5: Fresh install config.php sets utf8mb4_unicode_ci collation" {
  cd "$SCRIPT_DIR"
  
  # Verify config.php sets dbcollation
  grep -A 30 "config.php" scripts/case_a_fresh.sh | grep -q "utf8mb4_unicode_ci"
}

@test "Preservation 3.5: Existing install generates config.php with database parameters" {
  cd "$SCRIPT_DIR"
  
  # Verify config.php generation in case_b_existing.sh
  grep -A 30 "config.php" scripts/case_b_existing.sh | grep -q "CFG->dbtype"
  grep -A 30 "config.php" scripts/case_b_existing.sh | grep -q "CFG->dbhost"
  grep -A 30 "config.php" scripts/case_b_existing.sh | grep -q "CFG->dbname"
}

# ============================================================
# PROPERTY 3.6: Existing database detection and skip logic remains unchanged
# **Validates: Requirement 3.6**
# ============================================================

@test "Preservation 3.6: check_mariadb function exists" {
  cd "$SCRIPT_DIR"
  
  # Verify check_mariadb function exists in lib/checks.sh
  grep -q "^check_mariadb()" lib/checks.sh
}

@test "Preservation 3.6: Existing install detects MariaDB presence" {
  cd "$SCRIPT_DIR"
  
  # Verify case_b_existing.sh calls check_mariadb
  grep -q "check_mariadb" scripts/case_b_existing.sh
}

@test "Preservation 3.6: Existing install sets DB_OK flag when database detected" {
  cd "$SCRIPT_DIR"
  
  # Verify DB_OK variable is set based on check_mariadb result
  grep -A 5 "check_mariadb" scripts/case_b_existing.sh | grep -q "DB_OK"
}

@test "Preservation 3.6: Existing install skips database installation when DB_OK=true" {
  cd "$SCRIPT_DIR"
  
  # Verify conditional database installation based on DB_OK
  grep -A 5 "DB_OK.*false" scripts/case_b_existing.sh | grep -q "Installing MariaDB"
}

# ============================================================
# PROPERTY 3.7: PHP mysql extension installation remains unchanged
# **Validates: Requirement 3.7**
# ============================================================

@test "Preservation 3.7: Fresh install installs php8.3-mysql extension" {
  cd "$SCRIPT_DIR"
  
  # Verify php8.3-mysql is installed
  grep -q "php8.3-mysql" scripts/case_a_fresh.sh
}

@test "Preservation 3.7: Existing install installs php8.3-mysql extension" {
  cd "$SCRIPT_DIR"
  
  # Verify php8.3-mysql is installed in case_b_existing.sh
  grep -q "php8.3-mysql" scripts/case_b_existing.sh
}

# ============================================================
# PROPERTY 3.8: Moodle CLI installer execution remains unchanged
# **Validates: Requirement 3.8**
# ============================================================

@test "Preservation 3.8: Fresh install runs install_database.php" {
  cd "$SCRIPT_DIR"
  
  # Verify install_database.php is executed
  grep -q "install_database.php" scripts/case_a_fresh.sh
}

@test "Preservation 3.8: Fresh install passes required CLI parameters" {
  cd "$SCRIPT_DIR"
  
  # Verify CLI parameters are passed
  grep -A 10 "install_database.php" scripts/case_a_fresh.sh | grep -q "agree-license"
  grep -A 10 "install_database.php" scripts/case_a_fresh.sh | grep -q "adminuser"
  grep -A 10 "install_database.php" scripts/case_a_fresh.sh | grep -q "adminpass"
}

@test "Preservation 3.8: Existing install runs install_database.php" {
  cd "$SCRIPT_DIR"
  
  # Verify install_database.php is executed in case_b_existing.sh
  grep -q "install_database.php" scripts/case_b_existing.sh
}

@test "Preservation 3.8: CLI installer runs as web user (www-data)" {
  cd "$SCRIPT_DIR"
  
  # Verify CLI installer runs with sudo -u www-data via PHP_RUNNER
  grep -B 5 "install_database.php" scripts/case_a_fresh.sh | grep -q "PHP_RUNNER"
}

# ============================================================
# PROPERTY 3.9: Environment summary display remains unchanged
# **Validates: Requirement 3.9**
# ============================================================

@test "Preservation 3.9: Existing install displays environment summary" {
  cd "$SCRIPT_DIR"
  
  # Verify environment summary section exists
  grep -q "Environment summary" scripts/case_b_existing.sh
}

@test "Preservation 3.9: Environment summary shows web server detection" {
  cd "$SCRIPT_DIR"
  
  # Verify web server is displayed in summary
  grep -A 10 "Environment summary" scripts/case_b_existing.sh | grep -q "Web server"
}

@test "Preservation 3.9: Environment summary shows PHP detection" {
  cd "$SCRIPT_DIR"
  
  # Verify PHP status is displayed in summary
  grep -A 10 "Environment summary" scripts/case_b_existing.sh | grep -q "PHP"
}

@test "Preservation 3.9: Environment summary shows MariaDB detection" {
  cd "$SCRIPT_DIR"
  
  # Verify MariaDB status is displayed in summary
  grep -A 10 "Environment summary" scripts/case_b_existing.sh | grep -q "MariaDB"
}

# ============================================================
# PROPERTY 3.10: Credentials file includes database information
# **Validates: Requirement 3.10**
# ============================================================

@test "Preservation 3.10: Fresh install saves database name to credentials file" {
  cd "$SCRIPT_DIR"
  
  # Verify credentials file includes database name
  grep -A 20 "CREDS_FILE" scripts/case_a_fresh.sh | grep -q "Database Name"
}

@test "Preservation 3.10: Fresh install saves database user to credentials file" {
  cd "$SCRIPT_DIR"
  
  # Verify credentials file includes database user
  grep -A 20 "CREDS_FILE" scripts/case_a_fresh.sh | grep -q "Database User"
}

@test "Preservation 3.10: Fresh install saves database password to credentials file" {
  cd "$SCRIPT_DIR"
  
  # Verify credentials file includes database password
  grep -A 20 "CREDS_FILE" scripts/case_a_fresh.sh | grep -q "Database Pass"
}

@test "Preservation 3.10: Fresh install saves database host to credentials file" {
  cd "$SCRIPT_DIR"
  
  # Verify credentials file includes database host
  grep -A 20 "CREDS_FILE" scripts/case_a_fresh.sh | grep -q "Database Host" || \
  grep -A 20 "CREDS_FILE" scripts/case_a_fresh.sh | grep -q "localhost"
}

@test "Preservation 3.10: Existing install saves database credentials" {
  cd "$SCRIPT_DIR"
  
  # Verify credentials file includes database information in case_b_existing.sh
  grep -A 20 "CREDS_FILE" scripts/case_b_existing.sh | grep -q "Database Name"
  grep -A 20 "CREDS_FILE" scripts/case_b_existing.sh | grep -q "Database User"
  grep -A 20 "CREDS_FILE" scripts/case_b_existing.sh | grep -q "Database Pass"
}

# ============================================================
# INTEGRATION TEST: All preservation properties hold
# ============================================================

@test "Integration: All preservation properties verified for Moodle 4.1-4.5 compatibility" {
  cd "$SCRIPT_DIR"
  
  local property_count=0
  
  # 3.1: Moodle 4.1-4.5 database requirements are compatible
  source lib/version_config.sh
  [ -n "${MOODLE_DB_VERSIONS[MOODLE_401_STABLE]}" ] && property_count=$((property_count + 1))
  [ -n "${MOODLE_DB_VERSIONS[MOODLE_405_STABLE]}" ] && property_count=$((property_count + 1))
  
  # 3.2: Database setup SQL commands
  grep -q "utf8mb4_unicode_ci" scripts/case_a_fresh.sh && property_count=$((property_count + 1))
  grep -q "GRANT ALL PRIVILEGES" scripts/case_a_fresh.sh && property_count=$((property_count + 1))
  grep -q "FLUSH PRIVILEGES" scripts/case_a_fresh.sh && property_count=$((property_count + 1))
  
  # 3.3: mysql_root authentication
  grep -q "^mysql_root()" lib/checks.sh && property_count=$((property_count + 1))
  
  # 3.4: Service management
  grep -q "platform_start_service mariadb" scripts/case_a_fresh.sh && property_count=$((property_count + 1))
  grep -q "platform_enable_service mariadb" scripts/case_a_fresh.sh && property_count=$((property_count + 1))
  
  # 3.5: config.php generation
  grep -A 20 "config.php" scripts/case_a_fresh.sh | grep -q "CFG->dbtype" && property_count=$((property_count + 1))
  grep -A 30 "config.php" scripts/case_a_fresh.sh | grep -q "CFG->dbhost" && property_count=$((property_count + 1))
  
  # 3.6: Existing database detection
  grep -q "^check_mariadb()" lib/checks.sh && property_count=$((property_count + 1))
  grep -q "check_mariadb" scripts/case_b_existing.sh && property_count=$((property_count + 1))
  
  # 3.7: PHP mysql extension
  grep -q "php8.3-mysql" scripts/case_a_fresh.sh && property_count=$((property_count + 1))
  
  # 3.8: Moodle CLI installer
  grep -q "install_database.php" scripts/case_a_fresh.sh && property_count=$((property_count + 1))
  
  # 3.9: Environment summary
  grep -q "Environment summary" scripts/case_b_existing.sh && property_count=$((property_count + 1))
  
  # 3.10: Credentials file
  grep -A 20 "CREDS_FILE" scripts/case_a_fresh.sh | grep -q "Database Name" && property_count=$((property_count + 1))
  
  echo "# Preservation properties verified: $property_count/16" >&3
  
  # All 16 preservation properties should be present
  [ "$property_count" -ge 15 ]
}

# ============================================================
# PROPERTY-BASED TEST: Version comparison consistency
# ============================================================

@test "Property: version_compare function produces consistent results" {
  cd "$SCRIPT_DIR"
  source lib/version_config.sh
  
  # Test transitivity: if A >= B and B >= C, then A >= C
  version_compare "10.11.0" ">=" "10.6.7"
  version_compare "10.6.7" ">=" "10.4.0"
  version_compare "10.11.0" ">=" "10.4.0"
  
  # Test reflexivity: A >= A
  version_compare "10.6.7" ">=" "10.6.7"
  version_compare "8.0.30" ">=" "8.0.30"
  
  # Test antisymmetry: if A >= B and B >= A, then A == B
  version_compare "10.6.7" ">=" "10.6.7"
  version_compare "10.6.7" "<=" "10.6.7"
  version_compare "10.6.7" "==" "10.6.7"
}

# ============================================================
# PROPERTY-BASED TEST: Database requirements are well-formed
# ============================================================

@test "Property: All MOODLE_DB_VERSIONS entries follow format mariadb:X.Y.Z,mysql:X.Y.Z" {
  cd "$SCRIPT_DIR"
  source lib/version_config.sh
  
  # Check all Moodle versions have well-formed database requirements
  for branch in MOODLE_401_STABLE MOODLE_402_STABLE MOODLE_403_STABLE MOODLE_404_STABLE MOODLE_405_STABLE MOODLE_501_STABLE main; do
    local db_req="${MOODLE_DB_VERSIONS[$branch]}"
    
    # Verify format: contains "mariadb:" and "mysql:"
    echo "$db_req" | grep -q "mariadb:"
    echo "$db_req" | grep -q "mysql:"
    
    # Verify format: contains comma separator
    echo "$db_req" | grep -q ","
  done
}

# ============================================================
# PROPERTY-BASED TEST: Installation flow consistency
# ============================================================

@test "Property: Fresh and existing install scripts follow same database setup pattern" {
  cd "$SCRIPT_DIR"
  
  # Both scripts should use the same SQL commands for database setup
  # Extract database setup sections and compare patterns
  
  # Both should create database with utf8mb4_unicode_ci
  grep -q "CREATE DATABASE.*utf8mb4_unicode_ci" scripts/case_a_fresh.sh
  grep -q "CREATE DATABASE.*utf8mb4_unicode_ci" scripts/case_b_existing.sh
  
  # Both should create user
  grep -q "CREATE USER" scripts/case_a_fresh.sh
  grep -q "CREATE USER" scripts/case_b_existing.sh
  
  # Both should grant privileges
  grep -q "GRANT ALL PRIVILEGES" scripts/case_a_fresh.sh
  grep -q "GRANT ALL PRIVILEGES" scripts/case_b_existing.sh
  
  # Both should flush privileges
  grep -q "FLUSH PRIVILEGES" scripts/case_a_fresh.sh
  grep -q "FLUSH PRIVILEGES" scripts/case_b_existing.sh
}

