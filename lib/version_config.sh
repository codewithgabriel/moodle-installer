#!/usr/bin/env bash
# lib/version_config.sh — Version-specific configuration and requirements

# Minimum PHP version for each Moodle version
declare -A MOODLE_PHP_VERSIONS=(
  ["MOODLE_401_STABLE"]="7.4"
  ["MOODLE_402_STABLE"]="8.0"
  ["MOODLE_403_STABLE"]="8.0"
  ["MOODLE_404_STABLE"]="8.1"
  ["MOODLE_405_STABLE"]="8.1"
  ["MOODLE_501_STABLE"]="8.1"
  ["main"]="8.1"
)

# Database version requirements (format: "mariadb:min_version,mysql:min_version")
declare -A MOODLE_DB_VERSIONS=(
  ["MOODLE_401_STABLE"]="mariadb:10.4.0,mysql:5.7.0"
  ["MOODLE_402_STABLE"]="mariadb:10.5.0,mysql:8.0.0"
  ["MOODLE_403_STABLE"]="mariadb:10.5.0,mysql:8.0.0"
  ["MOODLE_404_STABLE"]="mariadb:10.6.7,mysql:8.0.30"
  ["MOODLE_405_STABLE"]="mariadb:10.6.7,mysql:8.0.30"
  ["MOODLE_501_STABLE"]="mariadb:10.6.7,mysql:8.0.30"
  ["main"]="mariadb:10.6.7,mysql:8.0.30"
)

# Required PHP extensions for each version
declare -A MOODLE_PHP_EXTENSIONS=(
  ["MOODLE_401_STABLE"]="mysql xml mbstring curl zip gd intl soap redis opcache"
  ["MOODLE_402_STABLE"]="mysql xml mbstring curl zip gd intl soap redis opcache"
  ["MOODLE_403_STABLE"]="mysql xml mbstring curl zip gd intl soap redis opcache"
  ["MOODLE_404_STABLE"]="mysql xml mbstring curl zip gd intl soap redis opcache"
  ["MOODLE_405_STABLE"]="mysql xml mbstring curl zip gd intl soap redis opcache"
  ["MOODLE_501_STABLE"]="mysql xml mbstring curl zip gd intl soap redis opcache sodium"
  ["main"]="mysql xml mbstring curl zip gd intl soap redis opcache sodium"
)

# ── Version Information Functions ─────────────────────────────

get_min_php_version() {
  local branch="$1"
  echo "${MOODLE_PHP_VERSIONS[$branch]:-8.1}"
}

get_required_php_extensions() {
  local branch="$1"
  echo "${MOODLE_PHP_EXTENSIONS[$branch]:-mysql xml mbstring curl zip gd intl soap redis opcache}"
}

get_database_requirements() {
  local branch="$1"
  echo "${MOODLE_DB_VERSIONS[$branch]:-mariadb:10.6.7,mysql:8.0.30}"
}

# ── PHP Configuration ─────────────────────────────────────────

