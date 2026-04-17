# MySQL Version Compatibility Fix - Preservation Test Results

## Test Execution Summary

**Date**: 2024-04-17  
**Test File**: `tests/mysql_version_compatibility_preservation.bats`  
**Code State**: UNFIXED (baseline behavior)  
**Total Tests**: 45  
**Passed**: 45  
**Failed**: 0  

## Test Outcome

✅ **ALL PRESERVATION TESTS PASS ON UNFIXED CODE**

This confirms the baseline behavior that must be preserved when implementing the MySQL/MariaDB version compatibility fix.

## Test Coverage

### Property 3.1: Moodle 4.1-4.5 Compatibility (5 tests)
- ✅ Moodle 4.1 database requirements compatible with default repositories
- ✅ Moodle 4.2 database requirements compatible with default repositories
- ✅ Moodle 4.3 database requirements compatible with default repositories
- ✅ Moodle 4.4 database requirements compatible with default repositories
- ✅ Moodle 4.5 database requirements compatible with default repositories

**Observation**: All Moodle 4.x versions (4.1-4.5) have database requirements that are satisfied by default Ubuntu repository MariaDB versions. This behavior must be preserved.

### Property 3.2: Database Setup SQL Commands (6 tests)
- ✅ Fresh install creates database with utf8mb4_unicode_ci collation
- ✅ Fresh install creates database user with GRANT PRIVILEGES
- ✅ Fresh install executes FLUSH PRIVILEGES
- ✅ Existing install creates database with utf8mb4_unicode_ci collation
- ✅ Existing install creates database user with GRANT PRIVILEGES
- ✅ Existing install executes FLUSH PRIVILEGES

**Observation**: Both fresh and existing install scripts execute identical SQL commands for database setup. The fix must not alter these SQL commands.

### Property 3.3: mysql_root Authentication (3 tests)
- ✅ mysql_root function exists in lib/checks.sh
- ✅ mysql_root handles socket authentication
- ✅ mysql_root handles password authentication

**Observation**: The mysql_root function handles both socket authentication (Ubuntu default) and password authentication. This dual authentication support must be preserved.

### Property 3.4: Database Service Management (4 tests)
- ✅ Fresh install starts MariaDB service
- ✅ Fresh install enables MariaDB service
- ✅ Existing install starts MariaDB service when installing
- ✅ Existing install enables MariaDB service when installing

**Observation**: Both installation paths use platform_start_service and platform_enable_service for MariaDB. Service management commands must remain unchanged.

### Property 3.5: config.php Generation (4 tests)
- ✅ Fresh install generates config.php with dbtype=mariadb
- ✅ Fresh install config.php includes database connection parameters
- ✅ Fresh install config.php sets utf8mb4_unicode_ci collation
- ✅ Existing install generates config.php with database parameters

**Observation**: config.php generation includes all required database connection parameters (dbtype, dbhost, dbname, dbuser, dbpass) with utf8mb4_unicode_ci collation. This must be preserved.

### Property 3.6: Existing Database Detection (4 tests)
- ✅ check_mariadb function exists
- ✅ Existing install detects MariaDB presence
- ✅ Existing install sets DB_OK flag when database detected
- ✅ Existing install skips database installation when DB_OK=true

**Observation**: Case B (existing server) has logic to detect existing MariaDB installations and skip database installation when already present. This skip logic must be preserved.

### Property 3.7: PHP MySQL Extension (2 tests)
- ✅ Fresh install installs php8.3-mysql extension
- ✅ Existing install installs php8.3-mysql extension

**Observation**: Both installation paths install php8.3-mysql extension for database connectivity. This must remain unchanged.

### Property 3.8: Moodle CLI Installer (4 tests)
- ✅ Fresh install runs install_database.php
- ✅ Fresh install passes required CLI parameters
- ✅ Existing install runs install_database.php
- ✅ CLI installer runs as web user (www-data)

**Observation**: Both installation paths execute Moodle's install_database.php with required parameters (--agree-license, --adminuser, --adminpass, etc.) as the www-data user. This execution pattern must be preserved.

### Property 3.9: Environment Summary Display (4 tests)
- ✅ Existing install displays environment summary
- ✅ Environment summary shows web server detection
- ✅ Environment summary shows PHP detection
- ✅ Environment summary shows MariaDB detection

**Observation**: Case B displays an environment summary showing detected components (web server, PHP, MariaDB). This user-facing display must be preserved.

