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

run_preflight() {
  write_section "Pre-flight Checks"
  check_os
  check_disk_space
  check_ram
  check_internet
  check_systemctl
  success "All pre-flight checks passed"
}
