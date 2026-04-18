#!/usr/bin/env bash
# lib/checks.sh — pre-flight system checks

check_os() {
  if [[ ! -f /etc/os-release ]]; then
    error "Cannot detect OS. Only Debian/Ubuntu Linux is supported."
    exit 1
  fi
  # shellcheck source=/dev/null
  source /etc/os-release
  if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
    warn "Detected OS: $PRETTY_NAME"
    warn "This installer is optimised for Ubuntu/Debian. Proceed with caution."
    confirm "Continue anyway?" || exit 0
  else
    success "OS detected: $PRETTY_NAME"
  fi
}

# Detect the actual installed PHP version and return the binary path + ini dir
detect_php() {
  # Try versioned binaries first (most reliable)
  local candidates=(php8.3 php8.2 php8.1 php8.0 php)
  for bin in "${candidates[@]}"; do
    if command -v "$bin" &>/dev/null; then
      local ver
      ver=$("$bin" -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null)
      local major minor
      major=$(echo "$ver" | cut -d. -f1)
      minor=$(echo "$ver" | cut -d. -f2)
      if (( major > 8 || (major == 8 && minor >= 1) )); then
        PHP_BIN="$bin"
        PHP_VER="$ver"
        PHP_MAJOR_MINOR="${major}.${minor}"
        return 0
      fi
    fi
  done
  PHP_BIN=""
  PHP_VER=""
  PHP_MAJOR_MINOR=""
  return 1
}

check_php_version() {
  set +e
  detect_php
  local result=$?
  set -e
  
  if [[ $result -eq 0 ]]; then
    success "PHP ${PHP_VER} detected (${PHP_BIN}) — compatible with Moodle"
    return 0
  else
    info "PHP 8.1+ not found. Will install."
    return 1
  fi
}

