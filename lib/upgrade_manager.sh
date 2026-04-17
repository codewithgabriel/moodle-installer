#!/usr/bin/env bash
# lib/upgrade_manager.sh — Moodle upgrade management and compatibility

# ── Timeout Helper ────────────────────────────────────────────

# Wrapper for timeout command with fallback
run_with_timeout() {
  local seconds="$1"
  shift
  
  if command -v timeout &>/dev/null; then
    timeout "$seconds" "$@"
  else
    # Fallback: run without timeout if command not available
    warn "timeout command not available, running without timeout"
    "$@"
  fi
}

# ── Version Detection ─────────────────────────────────────────

detect_installed_version() {
  local moodle_dir="$1"
  local version_file="$moodle_dir/version.php"
  
  if [[ ! -f "$version_file" ]]; then
    echo "none"
    return 1
  fi
  
  # Extract branch number from version.php
  local branch
  branch=$(grep '$branch' "$version_file" | grep -oP "'\K\d+" | head -1)
  
  if [[ -z "$branch" ]]; then
    echo "unknown"
    return 1
  fi
  
  # Map branch number to version name
  case "$branch" in
    401) echo "4.1" ;;
    402) echo "4.2" ;;
    403) echo "4.3" ;;
    404) echo "4.4" ;;
    405) echo "4.5" ;;
    501) echo "5.1" ;;
    *)   echo "unknown" ;;
  esac
}

# ── Upgrade Path Validation ──────────────────────────────────

validate_upgrade_path() {
  local current="$1"
  local target="$2"
  
  # Define supported upgrade paths
  declare -A UPGRADE_PATHS=(
    ["4.1"]="4.2,4.3,4.4,4.5,5.1"
    ["4.2"]="4.3,4.4,4.5,5.1"
    ["4.3"]="4.4,4.5,5.1"
    ["4.4"]="4.5,5.1"
    ["4.5"]="5.1"
  )
  
  local allowed_targets="${UPGRADE_PATHS[$current]:-}"
  
  if [[ -z "$allowed_targets" ]]; then
    error "Cannot upgrade from Moodle $current"
    error "Current version may be too old or already at the latest version"
    return 1
  fi
  
  if [[ ! ",$allowed_targets," =~ ",$target," ]]; then
    error "Direct upgrade from Moodle $current to $target is not supported"
    error ""
    error "Supported upgrade targets from Moodle $current:"
    echo "$allowed_targets" | tr ',' '\n' | while read -r ver; do
      error "  - Moodle $ver"
    done
    return 1
  fi
  
  # Check for breaking changes
  if [[ "$current" =~ ^4\. && "$target" == "5.1" ]]; then
    warn ""
    warn "Upgrading from Moodle 4.x to 5.1 includes breaking changes:"
    warn "  - PHP 8.1+ required (your current version may be 8.0)"
    warn "  - Database version requirements increased"
    warn "  - Some deprecated features removed"
    warn "  - Configuration changes may be needed"
    warn ""
    confirm "Do you want to continue with the upgrade?" || return 1
  fi
  
  return 0
}

# ── Dependency Checking ───────────────────────────────────────

check_upgrade_dependencies() {
  local target_version="$1"
  
  # Get target branch name
  local target_branch
  target_branch=$(get_branch_from_version "$target_version")
  
  if [[ -z "$target_branch" ]]; then
    error "Unknown target version: $target_version"
    return 1
  fi
  
  local issues=0
  
  # Check PHP version
  local required_php
  required_php=$(get_min_php_version "$target_branch")
  
  local current_php
  current_php=$(php -r 'echo PHP_VERSION;' 2>/dev/null || echo "0.0")
  
  if ! version_compare "$current_php" ">=" "$required_php"; then
    warn "PHP upgrade required: $current_php → $required_php+"
    ((issues++))
  fi
  
  # Check database version
  local db_requirements
  db_requirements=$(get_database_requirements "$target_branch")
  
  if command -v mysql &>/dev/null || command -v mariadb &>/dev/null; then
    local current_db_version
    current_db_version=$(mysql_root -e "SELECT VERSION();" 2>/dev/null | tail -1 || echo "unknown")
    
    if [[ "$current_db_version" =~ MariaDB ]]; then
      local mariadb_version
      mariadb_version=$(echo "$current_db_version" | grep -oP '\d+\.\d+\.\d+' | head -1)
      local required_mariadb
      required_mariadb=$(echo "$db_requirements" | grep -oP 'mariadb:\K[\d.]+')
      
      if [[ -n "$mariadb_version" && -n "$required_mariadb" ]]; then
        if ! version_compare "$mariadb_version" ">=" "$required_mariadb"; then
          warn "MariaDB upgrade may be required: $mariadb_version → $required_mariadb+"
          warn "(This is a recommendation, not a strict requirement)"
        fi
      fi
    fi
  fi
  
  # Check required PHP extensions
  local required_extensions
  required_extensions=$(get_required_php_extensions "$target_branch")
  
  for ext in $required_extensions; do
    if ! php -m 2>/dev/null | grep -qi "^$ext$"; then
      warn "Missing PHP extension: $ext"
      ((issues++))
    fi
  done
  
  if ((issues > 0)); then
    warn ""
    warn "Found $issues dependency issue(s) that need to be resolved"
    warn "The installer can attempt to upgrade these dependencies automatically"
    return 1
  fi
  
  success "All dependencies meet requirements for Moodle $target_version"
  return 0
}