apply_php_config() {
  local branch="$1"
  local php_ini="$2"
  
  if [[ ! -f "$php_ini" ]]; then
    warn "PHP ini file not found: $php_ini"
    return 1
  fi
  
  # Create backup before modifying (cross-platform compatible)
  cp "$php_ini" "${php_ini}.bak" 2>/dev/null || true
  
  # Base configuration for all versions
  # Use platform-specific sed
  if [[ "$PLATFORM" == "linux" ]]; then
    sed -i 's/^;\?max_input_vars\s*=.*/max_input_vars = 5000/' "$php_ini"
    sed -i 's/^;\?upload_max_filesize\s*=.*/upload_max_filesize = 512M/' "$php_ini"
    sed -i 's/^;\?post_max_size\s*=.*/post_max_size = 512M/' "$php_ini"
    sed -i 's/^;\?memory_limit\s*=.*/memory_limit = 256M/' "$php_ini"
    sed -i 's/^;\?max_execution_time\s*=.*/max_execution_time = 300/' "$php_ini"
    sed -i 's/^;\?opcache\.enable\s*=.*/opcache.enable = 1/' "$php_ini"
  else
    # BSD/macOS/Windows - use backup file explicitly
    sed -i.bak 's/^;\?max_input_vars\s*=.*/max_input_vars = 5000/' "$php_ini"
    sed -i.bak 's/^;\?upload_max_filesize\s*=.*/upload_max_filesize = 512M/' "$php_ini"
    sed -i.bak 's/^;\?post_max_size\s*=.*/post_max_size = 512M/' "$php_ini"
    sed -i.bak 's/^;\?memory_limit\s*=.*/memory_limit = 256M/' "$php_ini"
    sed -i.bak 's/^;\?max_execution_time\s*=.*/max_execution_time = 300/' "$php_ini"
    sed -i.bak 's/^;\?opcache\.enable\s*=.*/opcache.enable = 1/' "$php_ini"
  fi
  
  # Version-specific optimizations
  case "$branch" in
    MOODLE_501_STABLE|main)
      # Moodle 5.1+ benefits from increased OPcache
      if [[ "$PLATFORM" == "linux" ]]; then
        sed -i 's/^;\?opcache\.memory_consumption\s*=.*/opcache.memory_consumption = 256/' "$php_ini"
        sed -i 's/^;\?opcache\.interned_strings_buffer\s*=.*/opcache.interned_strings_buffer = 16/' "$php_ini"
        sed -i 's/^;\?opcache\.max_accelerated_files\s*=.*/opcache.max_accelerated_files = 10000/' "$php_ini"
      else
        sed -i.bak 's/^;\?opcache\.memory_consumption\s*=.*/opcache.memory_consumption = 256/' "$php_ini"
        sed -i.bak 's/^;\?opcache\.interned_strings_buffer\s*=.*/opcache.interned_strings_buffer = 16/' "$php_ini"
        sed -i.bak 's/^;\?opcache\.max_accelerated_files\s*=.*/opcache.max_accelerated_files = 10000/' "$php_ini"
      fi
      ;;
    *)
      # Moodle 4.x versions
      if [[ "$PLATFORM" == "linux" ]]; then
        sed -i 's/^;\?opcache\.memory_consumption\s*=.*/opcache.memory_consumption = 128/' "$php_ini"
        sed -i 's/^;\?opcache\.interned_strings_buffer\s*=.*/opcache.interned_strings_buffer = 8/' "$php_ini"
        sed -i 's/^;\?opcache\.max_accelerated_files\s*=.*/opcache.max_accelerated_files = 4000/' "$php_ini"
      else
        sed -i.bak 's/^;\?opcache\.memory_consumption\s*=.*/opcache.memory_consumption = 128/' "$php_ini"
        sed -i.bak 's/^;\?opcache\.interned_strings_buffer\s*=.*/opcache.interned_strings_buffer = 8/' "$php_ini"
        sed -i.bak 's/^;\?opcache\.max_accelerated_files\s*=.*/opcache.max_accelerated_files = 4000/' "$php_ini"
      fi
      ;;
  esac
  
  return 0
}

# ── Version-Specific Config.php Settings ──────────────────────

generate_version_config() {
  local branch="$1"
  
  # Return version-specific configuration snippets
  case "$branch" in
    MOODLE_501_STABLE|main)
      # Moodle 5.1+ specific settings
      cat <<'EOF'
// Enhanced caching for Moodle 5.1+
$CFG->cachejs = true;
$CFG->yuicomboloading = true;
EOF
      ;;
    *)
      # Standard settings for Moodle 4.x
      echo "// Standard Moodle 4.x configuration"
      ;;
  esac
}

# ── Version Comparison Helper ─────────────────────────────────

version_compare() {
  local version1="$1"
  local operator="$2"
  local version2="$3"
  
  # Use sort -V for version comparison
  case "$operator" in
    ">=")
      [[ "$(printf '%s\n' "$version1" "$version2" | sort -V | head -1)" == "$version2" ]]
      ;;
    ">")
      [[ "$version1" != "$version2" ]] && version_compare "$version1" ">=" "$version2"
      ;;
    "<=")
      [[ "$(printf '%s\n' "$version1" "$version2" | sort -V | tail -1)" == "$version2" ]]
      ;;
    "<")
      [[ "$version1" != "$version2" ]] && version_compare "$version1" "<=" "$version2"
      ;;
    "==")
      [[ "$version1" == "$version2" ]]
      ;;
    *)
      error "Unknown operator: $operator"
      return 1
      ;;
  esac
}

# ── Version Display Name ──────────────────────────────────────

get_version_display_name() {
  local branch="$1"
  case "$branch" in
    MOODLE_401_STABLE) echo "4.1" ;;
    MOODLE_402_STABLE) echo "4.2" ;;
    MOODLE_403_STABLE) echo "4.3" ;;
    MOODLE_404_STABLE) echo "4.4" ;;
    MOODLE_405_STABLE) echo "4.5" ;;
    MOODLE_501_STABLE) echo "5.1" ;;
    main) echo "main" ;;
    *) echo "unknown" ;;
  esac
}

get_branch_from_version() {
  local version="$1"
  case "$version" in
    4.1) echo "MOODLE_401_STABLE" ;;
    4.2) echo "MOODLE_402_STABLE" ;;
    4.3) echo "MOODLE_403_STABLE" ;;
    4.4) echo "MOODLE_404_STABLE" ;;
    4.5) echo "MOODLE_405_STABLE" ;;
    5.1) echo "MOODLE_501_STABLE" ;;
    main) echo "main" ;;
    *) echo "" ;;
  esac
}
