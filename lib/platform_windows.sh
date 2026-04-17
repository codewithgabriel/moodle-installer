#!/usr/bin/env bash
# lib/platform_windows.sh — Windows-specific implementations using Chocolatey and PowerShell

# Package name mapping: Linux package name → Windows Chocolatey package
declare -A WINDOWS_PACKAGE_MAP=(
  ["apache2"]="apache-httpd"
  ["mariadb-server"]="mariadb"
  ["mariadb-client"]="mariadb"
  ["redis-server"]="redis-64"
  ["php8.3"]="php --version=8.3"
  ["php8.3-cli"]="php --version=8.3"
  ["php8.3-fpm"]="php --version=8.3"
  ["php8.3-mysql"]="php --version=8.3"
  ["php8.3-xml"]="php --version=8.3"
  ["php8.3-mbstring"]="php --version=8.3"
  ["php8.3-curl"]="php --version=8.3"
  ["php8.3-zip"]="php --version=8.3"
  ["php8.3-gd"]="php --version=8.3"
  ["php8.3-intl"]="php --version=8.3"
  ["php8.3-soap"]="php --version=8.3"
  ["php8.3-redis"]="php --version=8.3"
  ["php8.3-opcache"]="php --version=8.3"
  ["php8.3-sodium"]="php --version=8.3"
  ["libapache2-mod-php8.3"]="php --version=8.3"
  ["php8.1"]="php --version=8.1"
  ["php8.1-cli"]="php --version=8.1"
  ["git"]="git"
  ["curl"]="curl"
  ["wget"]="wget"
  ["unzip"]="unzip"
  ["cron"]=""
  ["software-properties-common"]=""
  ["certbot"]="certbot"
  ["python3-certbot-apache"]="certbot"
  ["openssl"]="openssl"
)

# Windows service name mapping
declare -A WINDOWS_SERVICE_MAP=(
  ["apache2"]="Apache2.4"
  ["mariadb"]="MySQL"
  ["redis-server"]="Redis"
  ["php8.3-fpm"]=""
  ["nginx"]="nginx"
)

# ── Package Management ────────────────────────────────────────

windows_check_chocolatey() {
  if ! command -v choco &>/dev/null; then
    error "Chocolatey package manager is not installed"
    error ""
    error "Chocolatey is required for automated package installation on Windows."
    error ""
    error "Installation options:"
    error "  1. Automated (requires admin PowerShell):"
    error "     Run in PowerShell as Administrator:"
    error "     Set-ExecutionPolicy Bypass -Scope Process -Force;"
    error "     [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072;"
    error "     iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
    error ""
    error "  2. Manual: Visit https://chocolatey.org/install"
    error ""
    return 1
  fi
  return 0
}

windows_install_package() {
  local package="$1"
  
  # Check if Chocolatey is installed
  windows_check_chocolatey || return 1
  
  # Get Windows package name from mapping
  local windows_package="${WINDOWS_PACKAGE_MAP[$package]}"
  
  # If no mapping exists, use the package name as-is
  if [[ -z "$windows_package" ]]; then
    # Skip packages that don't have Windows equivalents
    if [[ "$package" == "cron" || "$package" == "software-properties-common" ]]; then
      info "Skipping $package (not needed on Windows)"
      return 0
    fi
    windows_package="$package"
  fi
  
  # Skip if already handled by another package (PHP extensions)
  if [[ "$package" =~ ^php[0-9.]+- ]]; then
    info "PHP extension $package will be configured with PHP installation"
    return 0
  fi
  
  # Install via Chocolatey
  info "Installing $package via Chocolatey"
  if [[ -n "${LOG_FILE:-}" ]]; then
    choco install $windows_package -y --no-progress 2>&1 | tee -a "$LOG_FILE" || {
      error "Failed to install $package on Windows"
      error "Package: $windows_package"
      error "Try manually: choco install $windows_package"
      return 1
    }
  else
    choco install $windows_package -y --no-progress || {
      error "Failed to install $package on Windows"
      error "Package: $windows_package"
      error "Try manually: choco install $windows_package"
      return 1
    }
  fi
  
  return 0
}

windows_update_packages() {
  windows_check_chocolatey || return 1
  choco upgrade all -y --no-progress
}