# ── Dependency Upgrade ────────────────────────────────────────

upgrade_dependencies() {
  local current_version="$1"
  local target_version="$2"
  
  write_section "Upgrading System Dependencies"
  
  # Get target branch
  local target_branch
  target_branch=$(get_branch_from_version "$target_version")
  
  local required_php
  required_php=$(get_min_php_version "$target_branch")
  
  local current_php
  current_php=$(php -r 'echo PHP_VERSION;' 2>/dev/null || echo "0.0")
  
  # Upgrade PHP if needed
  if ! version_compare "$current_php" ">=" "$required_php"; then
    info "Upgrading PHP from $current_php to $required_php+"
    
    case "$PLATFORM" in
      linux)
        # Backup current PHP config
        local php_ini
        php_ini=$(php -i 2>/dev/null | grep 'Loaded Configuration File' | awk '{print $5}')
        if [[ -f "$php_ini" ]]; then
          cp "$php_ini" "${php_ini}.backup.$(date +%Y%m%d_%H%M%S)"
          info "PHP configuration backed up"
        fi
        
        # Install new PHP version
        run_cmd "Adding PHP repository" add-apt-repository -y ppa:ondrej/php || true
        run_cmd "Updating packages" apt-get update
        
        local php_major_minor="${required_php%.*}"
        run_cmd "Installing PHP $php_major_minor" platform_install_package "php${php_major_minor}"
        
        # Install required extensions
        local extensions
        extensions=$(get_required_php_extensions "$target_branch")
        for ext in $extensions; do
          platform_install_package "php${php_major_minor}-${ext}" || warn "Could not install php${php_major_minor}-${ext}"
        done
        
        # Update alternatives to use new PHP
        update-alternatives --set php "/usr/bin/php${php_major_minor}" 2>/dev/null || true
        
        # Apply version-specific configuration
        apply_php_config "$target_branch" "/etc/php/${php_major_minor}/apache2/php.ini" 2>/dev/null || true
        apply_php_config "$target_branch" "/etc/php/${php_major_minor}/cli/php.ini" 2>/dev/null || true
        
        # Restart web server
        platform_restart_service apache2 || platform_restart_service nginx || true
        ;;
        
      windows)
        warn "PHP upgrade on Windows requires manual intervention"
        info "Run: choco upgrade php --version=${required_php}"
        confirm "Have you upgraded PHP to ${required_php}+?" || return 1
        ;;
    esac
    
    success "PHP upgraded to $(php -r 'echo PHP_VERSION;' 2>/dev/null || echo 'unknown')"
  fi
  
  # Install any missing extensions
  local required_extensions
  required_extensions=$(get_required_php_extensions "$target_branch")
  
  for ext in $required_extensions; do
    if ! php -m 2>/dev/null | grep -qi "^$ext$"; then
      info "Installing PHP extension: $ext"
      case "$PLATFORM" in
        linux)
          local php_version
          php_version=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || echo "8.1")
          platform_install_package "php${php_version}-${ext}" || warn "Could not install $ext extension"
          ;;
        windows)
          warn "PHP extension $ext may need manual installation on Windows"
          ;;
      esac
    fi
  done
  
  success "All dependencies upgraded"
}

# ── Moodle Upgrade Execution ──────────────────────────────────

