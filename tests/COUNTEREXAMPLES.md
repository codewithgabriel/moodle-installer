# Bug Condition Exploration - Counterexamples Found

**Test Date:** $(date)
**Test Status:** FAILED (as expected - confirms bugs exist)
**Bugs Found:** 4 critical bugs remaining in unfixed code

## Summary

The bug exploration test was run on the UNFIXED codebase and successfully identified 4 remaining critical defects that need to be fixed. Additionally, 9 bugs were found to have already been fixed in the codebase.

## Counterexamples (Bugs Confirmed Present)

### Bug 1.2: Missing Library Dependency Guard
**Requirement:** 1.2  
**Status:** FAILED ✗  
**Counterexample:**
- File: `install.sh`
- Expected: Explicit dependency order comment `# DEPENDENCY ORDER: colors → utils → checks`
- Actual: No dependency guard comment found
- Impact: If a maintainer reorders the source statements, color functions will break silently in downstream scripts

### Bug 1.5: Background Job Status Not Captured
**Requirement:** 1.5  
**Status:** FAILED ✗  
**Counterexample:**
- File: `lib/utils.sh`, function `run_cmd`
- Expected: After `wait "$pid"`, capture status with `status=$?` or `local status=$?`
- Actual: `wait "$pid"` is called but exit status is not captured for checking
- Impact: Background job failures may not be properly detected and handled

### Bug 1.6: Incomplete Error Output Formatting
**Requirement:** 1.6  
**Status:** FAILED ✗  
**Counterexample:**
- File: `lib/utils.sh`, function `run_cmd`
- Expected: Comprehensive error output with:
  - Timestamp (ISO 8601 or human-readable)
  - Full command that failed
  - Exit code
  - Complete stderr output
  - Visual separators (==== or ----)
- Actual: Basic error message present but missing comprehensive formatting elements
- Impact: When commands fail, users don't get sufficient diagnostic information to troubleshoot

### Bug 1.11: Missing Input Validation
**Requirement:** 1.11  
**Status:** FAILED ✗  
**Counterexample:**
- Files: `scripts/case_a_fresh.sh`, `scripts/case_b_existing.sh`, `scripts/case_c_cpanel.sh`
- Expected: Input validation for:
  - Domain: non-empty, matches hostname pattern
  - Email: contains `@`, matches basic email pattern
  - Paths: no unquoted spaces, no special characters that break sed
  - Passwords: escape or reject characters that break sed substitution or MySQL heredocs
- Actual: No validation functions found, invalid inputs accepted
- Impact: Invalid inputs (empty domain, malformed email, paths with spaces, passwords with special chars) proceed without validation and produce broken config files or silent SQL errors

## Bugs Already Fixed (Skipped in Test)

The following 9 bugs were found to have already been fixed in the codebase:

1. **Bug 1.3:** Status messages in `check_webserver` already redirect to stderr ✓
2. **Bug 1.4:** PHP status check already uses proper conditionals (no command execution) ✓
3. **Bug 1.7:** Credentials file already written to `$HOME` (not `$SCRIPT_DIR`) ✓
4. **Bug 1.8:** Directory permissions already use `0750` (not `0777`) ✓
5. **Bug 1.9:** Passwords already written to `/dev/tty` (not captured by tee) ✓
6. **Bug 1.10:** SSH user already defaults to non-root (`deploy`) with security warning ✓
7. **Bug 1.12:** cPanel config.php already has clear guidance and copy option ✓
8. **Bug 1.13:** Main menu already uses `while true` loop (not recursion) ✓
9. **Bug 1.14:** Internet connectivity already checked in `run_preflight` ✓

## Test Results

```
15 tests total
- 1 passed (Bug 1.1 - no brace artifact)
- 4 failed (Bugs 1.2, 1.5, 1.6, 1.11 - confirmed present)
- 9 skipped (already fixed)
- 1 integration test failed (confirmed 4 bugs present)
```

## Next Steps

The fix implementation (Task 3) should address the 4 remaining bugs:
1. Add library dependency guard comment in `install.sh`
2. Capture background job exit status in `run_cmd`
3. Implement comprehensive error output formatting
4. Add input validation for domain, email, path, and password fields

## Notes

- The test is designed to FAIL on unfixed code - this is the expected and correct behavior
- When the fix is implemented, this same test should PASS, confirming all bugs are resolved
- The test uses property-based testing principles to validate behavior across the bug conditions