check_mariadb() {
  set +e
  check_cmd mysql
  local cmd_result=$?
  set -e
  
  if [[ $cmd_result -eq 0 ]]; then
    local ver
    ver=$(mysql --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
    success "MariaDB/MySQL ${ver} detected"
    return 0
  else
    info "MariaDB not found. Will install."
    return 1
  fi
}

check_webserver() {
  set +e
  check_cmd apache2
  local apache_result=$?
  check_cmd nginx
  local nginx_result=$?
  set -e
  
  if [[ $apache_result -eq 0 ]]; then
    success "Apache2 detected" >&2
    echo "apache2"
  elif [[ $nginx_result -eq 0 ]]; then
    success "Nginx detected" >&2
    echo "nginx"
  else
    info "No web server detected. Will install Apache2." >&2
    echo "none"
  fi
}

check_disk_space() {
  local required_mb=2048
  local available_mb
  available_mb=$(df -m / | awk 'NR==2 {print $4}')
  if (( available_mb < required_mb )); then
    error "Insufficient disk space. Need ${required_mb}MB, have ${available_mb}MB."
    exit 1
  else
    success "Disk space OK: ${available_mb}MB available"
  fi
}

check_moodle_disk_space() {
  local moodle_dir="${1:-/var/www/html/moodle}"
  local required_mb=1024
  local available_mb
  available_mb=$(df -m "$moodle_dir" 2>/dev/null | awk 'NR==2 {print $4}')
  if [[ -z "$available_mb" ]]; then
    # Directory doesn't exist yet, check parent
    local parent_dir
    parent_dir=$(dirname "$moodle_dir")
    available_mb=$(df -m "$parent_dir" 2>/dev/null | awk 'NR==2 {print $4}')
  fi
  if (( available_mb < required_mb )); then
    error "Insufficient disk space for Moodle installation. Need ${required_mb}MB, have ${available_mb}MB."
    return 1
  else
    success "Disk space OK for Moodle: ${available_mb}MB available"
    return 0
  fi
}

check_ram() {
  local required_mb=512
  local available_mb
  available_mb=$(free -m | awk '/^Mem:/ {print $2}')
  if (( available_mb < required_mb )); then
    warn "RAM is low (${available_mb}MB). Moodle recommends at least 512MB."
  else
    success "RAM OK: ${available_mb}MB"
  fi
}

check_internet() {
  if ! curl -s --max-time 10 --head https://github.com &>/dev/null; then
    error "No internet connectivity. Please check your network and try again."
    exit 1
  fi
  success "Internet connectivity OK"
}

check_systemctl() {
  # Detect if systemctl is functional (fails in containers/LXC without systemd)
  set +e
  systemctl status &>/dev/null
  local result=$?
  set -e
  
  if [[ $result -ne 0 ]]; then
    warn "systemctl is not available or not functional (container/LXC environment?)."
    warn "Service management commands may fail. You may need to start services manually."
    SYSTEMCTL_OK=false
  else
    SYSTEMCTL_OK=true
  fi
}

# Safe systemctl wrapper — falls back gracefully in containers
svc_enable()  { [[ "$SYSTEMCTL_OK" == "true" ]] && systemctl enable  "$1" &>/dev/null || true; }
svc_start()   { [[ "$SYSTEMCTL_OK" == "true" ]] && systemctl start   "$1" &>/dev/null || service "$1" start &>/dev/null || true; }
svc_restart() { [[ "$SYSTEMCTL_OK" == "true" ]] && systemctl restart "$1" &>/dev/null || service "$1" restart &>/dev/null || true; }
svc_reload()  { [[ "$SYSTEMCTL_OK" == "true" ]] && systemctl reload  "$1" &>/dev/null || service "$1" reload  &>/dev/null || true; }

# Secure MariaDB root access — handles auth_socket (Ubuntu default) and password auth
mysql_root() {
  # Try socket auth first (Ubuntu/Debian default for fresh installs)
  if mysql -u root --connect-expired-password -e "SELECT 1;" &>/dev/null 2>&1; then
    mysql -u root "$@"
  elif [[ -n "${MYSQL_ROOT_PASS:-}" ]]; then
    mysql -u root -p"${MYSQL_ROOT_PASS}" "$@"
  else
    # Prompt for root password
    read -rsp "$(echo -e "  ${BOLD_CYAN}→  MySQL root password (leave blank if none): ${RESET}")" MYSQL_ROOT_PASS
    echo ""
    if [[ -z "$MYSQL_ROOT_PASS" ]]; then
      mysql -u root "$@"
    else
      mysql -u root -p"${MYSQL_ROOT_PASS}" "$@"
    fi
  fi
}

# ── Database Version Detection and Compatibility ─────────────

# Detect installed database version (MySQL or MariaDB)
detect_database_version() {
  local version=""
  local db_type=""
  
  # Try mysql --version first (works when mysql client is installed)
  if command -v mysql &>/dev/null; then
    local version_output
    version_output=$(mysql --version 2>/dev/null || echo "")
    
    # Parse MariaDB version (format: "mysql  Ver 15.1 Distrib 10.11.6-MariaDB")
    if echo "$version_output" | grep -qi "mariadb"; then
      db_type="mariadb"
      version=$(echo "$version_output" | grep -oP '\d+\.\d+\.\d+' | head -1)
    # Parse MySQL version (format: "mysql  Ver 8.0.45 for Linux")
    elif echo "$version_output" | grep -qi "mysql"; then
      db_type="mysql"
      version=$(echo "$version_output" | grep -oP '\d+\.\d+\.\d+' | head -1)
    fi
  fi
  
  # If mysql --version didn't work, try querying the database directly
  if [[ -z "$version" ]] && command -v mysql &>/dev/null; then
    local db_version
    db_version=$(mysql_root -e "SELECT VERSION();" -sN 2>/dev/null || echo "")
    if [[ -n "$db_version" ]]; then
      if echo "$db_version" | grep -qi "mariadb"; then
        db_type="mariadb"
        version=$(echo "$db_version" | grep -oP '\d+\.\d+\.\d+' | head -1)
      else
        db_type="mysql"
        version=$(echo "$db_version" | grep -oP '\d+\.\d+\.\d+' | head -1)
      fi
    fi
  fi
  
  # Return format: "type:version" or empty if not detected
  if [[ -n "$version" && -n "$db_type" ]]; then
    echo "${db_type}:${version}"
    return 0
  else
    return 1
  fi
}

# Get database version available in repositories without installing
get_repository_database_version() {
  local package="${1:-mariadb-server}"
  local version=""
  
  # Try apt-cache policy first (shows candidate version)
  if command -v apt-cache &>/dev/null; then
    local policy_output
    policy_output=$(apt-cache policy "$package" 2>/dev/null || echo "")
    
    # Extract candidate version
    version=$(echo "$policy_output" | grep -oP 'Candidate: \K[\d\.\-]+' | grep -oP '^\d+\.\d+\.\d+' | head -1)
    
    # If policy didn't work, try madison
    if [[ -z "$version" ]]; then
      local madison_output
      madison_output=$(apt-cache madison "$package" 2>/dev/null | head -1 || echo "")
      version=$(echo "$madison_output" | awk '{print $3}' | grep -oP '^\d+\.\d+\.\d+' | head -1)
    fi
  fi
  
  if [[ -n "$version" ]]; then
    echo "$version"
    return 0
  else
    return 1
  fi
}

# Parse database requirements from MOODLE_DB_VERSIONS array
parse_db_requirements() {
  local branch="$1"
  local requirements
  
  # Get requirements string from version_config.sh
  requirements=$(get_database_requirements "$branch")
  
  if [[ -z "$requirements" ]]; then
    error "No database requirements found for branch: $branch"
    return 1
  fi
  
  # Parse format: "mariadb:10.11.0,mysql:8.4.0"
  local mariadb_min=""
  local mysql_min=""
  
  # Extract MariaDB minimum version
  if echo "$requirements" | grep -q "mariadb:"; then
    mariadb_min=$(echo "$requirements" | grep -oP 'mariadb:\K[\d\.]+')
  fi
  
  # Extract MySQL minimum version
  if echo "$requirements" | grep -q "mysql:"; then
    mysql_min=$(echo "$requirements" | grep -oP 'mysql:\K[\d\.]+')
  fi
  
  # Export as variables for caller to use
  echo "mariadb_min=$mariadb_min"
  echo "mysql_min=$mysql_min"
  return 0
}

# Check database compatibility for selected Moodle version
check_database_compatibility() {
  local branch="$1"
  local installed_db_version="${2:-}"  # Optional: provide if already detected
  
  # Get requirements for this Moodle version
  local requirements
  requirements=$(get_database_requirements "$branch")
  
  if [[ -z "$requirements" ]]; then
    error "Cannot determine database requirements for Moodle branch: $branch"
    return 1
  fi
  
  # Parse requirements
  local req_output
  req_output=$(parse_db_requirements "$branch")
  local mariadb_min
  local mysql_min
  mariadb_min=$(echo "$req_output" | grep "mariadb_min=" | cut -d= -f2)
  mysql_min=$(echo "$req_output" | grep "mysql_min=" | cut -d= -f2)
  
  # Detect installed database version if not provided
  local db_info=""
  if [[ -z "$installed_db_version" ]]; then
    db_info=$(detect_database_version 2>/dev/null || echo "")
  else
    db_info="$installed_db_version"
  fi
  
  # If database is installed, check compatibility
  if [[ -n "$db_info" ]]; then
    local db_type
    local db_version
    db_type=$(echo "$db_info" | cut -d: -f1)
    db_version=$(echo "$db_info" | cut -d: -f2)
    
    local required_version=""
    if [[ "$db_type" == "mariadb" ]]; then
      required_version="$mariadb_min"
    elif [[ "$db_type" == "mysql" ]]; then
      required_version="$mysql_min"
    else
      error "Unknown database type: $db_type"
      return 1
    fi
    
    # Compare versions
    if version_compare "$db_version" ">=" "$required_version"; then
      success "Database version compatible: $db_type $db_version >= $required_version"
      return 0
    else
      error "Database version incompatible!"
      error "  Installed: $db_type $db_version"
      error "  Required:  $db_type $required_version (minimum)"
      error ""
      error "Options:"
      error "  1. Upgrade your database to version $required_version or higher"
      error "  2. Select a different Moodle version compatible with $db_type $db_version"
      return 1
    fi
  else
    # No database installed - check if repository version is sufficient
    local repo_version
    repo_version=$(get_repository_database_version "mariadb-server" 2>/dev/null || echo "")
    
    if [[ -n "$repo_version" && -n "$mariadb_min" ]]; then
      if version_compare "$repo_version" ">=" "$mariadb_min"; then
        info "Repository MariaDB version $repo_version is compatible (>= $mariadb_min)"
        return 0
      else
        warn "Repository MariaDB version $repo_version is insufficient (need >= $mariadb_min)"
        info "Will need to add MariaDB official repository for compatible version"
        return 2  # Special return code: need repository management
      fi
    else
      # Cannot determine repository version - proceed with caution
      info "Cannot determine repository database version - will attempt installation"
      return 0
    fi
  fi
}

# ── Repository Management ─────────────────────────────────────

# Add MariaDB official repository for newer versions
add_mariadb_repository() {
  local required_version="${1:-10.11}"
  
  info "Adding MariaDB official repository for version $required_version..."
  
  # Detect OS distribution
  if [[ ! -f /etc/os-release ]]; then
    error "Cannot detect OS distribution"
    return 1
  fi
  
  # shellcheck source=/dev/null
  source /etc/os-release
  
  local os_id="$ID"
  local os_version_codename="${VERSION_CODENAME:-}"
  
  # Determine repository codename
  local repo_codename=""
  case "$os_id" in
    ubuntu)
      repo_codename="$os_version_codename"
      ;;
    debian)
      repo_codename="$os_version_codename"
      ;;
    *)
      error "Unsupported OS for MariaDB repository: $os_id"
      return 1
      ;;
  esac
  
  if [[ -z "$repo_codename" ]]; then
    error "Cannot determine OS version codename"
    return 1
  fi
  
  info "Detected OS: $os_id $repo_codename"
  
  # Install prerequisites
  if ! command -v curl &>/dev/null; then
    info "Installing curl..."
    apt_install curl || { error "Failed to install curl"; return 1; }
  fi
  
  if ! command -v gpg &>/dev/null; then
    info "Installing gnupg..."
    apt_install gnupg || { error "Failed to install gnupg"; return 1; }
  fi
  
  # Add MariaDB GPG key
  info "Adding MariaDB GPG key..."
  local keyring_path="/usr/share/keyrings/mariadb-keyring.gpg"
  
  if ! curl -fsSL https://mariadb.org/mariadb_release_signing_key.asc | gpg --dearmor -o "$keyring_path" 2>/dev/null; then
    error "Failed to add MariaDB GPG key"
    return 1
  fi
  
  # Determine MariaDB major.minor version for repository URL
  local mariadb_major_minor
  mariadb_major_minor=$(echo "$required_version" | grep -oP '^\d+\.\d+')
  
  # Create repository configuration
  local repo_file="/etc/apt/sources.list.d/mariadb.list"
  info "Creating repository configuration: $repo_file"
  
  cat > "$repo_file" <<EOF
