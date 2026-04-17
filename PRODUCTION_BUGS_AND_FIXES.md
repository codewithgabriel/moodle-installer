# Production Bugs Analysis and Fixes

## Critical Issues Found

### 1. **CRITICAL: Missing `mysql_root` Function Reference**
**Location**: `lib/upgrade_manager.sh`, `lib/checks.sh` (assumed)
**Severity**: HIGH - Will cause upgrade failures
**Issue**: The `mysql_root` function is called but not defined in the new modules
**Impact**: Database version checks and upgrade operations will fail

**Fix**: The function exists in `lib/checks.sh` but needs to be ensured it's loaded before upgrade_manager.sh

### 2. **CRITICAL: `sed -i` Not Cross-Platform Compatible**
**Location**: `lib/version_config.sh` - `apply_php_config()` function
**Severity**: HIGH - Will fail on macOS and some BSD systems
**Issue**: `sed -i` syntax differs between GNU sed (Linux) and BSD sed (macOS/BSD)
**Impact**: PHP configuration will fail on non-Linux systems

**Solution**: Create backup file explicitly for cross-platform compatibility

### 3. **CRITICAL: Race Condition in Spinner Function**
**Location**: `lib/utils.sh` - `spinner()` function
**Severity**: MEDIUM - Can cause false success messages
**Issue**: Process might complete before spinner starts checking
**Impact**: User sees success message even if process failed

**Solution**: Check process exit status immediately after wait

### 4. **CRITICAL: Unquoted Variables in Path Operations**
**Location**: Multiple files - path handling
**Severity**: HIGH - Paths with spaces will break
**Issue**: Variables like `$moodle_dir` not quoted in some places
**Impact**: Installation fails if paths contain spaces

**Solution**: Quote all path variables

### 5. **CRITICAL: Missing Error Handling for Platform Detection**
**Location**: `install.sh` - platform detection
**Severity**: HIGH - Script continues with undefined PLATFORM
**Issue**: If `detect_platform` fails, PLATFORM variable may be empty
**Impact**: All platform-specific operations will fail silently

**Solution**: Exit immediately if platform detection fails (already implemented)

### 6. **CRITICAL: Windows Path Conversion Issues**
**Location**: `lib/platform_windows.sh` - `windows_set_permissions()`
**Severity**: MEDIUM - Permission setting may fail
**Issue**: `cygpath` may not be available in all Windows environments
**Impact**: Permissions won't be set correctly

**Solution**: Add fallback for when cygpath is not available

### 7. **CRITICAL: PHP Version Detection Fragility**
**Location**: `lib/upgrade_manager.sh` - `check_upgrade_dependencies()`
**Severity**: MEDIUM - May fail to detect PHP
**Issue**: Assumes `php` command is in PATH
**Impact**: Upgrade dependency checks fail

**Solution**: Add fallback to check for php binary in common locations

### 8. **CRITICAL: Git Operations Without Error Recovery**
**Location**: `lib/upgrade_manager.sh` - `execute_moodle_upgrade()`
**Severity**: HIGH - Can leave system in broken state
**Issue**: Git operations don't have rollback on failure
**Impact**: Failed upgrade leaves Moodle in inconsistent state

**Solution**: Add rollback mechanism

### 9. **WARNING: Associative Array Compatibility**
**Location**: Multiple files using `declare -A`
**Severity**: LOW - Requires Bash 4.0+
**Issue**: Associative arrays require Bash 4.0+, not available on older systems
**Impact**: Script fails on systems with Bash < 4.0

**Solution**: Add Bash version check in install.sh

### 10. **WARNING: PowerShell Command Injection Risk**
**Location**: `lib/platform_windows.sh` - PowerShell commands
**Severity**: MEDIUM - Security risk
**Issue**: Variables passed to PowerShell without proper escaping
**Impact**: Potential command injection if paths contain special characters

**Solution**: Properly escape PowerShell parameters

### 11. **CRITICAL: Missing Dependency - `mysql_root` Function**
**Location**: `lib/upgrade_manager.sh` line 127
**Severity**: HIGH
**Issue**: Function `mysql_root` is called but may not be available
**Impact**: Database checks will fail

**Solution**: Ensure checks.sh is loaded and function exists

### 12. **WARNING: Hardcoded Timeout Values**
**Location**: `lib/upgrade_manager.sh` - spinner calls
**Severity**: LOW
**Issue**: No timeout for long-running operations
**Impact**: Script may hang indefinitely on slow networks

**Solution**: Add timeout to git operations