windows_package_exists() {
  local package="$1"
  local windows_package="${WINDOWS_PACKAGE_MAP[$package]:-$package}"
  
  # Extract package name without version
  windows_package="${windows_package%% *}"
  
  choco list --local-only | grep -qi "^$windows_package "
}

# ── Service Management ────────────────────────────────────────

windows_get_service_name() {
  local service="$1"
  echo "${WINDOWS_SERVICE_MAP[$service]:-$service}"
}

windows_start_service() {
  local service="$1"
  local windows_service
  windows_service=$(windows_get_service_name "$service")
  
  if [[ -z "$windows_service" ]]; then
    info "Service $service does not require management on Windows"
    return 0
  fi
  
  powershell.exe -Command "Start-Service -Name '$windows_service' -ErrorAction SilentlyContinue" 2>/dev/null || {
    warn "Could not start service: $windows_service"
    return 1
  }
}

windows_stop_service() {
  local service="$1"
  local windows_service
  windows_service=$(windows_get_service_name "$service")
  
  if [[ -z "$windows_service" ]]; then
    return 0
  fi
  
  powershell.exe -Command "Stop-Service -Name '$windows_service' -ErrorAction SilentlyContinue" 2>/dev/null
}

windows_enable_service() {
  local service="$1"
  local windows_service
  windows_service=$(windows_get_service_name "$service")
  
  if [[ -z "$windows_service" ]]; then
    return 0
  fi
  
  powershell.exe -Command "Set-Service -Name '$windows_service' -StartupType Automatic -ErrorAction SilentlyContinue" 2>/dev/null || {
    warn "Could not set service $windows_service to automatic startup"
    return 1
  }
}

windows_restart_service() {
  local service="$1"
  local windows_service
  windows_service=$(windows_get_service_name "$service")
  
  if [[ -z "$windows_service" ]]; then
    return 0
  fi
  
  powershell.exe -Command "Restart-Service -Name '$windows_service' -ErrorAction SilentlyContinue" 2>/dev/null
}

windows_reload_service() {
  local service="$1"
  # Windows services don't have a reload concept, restart instead
  windows_restart_service "$service"
}

windows_service_status() {
  local service="$1"
  local windows_service
  windows_service=$(windows_get_service_name "$service")
  
  if [[ -z "$windows_service" ]]; then
    return 0
  fi
  
  local status
  status=$(powershell.exe -Command "(Get-Service -Name '$windows_service' -ErrorAction SilentlyContinue).Status" 2>/dev/null | tr -d '\r')
  
  [[ "$status" == "Running" ]]
}

# ── File System Operations ────────────────────────────────────

windows_set_permissions() {
  local path="$1"
  local owner="$2"
  local mode="$3"
  
  # Convert Unix path to Windows path
  local windows_path
  if command -v cygpath &>/dev/null; then
    windows_path=$(cygpath -w "$path" 2>/dev/null || echo "$path")
  else
    # Fallback: simple conversion if cygpath not available
    windows_path=$(echo "$path" | sed 's|^/c/|C:\\|; s|/|\\|g')
  fi
  
  # Convert Unix permissions to Windows ACL rights
  local acl_rights
  case "$mode" in
    755) acl_rights="Read,Execute" ;;
    770) acl_rights="Modify" ;;
    640) acl_rights="Read" ;;
    600) acl_rights="Read" ;;
    *) acl_rights="Read,Execute" ;;
  esac
  
  # Escape special characters for PowerShell
  local escaped_path="${windows_path//\\/\\\\}"
  local escaped_owner="${owner//\\/\\\\}"
  
  # Set permissions using PowerShell
  powershell.exe -Command "
    try {
      \$acl = Get-Acl '$escaped_path'
      \$rule = New-Object System.Security.AccessControl.FileSystemAccessRule('$escaped_owner', '$acl_rights', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
      \$acl.SetAccessRule(\$rule)
      Set-Acl '$escaped_path' \$acl
    } catch {
      Write-Host 'Warning: Could not set permissions on $escaped_path'
    }
  " 2>/dev/null || {
    warn "Could not set permissions on $path"
  }
}

windows_create_directory() {
  local path="$1"
  mkdir -p "$path" 2>/dev/null || {
    # Try with PowerShell if mkdir fails
    local windows_path
    windows_path=$(cygpath -w "$path" 2>/dev/null || echo "$path")
    powershell.exe -Command "New-Item -ItemType Directory -Force -Path '$windows_path'" 2>/dev/null
  }
}
