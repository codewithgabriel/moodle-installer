#!/usr/bin/env bash
# lib/platform_linux.sh — Linux-specific implementations

# ── Package Management ────────────────────────────────────────

linux_install_package() {
  local package="$1"
  apt_install "$package"
}

linux_update_packages() {
  apt-get update
}

linux_package_exists() {
  local package="$1"
  dpkg -l "$package" 2>/dev/null | grep -q "^ii"
}

# ── Service Management ────────────────────────────────────────

linux_start_service() {
  local service="$1"
  svc_start "$service"
}

linux_stop_service() {
  local service="$1"
  svc_stop "$service"
}

linux_enable_service() {
  local service="$1"
  svc_enable "$service"
}

linux_restart_service() {
  local service="$1"
  svc_restart "$service"
}

linux_reload_service() {
  local service="$1"
  svc_reload "$service"
}

linux_service_status() {
  local service="$1"
  systemctl is-active "$service" &>/dev/null
}

# ── File System Operations ────────────────────────────────────

linux_set_permissions() {
  local path="$1"
  local owner="$2"
  local mode="$3"
  
  if [[ -n "$owner" ]]; then
    chown -R "$owner" "$path" 2>/dev/null || true
  fi
  
  if [[ -n "$mode" ]]; then
    chmod -R "$mode" "$path" 2>/dev/null || true
  fi
}

linux_create_directory() {
  local path="$1"
  mkdir -p "$path"
}

# ── Service Management Helpers (use existing from checks.sh) ───────────
# Note: svc_* functions are defined in lib/checks.sh and handle systemctl availability
