#!/usr/bin/env bash
# lib/checks.sh — pre-flight system checks

check_os() {
  if [[ ! -f /etc/os-release ]]; then
    error "Cannot detect OS. Only Debian/Ubuntu Linux is supported."
    exit 1
  fi
  source /etc/os-release
  if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
    warn "Detected OS: $PRETTY_NAME"
    warn "This installer is optimised for Ubuntu/Debian. Proceed with caution."
    confirm "Continue anyway?" || exit 0
  else
    success "OS detected: $PRETTY_NAME"
  fi
}

check_php_version() {
  if check_cmd php; then
    local ver
    ver=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
    local major minor
    major=$(echo "$ver" | cut -d. -f1)
    minor=$(echo "$ver" | cut -d. -f2)
    if (( major > 8 || (major == 8 && minor >= 1) )); then
      success "PHP $ver detected — compatible with Moodle 4.5"
      return 0
    else
      warn "PHP $ver is below the required 8.1. Will upgrade."
      return 1
    fi
  else
    info "PHP not found. Will install."
    return 1
  fi
}

check_mariadb() {
  if check_cmd mysql; then
    local ver
    ver=$(mysql --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
    success "MariaDB/MySQL $ver detected"
    return 0
  else
    info "MariaDB not found. Will install."
    return 1
  fi
}

check_webserver() {
  if check_cmd apache2; then
    success "Apache2 detected" >&2
    echo "apache2"
  elif check_cmd nginx; then
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
  if ! curl -s --max-time 5 --head https://github.com &>/dev/null; then
    error "No internet connectivity. Please check your network and try again."
    exit 1
  fi
  success "Internet connectivity OK"
}

run_preflight() {
  write_section "Pre-flight Checks"
  check_os
  check_disk_space
  check_ram
  check_internet
  success "All pre-flight checks passed"
}
