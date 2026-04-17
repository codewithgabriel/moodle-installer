#!/usr/bin/env bash
# lib/platform.sh — Platform detection and environment identification

# Global variables set by detect_platform:
# - PLATFORM: "linux" | "windows"
# - PLATFORM_VARIANT: "native" | "wsl" | "ubuntu" | "debian" | etc.
# - PLATFORM_ARCH: "x86_64" | "aarch64" | etc.

detect_platform() {
  local kernel
  kernel=$(uname -s 2>/dev/null || echo "unknown")
  
  case "$kernel" in
    Linux)
      # Check if running under WSL
      if grep -qi microsoft /proc/version 2>/dev/null || grep -qi wsl /proc/version 2>/dev/null; then
        PLATFORM="linux"
        PLATFORM_VARIANT="wsl"
      else
        PLATFORM="linux"
        # Detect Linux distribution from /etc/os-release
        if [[ -f /etc/os-release ]]; then
          source /etc/os-release
          PLATFORM_VARIANT="${ID:-unknown}"
        else
          PLATFORM_VARIANT="unknown"
        fi
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*)
      # Git Bash, MSYS2, or Cygwin on Windows
      PLATFORM="windows"
      PLATFORM_VARIANT="native"
      ;;
    *)
      error "Unsupported platform: $kernel"
      error ""
      error "MoodleDeploy supports:"
      error "  - Linux (Ubuntu, Debian, and other distributions)"
      error "  - Windows 10/11 (via Git Bash, MSYS2, or PowerShell)"
      error "  - Windows Subsystem for Linux (WSL)"
      error ""
      error "Your system: $kernel"
      return 1
      ;;
  esac
  
  # Detect architecture
  PLATFORM_ARCH=$(uname -m 2>/dev/null || echo "unknown")
  
  # Export variables for use by other scripts
  export PLATFORM PLATFORM_VARIANT PLATFORM_ARCH
  
  return 0
}