# MariaDB $mariadb_major_minor repository
deb [signed-by=$keyring_path] https://mirror.mariadb.org/repo/$mariadb_major_minor/$os_id $repo_codename main
EOF
  
  if [[ ! -f "$repo_file" ]]; then
    error "Failed to create repository file"
    return 1
  fi
  
  # Update package lists
  info "Updating package lists..."
  if ! apt-get update 2>&1 | grep -v "^W:"; then
    warn "Package list update completed with warnings (this is usually safe to ignore)"
  fi
  
  # Verify repository was added successfully by checking if mariadb packages are available
  local repo_check
  repo_check=$(apt-cache policy mariadb-server 2>/dev/null | grep -c "mirror.mariadb.org" || echo "0")
  
  if [[ "$repo_check" -eq 0 ]]; then
    # Try alternative verification - check if the repo file exists and has content
    if [[ -f "$repo_file" ]] && grep -q "mirror.mariadb.org" "$repo_file"; then
      info "Repository file created successfully, proceeding with installation..."
    else
      error "MariaDB repository was not added successfully"
      return 1
    fi
  fi
  
  success "MariaDB official repository added successfully"
  return 0
}

# Install compatible database version for selected Moodle version
install_compatible_database() {
  local branch="$1"
  
  if [[ -z "$branch" ]]; then
    error "Moodle branch parameter required"
    return 1
  fi
  
  info "Determining required database version for $branch..."
  
  # Get requirements for this Moodle version
  local requirements
  requirements=$(get_database_requirements "$branch")
  
  if [[ -z "$requirements" ]]; then
    error "Cannot determine database requirements for branch: $branch"
    return 1
  fi
  
  # Parse requirements
  local req_output
  req_output=$(parse_db_requirements "$branch")
  local mariadb_min
  mariadb_min=$(echo "$req_output" | grep "mariadb_min=" | cut -d= -f2)
  
  if [[ -z "$mariadb_min" ]]; then
    error "Cannot parse MariaDB minimum version from requirements"
    return 1
  fi
  
  info "Required MariaDB version: $mariadb_min or higher"
  
  # Check if default repository provides compatible version
  local repo_version
  repo_version=$(get_repository_database_version "mariadb-server" 2>/dev/null || echo "")
  
  local need_official_repo=false
  if [[ -n "$repo_version" ]]; then
    info "Default repository provides MariaDB $repo_version"
    
    if version_compare "$repo_version" ">=" "$mariadb_min"; then
      info "Default repository version is sufficient"
    else
      warn "Default repository version $repo_version is insufficient (need >= $mariadb_min)"
      need_official_repo=true
    fi
  else
    warn "Cannot determine repository version - will attempt to add MariaDB official repository"
    need_official_repo=true
  fi
  
  # Add MariaDB official repository if needed
  if $need_official_repo; then
    info "Adding MariaDB official repository for version $mariadb_min..."
    if ! add_mariadb_repository "$mariadb_min"; then
      error "Failed to add MariaDB official repository"
      return 1
    fi
  fi
  
  # Determine package name to install
  local package_name="mariadb-server"
  
  # For specific versions from official repo, use versioned package if available
  if $need_official_repo; then
    local mariadb_major_minor
    mariadb_major_minor=$(echo "$mariadb_min" | grep -oP '^\d+\.\d+')
    
    # Check if versioned package exists
    if apt-cache show "mariadb-server-${mariadb_major_minor}" &>/dev/null; then
      package_name="mariadb-server-${mariadb_major_minor}"
      info "Using versioned package: $package_name"
    else
      info "Versioned package not available, using: $package_name"
    fi
  fi
  
  # Install MariaDB
  info "Installing $package_name..."
  if ! apt_install "$package_name"; then
    error "Failed to install $package_name"
    return 1
  fi
  
  success "MariaDB installed successfully"
  
  # Verify installed version meets requirements
  if ! verify_database_version "$branch"; then
    error "Installed database version does not meet requirements"
    return 1
  fi
  
  return 0
}

