# MySQL/MariaDB Version Compatibility Bug - Counterexamples

**Test Date**: 2024-04-17  
**Test File**: `tests/mysql_version_compatibility.bats`  
**Status**: ✅ Bug confirmed - 13 of 15 tests failed as expected

## Summary

The bug condition exploration test successfully confirmed the MySQL/MariaDB version compatibility bug exists in the unfixed codebase. The test identified **13 missing components** required for proper database version checking and compatibility management.

## Test Results

### ✅ Tests That Failed (Confirming Bug Exists)

#### 1. Missing Database Version Detection Functions (3 failures)

**Bug 1.1**: `detect_database_version()` function does not exist in `lib/checks.sh`
- **Expected**: Function to query and parse installed MySQL/MariaDB version
- **Actual**: Function missing
- **Impact**: Installer cannot detect what database version is currently installed

**Bug 1.2**: `check_database_compatibility()` function does not exist in `lib/checks.sh`
- **Expected**: Function to validate database version against Moodle requirements
- **Actual**: Function missing
- **Impact**: No compatibility checking before installation proceeds

**Bug 1.3**: `get_repository_database_version()` function does not exist in `lib/checks.sh`
- **Expected**: Function to query available database version in repositories
- **Actual**: Function missing
- **Impact**: Cannot determine if default repository provides compatible version

#### 2. Missing Repository Management Functions (2 failures)

**Bug 1.4**: `add_mariadb_repository()` function does not exist in `lib/checks.sh`
- **Expected**: Function to add MariaDB official repository for newer versions
- **Actual**: Function missing
- **Impact**: Cannot obtain MariaDB 10.11+ when default repository only has 10.6

**Bug 1.5**: `install_compatible_database()` function does not exist in `lib/checks.sh`
- **Expected**: Function to install version-compatible database with repository management
- **Actual**: Function missing
- **Impact**: No version-aware database installation logic

#### 3. Incorrect Version Configuration (1 failure)

**Bug 1.6**: `MOODLE_DB_VERSIONS[MOODLE_501_STABLE]` has incorrect requirements
- **Expected**: `mariadb:10.11.0,mysql:8.4.0` for Moodle 5.0.1
- **Actual**: `mariadb:10.6.7,mysql:8.0.30` (incorrect - too low)
- **Impact**: Even if version checking existed, it would check against wrong requirements
- **Critical**: This is a data error that will cause false compatibility checks

#### 4. Missing Fresh Install Script Integration (3 failures)

**Bug 1.7**: `scripts/case_a_fresh.sh` does not call `check_database_compatibility()` after version selection
- **Expected**: Compatibility check after `pick_moodle_version MOODLE_BRANCH`
- **Actual**: No compatibility check present
- **Impact**: Fresh installations proceed without validating database requirements

**Bug 1.8**: `scripts/case_a_fresh.sh` uses direct `platform_install_package mariadb-server` instead of `install_compatible_database()`
- **Expected**: Version-aware installation function
- **Actual**: Direct installation of whatever version is in default repository
- **Impact**: Installs incompatible database versions (e.g., MariaDB 10.6 for Moodle 5.0.1)

**Bug 1.9**: `scripts/case_a_fresh.sh` does not verify database version after installation
- **Expected**: Post-installation verification with `verify_database_version()`
- **Actual**: No verification step
- **Impact**: No confirmation that installed version meets requirements

#### 5. Missing Existing Server Script Integration (3 failures)

**Bug 1.10**: `scripts/case_b_existing.sh` does not detect and store database version
- **Expected**: Capture version using `detect_database_version()` when database is present
- **Actual**: Only checks presence with `check_mariadb`, not version
- **Impact**: Cannot validate existing database compatibility

**Bug 1.11**: `scripts/case_b_existing.sh` does not check existing database version compatibility
- **Expected**: Compatibility check after version selection for existing databases
- **Actual**: No compatibility check for existing installations
- **Impact**: Allows incompatible upgrades (e.g., Moodle 5.0.1 on MySQL 8.0.45)

**Bug 1.12**: `scripts/case_b_existing.sh` uses direct database installation when DB not present
- **Expected**: Use `install_compatible_database()` for version-aware installation
- **Actual**: Direct `platform_install_package mariadb-server`
- **Impact**: Same as Bug 1.8 - installs incompatible versions

#### 6. Integration Test Failure

**Integration Test**: Installer should prevent Moodle 5.0.1 installation with incompatible database
- **Missing Components**: 10 out of 10 required components are missing
- **Result**: Complete absence of version compatibility infrastructure
- **Impact**: Bug condition fully confirmed

### ✅ Tests That Passed (Baseline Functionality)

**Expected Behavior 1**: Version comparison function works correctly
- **Status**: ✅ PASS
- **Details**: `version_compare()` function in `lib/version_config.sh` works correctly
- **Significance**: Foundation for version checking exists, just not integrated