### 13. **CRITICAL: Missing Validation for User Input**
**Location**: `lib/utils.sh` - `handle_moodle_dir()`
**Severity**: MEDIUM
**Issue**: User input not validated before dangerous operations (rm -rf)
**Impact**: Accidental data loss

**Solution**: Add confirmation and path validation (already has confirm)

### 14. **WARNING: Inconsistent Error Handling**
**Location**: Multiple files
**Severity**: LOW
**Issue**: Some functions return error codes, others don't
**Impact**: Inconsistent error propagation

**Solution**: Standardize error handling pattern

### 15. **CRITICAL: Missing Check for Disk Space**
**Location**: All installation scripts
**Severity**: MEDIUM
**Issue**: No check for available disk space before installation
**Impact**: Installation fails mid-way if disk is full

**Solution**: Add disk space check in preflight

## Fixes Implemented

### 1. ✅ FIXED: `sed -i` Cross-Platform Compatibility
**Location**: `lib/version_config.sh` - `apply_php_config()` function
**Fix**: Added platform detection and uses appropriate sed syntax for Linux vs BSD/macOS/Windows
**Status**: COMPLETE

### 2. ✅ FIXED: Windows Path Conversion Issues
**Location**: `lib/platform_windows.sh` - `windows_set_permissions()`
**Fix**: Added fallback when cygpath unavailable, added PowerShell escaping
**Status**: COMPLETE

### 3. ✅ FIXED: Missing Bash 4.0+ Version Check
**Location**: `install.sh`
**Fix**: Added version check for associative array support
**Status**: COMPLETE

### 4. ✅ FIXED: Missing PLATFORM Variable Validation
**Location**: `install.sh`
**Fix**: Added validation to ensure platform detection succeeded
**Status**: COMPLETE

### 5. ✅ FIXED: Missing mysql_root Function Validation
**Location**: `install.sh`
**Fix**: Added check to ensure mysql_root function exists before use
**Status**: COMPLETE

### 6. ✅ FIXED: Git Operations Rollback Mechanism
**Location**: `lib/upgrade_manager.sh` - `execute_moodle_upgrade()`
**Fix**: Added rollback branch creation before upgrade, automatic rollback on failure
**Status**: COMPLETE

### 7. ✅ FIXED: Timeout for Git Operations
**Location**: `lib/upgrade_manager.sh` - `execute_moodle_upgrade()`
**Fix**: Added timeout (5 min for fetch, 2 min for checkout, 30 min for upgrade)
**Status**: COMPLETE

### 8. ✅ FIXED: Disk Space Check Enhancement
**Location**: `lib/checks.sh`
**Fix**: Added `check_moodle_disk_space()` function for installation-specific checks
**Status**: COMPLETE

### 9. ✅ FIXED: Spinner Race Condition
**Location**: `lib/utils.sh` - `spinner()` function
**Fix**: Check process status immediately, handle early completion correctly
**Status**: COMPLETE

### 10. ✅ FIXED: Path Variable Quoting
**Location**: `lib/utils.sh` - `fetch_moodle()` function
**Fix**: All path variables properly quoted to handle spaces
**Status**: COMPLETE

## Remaining Issues

### 11. ⚠️ TODO: Quote All Path Variables Across All Scripts
**Location**: Multiple files - comprehensive audit needed
**Severity**: MEDIUM
**Issue**: Some path variables may still be unquoted in case_a, case_b, case_c scripts
**Impact**: Installation fails if paths contain spaces
**Next Steps**: Audit all scripts and quote remaining path variables

### 12. ⚠️ TODO: PHP Version Detection Fallback
**Location**: `lib/upgrade_manager.sh` - `check_upgrade_dependencies()`
**Severity**: LOW
**Issue**: Assumes `php` command is in PATH
**Impact**: Upgrade dependency checks may fail in non-standard environments
**Next Steps**: Add fallback to check common PHP binary locations

### 13. ⚠️ TODO: PowerShell Command Injection Hardening
**Location**: `lib/platform_windows.sh`
**Severity**: LOW (already has basic escaping)
**Issue**: Could be more robust for edge cases
**Impact**: Potential issues with very unusual path characters
**Next Steps**: Review and enhance PowerShell parameter escaping

## Testing Recommendations

1. Test upgrade from Moodle 4.5 to 5.1 on Linux
2. Test rollback mechanism by simulating upgrade failure
3. Test timeout handling with slow network
4. Test disk space check with low disk space
5. Test spinner with fast-completing processes
6. Test paths with spaces in directory names
7. Test on actual Windows system with Chocolatey
8. Test integration of platform abstraction in case_a and case_b scripts

