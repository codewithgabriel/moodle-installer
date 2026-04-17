# Production Critical Bugs - Counterexamples Found

**Test Date**: $(date)
**Test File**: tests/production_critical_bugs.bats
**Status**: FAILED (as expected on unfixed code)

## Summary

- **Total Bugs Tested**: 15
- **Bugs Confirmed**: 14
- **Bugs Already Fixed**: 1 (Bug 1.12 - password generation)

## Counterexamples by Bug

### Bug 1.1: Strict Mode Silent Aborts ❌ CONFIRMED
**Expected Behavior**: Commands with expected non-zero exits should use `set +e` or `|| true`
**Actual Behavior**: 
- `install.sh` has `set -euo pipefail` at line 8
- `lib/checks.sh` functions (`check_webserver`, `check_php_version`, `check_mariadb`) do NOT wrap detection commands with `set +e`
- This causes silent script exits when commands like `command -v apache2` return non-zero

**Counterexample**: Running `check_webserver()` on a system without Apache will cause silent abort

---

### Bug 1.2: Data Loss on Re-run ❌ CONFIRMED
**Expected Behavior**: `handle_moodle_dir` should check for existing database and require explicit confirmation
**Actual Behavior**:
- No database existence check using `mysql_root -e "USE \`${DB_NAME}\`;"`
- No warning about database deletion
- No double confirmation requirement

**Counterexample**: Re-running installer on existing Moodle will drop database without warning

---

### Bug 1.3: Disk Space Exhaustion ❌ CONFIRMED
**Expected Behavior**: `run_preflight` should call `check_moodle_disk_space`
**Actual Behavior**:
- `run_preflight()` in `lib/checks.sh` does NOT call `check_moodle_disk_space`
- Function exists but is never invoked

**Counterexample**: Installing on system with <2GB free space will fail mid-install

---

### Bug 1.4: Credential Exposure ❌ CONFIRMED
**Expected Behavior**: Credentials written to `$HOME` with security warning
**Actual Behavior**:
- `scripts/case_a_fresh.sh` line 289: `CREDS_FILE="$HOME/moodle-credentials.txt"`
- File IS written to $HOME (good)
- BUT no "SECURITY WARNING" header in the file content

**Counterexample**: Credentials file lacks warning to delete after use

---

### Bug 1.5: Log File Leaks ❌ CONFIRMED
**Expected Behavior**: `moodle-install.log` and `*-credentials.txt` in `.gitignore`
**Actual Behavior**:
- `.gitignore` does NOT contain `moodle-install.log`
- `.gitignore` does NOT contain `*-credentials.txt` pattern

**Counterexample**: Log files can be accidentally committed to public repositories

---

### Bug 1.6: No Rollback Mechanism ❌ CONFIRMED
**Expected Behavior**: `trap 'rollback_on_error' ERR` and rollback log creation
**Actual Behavior**:
- No `trap` statement in `scripts/case_a_fresh.sh`
- No rollback mechanism implemented

**Counterexample**: Failed installation leaves server in broken state with no cleanup

---

### Bug 1.7: Git Integrity Verification ❌ CONFIRMED
**Expected Behavior**: `VERIFY_GIT_INTEGRITY` option and `git verify-commit`
**Actual Behavior**:
- `fetch_moodle()` in `lib/utils.sh` does NOT check for `VERIFY_GIT_INTEGRITY`
- No `git verify-commit` call

**Counterexample**: Git clones have no integrity verification, vulnerable to MITM attacks

---

### Bug 1.8: CI Environment Hangs ❌ CONFIRMED
**Expected Behavior**: `export DEBIAN_FRONTEND=noninteractive` at start of installation
**Actual Behavior**:
- `scripts/case_a_fresh.sh` uses `DEBIAN_FRONTEND=noninteractive` inline with apt-get commands
- NOT exported globally, so some commands may still prompt

**Counterexample**: CI environments may hang on interactive prompts

---

### Bug 1.9: Debian PPA Failure ❌ CONFIRMED
**Expected Behavior**: Check `$ID` from `/etc/os-release` and use Sury repo for Debian
**Actual Behavior**:
- No `source /etc/os-release` before PPA addition
- Always uses `ppa:ondrej/php` (Ubuntu-specific)
- No Debian alternative