### Property 3.10: Credentials File (5 tests)
- ✅ Fresh install saves database name to credentials file
- ✅ Fresh install saves database user to credentials file
- ✅ Fresh install saves database password to credentials file
- ✅ Fresh install saves database host to credentials file
- ✅ Existing install saves database credentials

**Observation**: Both installation paths save database credentials (name, user, password, host) to the credentials file. This must be preserved.

### Integration Tests (3 tests)
- ✅ All preservation properties verified for Moodle 4.1-4.5 compatibility
- ✅ Property: version_compare function produces consistent results
- ✅ Property: All MOODLE_DB_VERSIONS entries follow format mariadb:X.Y.Z,mysql:X.Y.Z
- ✅ Property: Fresh and existing install scripts follow same database setup pattern

**Observation**: Integration tests confirm that all preservation properties hold together and that the codebase has consistent patterns across installation paths.

## Key Findings

1. **Moodle 4.1-4.5 Work Correctly**: All Moodle 4.x versions have database requirements that are satisfied by default Ubuntu repository MariaDB versions (10.4+, 10.5+, 10.6+). The fix must not break these working installations.

2. **Consistent Database Setup**: Both fresh and existing install scripts use identical SQL commands (CREATE DATABASE, CREATE USER, GRANT PRIVILEGES, FLUSH PRIVILEGES) with utf8mb4_unicode_ci collation. The fix must not alter these commands.

3. **Dual Authentication Support**: The mysql_root function supports both socket authentication (Ubuntu default) and password authentication. The fix must preserve this flexibility.

4. **Service Management Pattern**: Both installation paths use platform_start_service and platform_enable_service for MariaDB. The fix must use the same service management functions.

5. **config.php Consistency**: config.php generation is consistent across installation paths with all required database parameters. The fix must not alter config.php generation logic.

6. **Existing Database Skip Logic**: Case B has logic to detect existing MariaDB and skip installation when already present. The fix must preserve this skip logic while adding version compatibility checking.

7. **PHP Extension Installation**: Both paths install php8.3-mysql extension. The fix must not alter PHP extension installation.

8. **CLI Installer Execution**: Both paths execute Moodle's install_database.php as www-data user with required parameters. The fix must not alter CLI installer execution.

9. **User-Facing Display**: Case B displays environment summary showing detected components. The fix should enhance this display to show database version information without breaking the existing format.

10. **Credentials File**: Both paths save database credentials to file. The fix must preserve this behavior.

## Recommendations for Implementation

Based on these preservation test results, the fix implementation should:

1. **Add version checking BEFORE database installation**: Insert compatibility checks after `pick_moodle_version` but before `platform_install_package mariadb-server`.

2. **Preserve existing installation flow for compatible versions**: When database version requirements are met by default repositories, the installation flow should be identical to current behavior.

3. **Only add repository management when needed**: Only invoke `add_mariadb_repository()` and `install_compatible_database()` when default repository versions are insufficient.

4. **Enhance existing database detection in Case B**: Extend the existing `check_mariadb` logic to capture version information without breaking the DB_OK flag behavior.

5. **Preserve all SQL commands**: Do not modify CREATE DATABASE, CREATE USER, GRANT PRIVILEGES, or FLUSH PRIVILEGES commands.

6. **Use existing service management functions**: Use platform_start_service and platform_enable_service for any new database installation logic.

7. **Preserve config.php generation**: Do not modify config.php generation logic.

8. **Preserve CLI installer execution**: Do not modify install_database.php execution or parameters.

9. **Enhance environment summary**: Add database version information to Case B environment summary without breaking existing display format.

10. **Preserve credentials file**: Ensure database credentials continue to be saved to credentials file.

## Next Steps

1. ✅ **Task 2 Complete**: Preservation tests written and passing on unfixed code
2. ⏭️ **Task 3**: Implement the fix for MySQL/MariaDB version compatibility
3. ⏭️ **Task 3.6**: Re-run bug condition exploration tests (should pass after fix)
4. ⏭️ **Task 3.7**: Re-run preservation tests (should still pass after fix - no regressions)

## Conclusion

All 45 preservation tests pass on the unfixed code, confirming the baseline behavior that must be preserved. The fix can now be implemented with confidence that these tests will catch any regressions in the working Moodle 4.1-4.5 installation flow.

The preservation tests provide strong guarantees that:
- Moodle 4.1-4.5 installations will continue to work identically after the fix
- Database setup SQL commands will remain unchanged
- Service management, config.php generation, and CLI installer execution will be preserved
- Existing database detection and skip logic will continue to work
- User-facing displays and credentials file generation will be preserved

These tests will be re-run after implementing the fix to ensure no regressions are introduced.
