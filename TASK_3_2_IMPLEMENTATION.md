# Task 3.2 Implementation Summary

## Overview
Task 3.2 adds repository management and compatible database installation functions to `lib/checks.sh` to support automatic installation of database versions that meet Moodle requirements.

## Functions Implemented

### 1. `add_mariadb_repository()`
**Purpose**: Adds MariaDB official repository for newer versions not available in default system repositories.

**Parameters**:
- `$1` (required_version): MariaDB version to install (default: 10.11)

**Functionality**:
- Detects OS distribution (Ubuntu/Debian) from `/etc/os-release`
- Installs prerequisites (curl, gnupg) if not present
- Downloads and adds MariaDB GPG key using `curl -fsSL https://mariadb.org/mariadb_release_signing_key.asc | gpg --dearmor`
- Stores key in `/usr/share/keyrings/mariadb-keyring.gpg`
- Creates `/etc/apt/sources.list.d/mariadb.list` with repository configuration
- Repository URL format: `https://mirror.mariadb.org/repo/{major.minor}/{os_id} {codename} main`
- Runs `apt-get update` to refresh package lists
- Verifies repository was added by checking `apt-cache policy mariadb-server` output

**Return Codes**:
- 0: Success
- 1: Failure (OS detection, GPG key, repository creation, or verification failed)

**Example Usage**:
```bash
add_mariadb_repository "10.11.0"
```

### 2. `install_compatible_database()`
**Purpose**: Installs a database version compatible with the selected Moodle version.

**Parameters**:
- `$1` (branch): Moodle branch (e.g., MOODLE_501_STABLE)

**Functionality**:
- Retrieves database requirements from `MOODLE_DB_VERSIONS` array via `get_database_requirements()`
- Parses requirements using `parse_db_requirements()` to extract MariaDB minimum version
- Checks default repository version using `get_repository_database_version()`
- Compares repository version against requirements using `version_compare()`
- If default repository is insufficient:
  - Calls `add_mariadb_repository()` to add MariaDB official repository
  - Attempts to install versioned package (e.g., `mariadb-server-10.11`)
  - Falls back to `mariadb-server` if versioned package not available
- If default repository is sufficient:
  - Installs `mariadb-server` from default repository
- Calls `verify_database_version()` to confirm installed version meets requirements

**Return Codes**:
- 0: Success (compatible database installed and verified)
- 1: Failure (missing parameters, repository management failed, installation failed, or verification failed)

**Example Usage**:
```bash
install_compatible_database "MOODLE_501_STABLE"
```

### 3. `verify_database_version()`
**Purpose**: Verifies that the installed database version meets requirements for the selected Moodle version.

**Parameters**:
- `$1` (branch): Moodle branch (e.g., MOODLE_501_STABLE)

**Functionality**:
- Retrieves database requirements using `parse_db_requirements()`
- Detects installed database version using `detect_database_version()`
- Parses database type (mariadb/mysql) and version from detection result
- Selects appropriate minimum version based on database type
- Compares installed version against minimum using `version_compare()`
- Displays success message if version is sufficient
- Displays error message with details if version is insufficient

**Return Codes**:
- 0: Success (installed version meets requirements)
- 1: Failure (missing parameters, cannot detect version, or version insufficient)

**Example Usage**:
```bash
verify_database_version "MOODLE_501_STABLE"
```

## Integration Points

### Dependencies
These functions depend on existing functions in `lib/checks.sh` and `lib/version_config.sh`:
- `get_database_requirements()` - Retrieves requirements from MOODLE_DB_VERSIONS array
- `parse_db_requirements()` - Parses requirement string into mariadb_min and mysql_min
- `detect_database_version()` - Detects installed database type and version
- `get_repository_database_version()` - Queries available version in repositories
- `version_compare()` - Compares version strings
- `apt_install()` - Installs packages with proper DEBIAN_FRONTEND settings
- `info()`, `success()`, `error()`, `warn()` - Logging functions

### Usage in Installation Scripts
These functions will be called from:
- `scripts/case_a_fresh.sh` - Fresh installation flow
- `scripts/case_b_existing.sh` - Existing server installation flow

**Typical call sequence**:
1. User selects Moodle version
2. `check_database_compatibility()` validates requirements (already implemented in task 3.1)
3. `install_compatible_database()` installs appropriate database version
4. Database setup continues (create database, user, privileges)

## Testing

### Unit Tests
Basic function tests in `test_task_3_2_functions.sh`:
- ✅ Function existence verification
- ✅ Requirements parsing for Moodle 5.0.1
- ✅ Version comparison logic
- ✅ Repository version detection (when apt-cache available)

### Integration Tests
Full integration tests require:
- Root/sudo privileges
- Network connectivity (to download GPG keys and packages)
- Ubuntu/Debian system with apt package manager

Integration tests will be performed during:
- Task 3.3: Update case_a_fresh.sh
- Task 3.4: Update case_b_existing.sh
- Task 3.6: Bug condition exploration test verification

## Requirements Validation

**Validates Requirements**:
- 1.5: Installer adds necessary third-party repositories for Moodle 5.0+
- 2.3: Installer automatically adds appropriate third-party repository when default is insufficient
- 2.6: Installer ensures MySQL 8.4+ or MariaDB 10.11+ for Moodle 5.0.1
- 2.7: Installer uses appropriate repository for detected OS distribution and handles GPG key securely
- 2.8: Installer verifies installed version meets requirements and logs result

## Implementation Notes

### Security Considerations
- GPG key is downloaded over HTTPS (`curl -fsSL`)
- Key is stored in `/usr/share/keyrings/` (standard location for APT keyrings)
- Repository configuration uses `signed-by` directive for key verification

### Error Handling
- All functions return proper exit codes (0 for success, 1 for failure)
- Detailed error messages guide troubleshooting
- Prerequisites (curl, gnupg) are installed automatically if missing

### OS Compatibility
- Supports Ubuntu and Debian distributions
- Uses `VERSION_CODENAME` from `/etc/os-release` for repository configuration
- Gracefully handles unsupported distributions with clear error messages

### Repository Management
- Uses MariaDB mirror network (`mirror.mariadb.org`) for reliability
- Repository URL includes major.minor version (e.g., 10.11) for version-specific packages
- Verifies repository addition by checking `apt-cache policy` output

### Package Selection
- Prefers versioned packages (e.g., `mariadb-server-10.11`) when available
- Falls back to generic `mariadb-server` package if versioned package not found
- Uses `apt-cache show` to check package availability before installation

## Next Steps

Task 3.3 and 3.4 will integrate these functions into the installation scripts:
- Replace direct `platform_install_package mariadb-server` calls
- Add compatibility checks before database installation
- Add post-installation verification steps