**Counterexample**: Installation fails on Debian systems with PPA error

---

### Bug 1.10: Moodledata Permissions ❌ CONFIRMED
**Expected Behavior**: `chmod 750`, `.htaccess` with "Require all denied"
**Actual Behavior**:
- `scripts/case_a_fresh.sh` line 263: `platform_set_permissions "$MOODLE_DATA" "$web_user:$web_user" "770"`
- Uses 770, not 750
- No `.htaccess` creation

**Counterexample**: Moodledata directory has overly permissive permissions

---

### Bug 1.11: Prompt Timeouts ❌ CONFIRMED
**Expected Behavior**: `read -t 300` in prompt functions
**Actual Behavior**:
- `lib/utils.sh` `prompt()` function uses `read -rp` without timeout
- `prompt_secret()` uses `read -rsp` without timeout

**Counterexample**: Unattended installations hang forever on prompts

---

### Bug 1.12: Weak Password Generation ✅ ALREADY FIXED
**Expected Behavior**: `generate_password` uses `/dev/urandom`
**Actual Behavior**:
- `lib/utils.sh` line 127: `tr -dc 'A-Za-z0-9@#%^&*' </dev/urandom | head -c 20`
- Already using `/dev/urandom` (cryptographically secure)

**Status**: This bug has been fixed in the codebase

---

### Bug 1.13: MySQL Root Authentication ❌ CONFIRMED
**Expected Behavior**: `verify_mysql_root_access()` function exists and is called
**Actual Behavior**:
- No `verify_mysql_root_access()` function in `lib/checks.sh`
- No verification call in `scripts/case_a_fresh.sh`

**Counterexample**: MySQL root access may fail silently, leaving database unsecured

---

### Bug 1.14: Firewall Not Configured ❌ CONFIRMED
**Expected Behavior**: `configure_firewall()` function exists and enables ufw
**Actual Behavior**:
- No `configure_firewall()` function in `lib/checks.sh`
- `scripts/case_a_fresh.sh` line 349-356 has basic ufw commands but no comprehensive firewall setup
- No call to dedicated firewall configuration function

**Counterexample**: All ports remain open, exposing unnecessary services

---

### Bug 1.15: CI/CD Secret Leaks ❌ CONFIRMED
**Expected Behavior**: Generated files have "WARNING" comments about secrets
**Actual Behavior**:
- `scripts/cicd_setup.sh` generates `deploy.yml` without warning header
- No "WARNING: Never commit secrets" comment in generated workflow

**Counterexample**: Users may accidentally commit secrets to generated CI/CD files

---

## Test Results

```
16 tests, 15 failures

✗ Bug 1.1: Strict mode should NOT cause silent aborts on expected failures
✗ Bug 1.2: Re-run should require confirmation before data loss
✗ Bug 1.3: Disk space should be checked before installation
✗ Bug 1.4: Credentials file should be secure and outside web root
✗ Bug 1.5: Log files should be in .gitignore
✗ Bug 1.6: Rollback mechanism should exist for failed installations
✗ Bug 1.7: Git clone should have integrity verification option
✗ Bug 1.8: DEBIAN_FRONTEND should be set for CI environments
✗ Bug 1.9: OS detection should use correct PHP repository for Debian
✗ Bug 1.10: Moodledata should have secure permissions (750) and .htaccess
✗ Bug 1.11: Prompt commands should have timeout to prevent hangs
✓ Bug 1.12: Passwords should use /dev/urandom not $RANDOM (ALREADY FIXED)
✗ Bug 1.13: MySQL root access should be verified after setup
✗ Bug 1.14: Firewall should be configured after installation
✗ Bug 1.15: CI/CD templates should have secret warnings
✗ Integration: All 15 production critical bugs should be fixed
```

## Conclusion

The bug exploration tests successfully confirmed **14 out of 15 production critical bugs** exist in the unfixed codebase. Bug 1.12 (weak password generation) has already been fixed. These tests will serve as validation when fixes are implemented - they should all pass after the fixes are complete.

## Next Steps

1. Implement fixes for bugs 1.1-1.11, 1.13-1.15 (14 bugs)
2. Re-run these tests to verify fixes work correctly
3. Ensure Bug 1.12 remains fixed (already using /dev/urandom)
4. Run preservation tests to ensure no regressions
