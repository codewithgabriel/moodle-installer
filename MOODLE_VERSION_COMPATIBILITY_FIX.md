# Moodle Version Compatibility Fix

## Issue
User selected Moodle 5.1 (MOODLE_501_STABLE) but system has MySQL 8.0.45.
Moodle 5.1 requires MySQL 8.4+ or MariaDB 10.11+.

## Error Message
```
!! database mysql (8.0.45-0ubuntu0.24.04.1) !!
[System] version 8.4 is required and you are running 8.0.45
```

## Root Cause
The installer doesn't validate database version compatibility before attempting Moodle installation.

## Moodle Version Requirements

| Moodle Version | Min MySQL | Min MariaDB | Min PHP |
|----------------|-----------|-------------|---------|
| 5.1 (501)      | 8.4       | 10.11       | 8.1     |
| 4.5 (405) LTS  | 8.0       | 10.6        | 8.1     |
| 4.4 (404)      | 8.0       | 10.6        | 8.1     |
| 4.3 (403)      | 8.0       | 10.4        | 8.0     |
| 4.2 (402)      | 8.0       | 10.4        | 8.0     |
| 4.1 (401) LTS  | 8.0       | 10.4        | 7.4     |

## Solution

### Immediate Workaround
**Option 1**: Use Moodle 4.5 LTS (recommended)
- Compatible with MySQL 8.0.45
- Long-term support version
- Production-ready

**Option 2**: Upgrade MySQL to 8.4+
```bash
# This requires Ubuntu 24.10+ or manual MySQL 8.4 installation
# Not recommended for production without testing
```

### Proper Fix (To Be Implemented)
Add database version checking function in `lib/checks.sh`:

```bash
check_database_version() {
  local moodle_branch="$1"
  local db_version=""
  local db_type=""
  
  # Detect database type and version
  if mysql_root -e "SELECT VERSION();" 2>/dev/null | grep -qi "mariadb"; then
    db_type="mariadb"
    db_version=$(mysql_root -e "SELECT VERSION();" 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
  else
    db_type="mysql"
    db_version=$(mysql_root -e "SELECT VERSION();" 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
  fi
  
  # Check compatibility based on Moodle version
  case "$moodle_branch" in
    MOODLE_501_STABLE)
      if [[ "$db_type" == "mysql" ]]; then
        if ! version_gte "$db_version" "8.4.0"; then
          error "Moodle 5.1 requires MySQL 8.4+ (you have $db_version)"
          warn "Recommended: Use Moodle 4.5 LTS instead (compatible with MySQL 8.0+)"
          return 1
        fi
      elif [[ "$db_type" == "mariadb" ]]; then
        if ! version_gte "$db_version" "10.11.0"; then
          error "Moodle 5.1 requires MariaDB 10.11+ (you have $db_version)"
          warn "Recommended: Use Moodle 4.5 LTS instead"
          return 1
        fi
      fi
      ;;
    MOODLE_405_STABLE|MOODLE_404_STABLE|MOODLE_403_STABLE|MOODLE_402_STABLE|MOODLE_401_STABLE)
      if [[ "$db_type" == "mysql" ]]; then
        if ! version_gte "$db_version" "8.0.0"; then
          error "Moodle 4.x requires MySQL 8.0+ (you have $db_version)"
          return 1
        fi
      elif [[ "$db_type" == "mariadb" ]]; then
        if ! version_gte "$db_version" "10.4.0"; then
          error "Moodle 4.x requires MariaDB 10.4+ (you have $db_version)"
          return 1
        fi
      fi
      ;;
  esac
  
  success "Database $db_type $db_version is compatible with $moodle_branch"
  return 0
}

version_gte() {
  # Compare versions: return 0 if $1 >= $2
  local ver1="$1" ver2="$2"
  printf '%s\n%s\n' "$ver2" "$ver1" | sort -V -C
}
```

### Integration Points
Call `check_database_version` after version selection in:
- `scripts/case_a_fresh.sh` (after `pick_moodle_version`)
- `scripts/case_b_existing.sh` (after `pick_moodle_version`)

## Recommendation for User

**For your current situation with MySQL 8.0.45:**

1. **Re-run the installer**
2. **Select Moodle 4.5 LTS** (option 2) instead of 5.1
3. Moodle 4.5 is:
   - Fully compatible with MySQL 8.0.45
   - Long-term support (LTS) version
   - Production-ready and stable
   - Receives security updates until 2027

**Why not upgrade MySQL?**
- MySQL 8.4 is very new (released 2024)
- Ubuntu 24.04 LTS ships with MySQL 8.0
- Upgrading MySQL on production systems requires careful planning
- Moodle 4.5 LTS is the recommended choice for most deployments

## Next Steps

This compatibility checking should be added to the production-critical-fixes spec as a new bug or as part of the existing preflight checks enhancement.