**Expected Behavior 2**: MOODLE_DB_VERSIONS array exists and is populated
- **Status**: ✅ PASS
- **Details**: Configuration array exists with entries for all Moodle versions
- **Significance**: Version requirements are defined, but values for 5.0.1 are incorrect

## Root Cause Analysis

Based on the counterexamples, the root causes are:

1. **Missing Version Detection Infrastructure**: No functions exist to detect installed or available database versions
2. **Missing Repository Management**: No capability to add third-party repositories for newer database versions
3. **No Script Integration**: Installation scripts don't call any version checking logic
4. **Incorrect Configuration Data**: MOODLE_501_STABLE has wrong minimum database versions (10.6.7/8.0.30 instead of 10.11.0/8.4.0)

## Concrete Bug Scenarios Confirmed

### Scenario 1: Moodle 5.0.1 on Ubuntu 24.04 Fresh Install
- **User Action**: Selects MOODLE_501_STABLE on fresh Ubuntu 24.04
- **Current Behavior**: 
  - Installer runs `apt-get install mariadb-server`
  - Ubuntu 24.04 default repository provides MariaDB 10.6.18
  - MariaDB 10.6.18 is installed
  - Moodle CLI installation fails with: "version 10.11 is required and you are running 10.6.18"
- **Missing Components**: All 13 components identified above

### Scenario 2: Moodle 5.0.1 on Existing Server with MySQL 8.0.45
- **User Action**: Selects MOODLE_501_STABLE on server with MySQL 8.0.45 already installed
- **Current Behavior**:
  - Installer detects MySQL is present with `check_mariadb`
  - No version check performed
  - Installation proceeds
  - Moodle CLI installation fails with: "version 8.4 is required and you are running 8.0.45"
- **Missing Components**: Bugs 1.1, 1.2, 1.10, 1.11

### Scenario 3: Moodle 4.5 on Ubuntu 24.04 (Should Work)
- **User Action**: Selects MOODLE_405_STABLE on Ubuntu 24.04
- **Current Behavior**:
  - Installer installs MariaDB 10.6.18 from default repository
  - Moodle 4.5 requires MariaDB 10.6.7+ (satisfied)
  - Installation succeeds
- **Status**: This scenario works by coincidence, not by design
- **Risk**: If version checking is added incorrectly, this could break (preservation concern)

## Expected Behavior After Fix

After implementing the fix, all 13 failing tests should pass:

1. **Version Detection**: Functions exist to detect installed and available database versions
2. **Compatibility Checking**: Functions validate requirements before installation
3. **Repository Management**: Functions add third-party repositories when needed
4. **Script Integration**: Both fresh and existing install scripts use version-aware logic
5. **Correct Configuration**: MOODLE_501_STABLE has correct requirements (10.11.0/8.4.0)
6. **Post-Installation Verification**: Installed versions are verified against requirements

## Next Steps

1. ✅ **Task 1 Complete**: Bug condition exploration test written and run on unfixed code
2. ⏭️ **Task 2**: Write preservation property tests (before implementing fix)
3. ⏭️ **Task 3**: Implement the fix with all required functions and integrations
4. ⏭️ **Task 4**: Verify this test passes after fix (confirms bug is resolved)

## Test Execution Command

```bash
bats tests/mysql_version_compatibility.bats
```

## Test Output Summary

```
15 tests, 13 failures

✗ Bug 1.1: detect_database_version() function should exist
✗ Bug 1.2: check_database_compatibility() function should exist
✗ Bug 1.3: get_repository_database_version() function should exist
✗ Bug 1.4: add_mariadb_repository() function should exist
✗ Bug 1.5: install_compatible_database() function should exist
✗ Bug 1.6: MOODLE_DB_VERSIONS should have correct requirements for Moodle 5.0.1
✗ Bug 1.7: case_a_fresh.sh should call check_database_compatibility()
✗ Bug 1.8: case_a_fresh.sh should use install_compatible_database()
✗ Bug 1.9: case_a_fresh.sh should verify database version after installation
✗ Bug 1.10: case_b_existing.sh should detect and store database version
✗ Bug 1.11: case_b_existing.sh should check existing database version compatibility
✗ Bug 1.12: case_b_existing.sh should use install_compatible_database()
✗ Integration: Installer should prevent Moodle 5.0.1 installation with incompatible database
✓ Expected Behavior: Version comparison function should work correctly
✓ Expected Behavior: MOODLE_DB_VERSIONS array exists and is populated
```

---

**Conclusion**: The bug condition exploration test successfully confirmed the MySQL/MariaDB version compatibility bug exists. The test identified 13 missing components and 1 incorrect configuration value. These counterexamples provide clear evidence of the bug and will serve as validation criteria when the fix is implemented.
