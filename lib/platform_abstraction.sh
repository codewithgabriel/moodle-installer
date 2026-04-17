#!/usr/bin/env bash
# lib/platform_abstraction.sh — Platform-agnostic interfaces for common operations

# ── Package Management ────────────────────────────────────────

platform_install_package() {
  local package="$1"
  case "$PLATFORM" in
    linux)   linux_install_package "$package" ;;
    windows) windows_install_package "$package" ;;
    *)       error "Unsupported platform: $PLATFORM"; return 1 ;;
  esac
}

platform_update_packages() {
  case "$PLATFORM" in
    linux)   linux_update_packages ;;
    windows) windows_update_packages ;;
    *)       error "Unsupported platform: $PLATFORM"; return 1 ;;
  esac
}

platform_package_exists() {
  local package="$1"
  case "$PLATFORM" in
    linux)   linux_package_exists "$package" ;;
    windows) windows_package_exists "$package" ;;
    *)       error "Unsupported platform: $PLATFORM"; return 1 ;;
  esac
}

# ── Service Management ────────────────────────────────────────

platform_start_service() {
  local service="$1"
  case "$PLATFORM" in
    linux)   linux_start_service "$service" ;;
    windows) windows_start_service "$service" ;;
    *)       error "Unsupported platform: $PLATFORM"; return 1 ;;
  esac
}

platform_stop_service() {
  local service="$1"
  case "$PLATFORM" in
    linux)   linux_stop_service "$service" ;;
    windows) windows_stop_service "$service" ;;
    *)       error "Unsupported platform: $PLATFORM"; return 1 ;;
  esac
}

platform_enable_service() {
  local service="$1"
  case "$PLATFORM" in
    linux)   linux_enable_service "$service" ;;
    windows) windows_enable_service "$service" ;;
    *)       error "Unsupported platform: $PLATFORM"; return 1 ;;
  esac
}

platform_restart_service() {
  local service="$1"
  case "$PLATFORM" in
    linux)   linux_restart_service "$service" ;;
    windows) windows_restart_service "$service" ;;
    *)       error "Unsupported platform: $PLATFORM"; return 1 ;;
  esac
}

platform_reload_service() {
  local service="$1"
  case "$PLATFORM" in
    linux)   linux_reload_service "$service" ;;
    windows) windows_reload_service "$service" ;;
    *)       error "Unsupported platform: $PLATFORM"; return 1 ;;
  esac
}

platform_service_status() {
  local service="$1"
  case "$PLATFORM" in
    linux)   linux_service_status "$service" ;;
    windows) windows_service_status "$service" ;;
    *)       error "Unsupported platform: $PLATFORM"; return 1 ;;
  esac
}

# ── File System Operations ────────────────────────────────────

platform_set_permissions() {
  local path="$1"
  local owner="$2"
  local mode="$3"
  case "$PLATFORM" in
    linux)   linux_set_permissions "$path" "$owner" "$mode" ;;
    windows) windows_set_permissions "$path" "$owner" "$mode" ;;
    *)       error "Unsupported platform: $PLATFORM"; return 1 ;;
  esac
}

platform_create_directory() {
  local path="$1"
  case "$PLATFORM" in
    linux)   linux_create_directory "$path" ;;
    windows) windows_create_directory "$path" ;;
    *)       error "Unsupported platform: $PLATFORM"; return 1 ;;
  esac
}

platform_path_separator() {
  case "$PLATFORM" in
    linux)   echo "/" ;;
    windows) echo "\\" ;;
    *)       echo "/" ;;
  esac
}

platform_normalize_path() {
  local path="$1"
  case "$PLATFORM" in
    linux)   echo "$path" ;;
    windows) 
      # Convert forward slashes to backslashes for Windows
      echo "$path" | sed 's|/|\\|g'
      ;;
    *)       echo "$path" ;;
  esac
}

# ── Platform Information ──────────────────────────────────────

platform_get_web_user() {
  case "$PLATFORM" in
    linux)   echo "www-data" ;;
    windows) echo "IIS_IUSRS" ;;
    *)       echo "www-data" ;;
  esac
}

platform_get_temp_dir() {
  case "$PLATFORM" in
    linux)   echo "/tmp" ;;
    windows) echo "$TEMP" ;;
    *)       echo "/tmp" ;;
  esac
}