# Verify installed database version meets requirements
verify_database_version() {
  local branch="$1"
  
  if [[ -z "$branch" ]]; then
    error "Moodle branch parameter required"
    return 1
  fi
  
  info "Verifying database version for $branch..."
  
  # Get requirements
  local req_output
  req_output=$(parse_db_requirements "$branch")
  local mariadb_min
  local mysql_min
  mariadb_min=$(echo "$req_output" | grep "mariadb_min=" | cut -d= -f2)
  mysql_min=$(echo "$req_output" | grep "mysql_min=" | cut -d= -f2)
  
  # Detect installed database version
  local db_info
  db_info=$(detect_database_version 2>/dev/null || echo "")
  
  if [[ -z "$db_info" ]]; then
    error "Cannot detect installed database version"
    return 1
  fi
  
  local db_type
  local db_version
  db_type=$(echo "$db_info" | cut -d: -f1)
  db_version=$(echo "$db_info" | cut -d: -f2)
  
  info "Detected: $db_type $db_version"
  
  # Determine required version based on database type
  local required_version=""
  if [[ "$db_type" == "mariadb" ]]; then
    required_version="$mariadb_min"
  elif [[ "$db_type" == "mysql" ]]; then
    required_version="$mysql_min"
  else
    error "Unknown database type: $db_type"
    return 1
  fi
  
  # Compare versions
  if version_compare "$db_version" ">=" "$required_version"; then
    success "Database version verified: $db_type $db_version >= $required_version"
    return 0
  else
    error "Database version insufficient!"
    error "  Installed: $db_type $db_version"
    error "  Required:  $db_type $required_version (minimum)"
    return 1
  fi
}

run_preflight() {
  write_section "Pre-flight Checks"
  check_os
  check_disk_space
  check_ram
  check_internet
  check_systemctl
  success "All pre-flight checks passed"
}