execute_moodle_upgrade() {
  local moodle_dir="$1"
  local target_version="$2"
  
  local target_branch
  target_branch=$(get_branch_from_version "$target_version")
  
  if [[ -z "$target_branch" ]]; then
    error "Unknown target version: $target_version"
    return 1
  fi
  
  write_section "Upgrading Moodle to $target_version"
  
  # Backup config.php
  if [[ -f "$moodle_dir/config.php" ]]; then
    local backup_file="$moodle_dir/config.php.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$moodle_dir/config.php" "$backup_file"
    success "config.php backed up to $backup_file"
  fi
  
  # Put site in maintenance mode
  info "Enabling maintenance mode"
  local php_runner
  php_runner=$(platform_get_web_user)
  if [[ "$PLATFORM" == "linux" ]]; then
    php_runner="sudo -u $php_runner"
  fi
  
  $php_runner php "$moodle_dir/admin/cli/maintenance.php" --enable 2>/dev/null || {
    warn "Could not enable maintenance mode (may not be critical)"
  }
  
  # Initialize git if needed
  if [[ ! -d "$moodle_dir/.git" ]]; then
    warn "Moodle directory is not a git repository"
    info "Initializing git repository"
    git -C "$moodle_dir" init
    git -C "$moodle_dir" remote add origin https://github.com/moodle/moodle.git
  fi
  
  # Create rollback point
  local rollback_branch="rollback_$(date +%Y%m%d_%H%M%S)"
  local current_branch
  current_branch=$(git -C "$moodle_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  if [[ -n "$current_branch" ]]; then
    git -C "$moodle_dir" branch "$rollback_branch" 2>/dev/null || true
    info "Rollback point created: $rollback_branch"
  fi
  
  # Fetch new Moodle code with timeout
  info "Fetching Moodle $target_branch"
  run_with_timeout 300 git -C "$moodle_dir" fetch --depth=1 origin "$target_branch" &
  local fetch_pid=$!
  spinner $fetch_pid "Downloading Moodle $target_version..."
  wait $fetch_pid
  local fetch_status=$?
  if [[ $fetch_status -eq 124 ]]; then
    error "Git fetch timed out after 5 minutes"
    return 1
  elif [[ $fetch_status -ne 0 ]]; then
    error "Failed to fetch Moodle code"
    return 1
  fi
  
  # Preserve config.php during checkout
  local config_backup
  if [[ -f "$moodle_dir/config.php" ]]; then
    config_backup=$(cat "$moodle_dir/config.php")
  fi
  
  # Checkout new version with timeout
  info "Switching to $target_branch"
  run_with_timeout 120 git -C "$moodle_dir" checkout -B "$target_branch" "origin/$target_branch" &
  local checkout_pid=$!
  spinner $checkout_pid "Updating Moodle files..."
  wait $checkout_pid
  local checkout_status=$?
  if [[ $checkout_status -eq 124 ]]; then
    error "Git checkout timed out after 2 minutes"
    # Rollback
    if [[ -n "$rollback_branch" ]]; then
      warn "Rolling back to previous version..."
      git -C "$moodle_dir" checkout "$rollback_branch" 2>/dev/null || true
    fi
    return 1
  elif [[ $checkout_status -ne 0 ]]; then
    error "Failed to checkout Moodle code"
    # Rollback
    if [[ -n "$rollback_branch" ]]; then
      warn "Rolling back to previous version..."
      git -C "$moodle_dir" checkout "$rollback_branch" 2>/dev/null || true
    fi
    return 1
  fi
  
  # Restore config.php if git removed it
  if [[ -n "$config_backup" && ! -f "$moodle_dir/config.php" ]]; then
    echo "$config_backup" > "$moodle_dir/config.php"
    info "config.php restored"
  fi
  
  # Run database upgrade with timeout
  info "Upgrading Moodle database (this may take several minutes)"
  run_with_timeout 1800 $php_runner php "$moodle_dir/admin/cli/upgrade.php" --non-interactive &
  local upgrade_pid=$!
  spinner $upgrade_pid "Upgrading database schema..."
  wait $upgrade_pid
  local upgrade_status=$?
  if [[ $upgrade_status -eq 124 ]]; then
    error "Database upgrade timed out after 30 minutes"
    [[ -n "${LOG_FILE:-}" ]] && error "Check $LOG_FILE for details"
    # Disable maintenance mode on failure
    $php_runner php "$moodle_dir/admin/cli/maintenance.php" --disable 2>/dev/null || true
    # Rollback
    if [[ -n "$rollback_branch" ]]; then
      warn "Rolling back to previous version..."
      git -C "$moodle_dir" checkout "$rollback_branch" 2>/dev/null || true
      if [[ -n "$config_backup" ]]; then
        echo "$config_backup" > "$moodle_dir/config.php"
      fi
    fi
    return 1
  elif [[ $upgrade_status -ne 0 ]]; then
    error "Database upgrade failed"
    [[ -n "${LOG_FILE:-}" ]] && error "Check $LOG_FILE for details"
    # Disable maintenance mode on failure
    $php_runner php "$moodle_dir/admin/cli/maintenance.php" --disable 2>/dev/null || true
    # Rollback
    if [[ -n "$rollback_branch" ]]; then
      warn "Rolling back to previous version..."
      git -C "$moodle_dir" checkout "$rollback_branch" 2>/dev/null || true
      if [[ -n "$config_backup" ]]; then
        echo "$config_backup" > "$moodle_dir/config.php"
      fi
    fi
    return 1
  fi
  
  # Purge caches
  info "Purging caches"
  $php_runner php "$moodle_dir/admin/cli/purge_caches.php" &>/dev/null || true
  
  # Disable maintenance mode
  info "Disabling maintenance mode"
  $php_runner php "$moodle_dir/admin/cli/maintenance.php" --disable 2>/dev/null || true
  
  success "Moodle upgraded to $target_version"
}

# ── Upgrade Verification ──────────────────────────────────────

verify_upgrade() {
  local moodle_dir="$1"
  local expected_version="$2"
  
  local actual_version
  actual_version=$(detect_installed_version "$moodle_dir")
  
  if [[ "$actual_version" == "$expected_version" ]]; then
    success "Upgrade verified: Moodle $actual_version is running"
    return 0
  else
    error "Upgrade verification failed"
    error "Expected: $expected_version, Found: $actual_version"
    return 1
  fi
}
