#!/usr/bin/env bash
# ============================================================
#  MoodleDeploy — Interactive Moodle Installer + CI/CD
#  Supports: Moodle 4.1-5.1 | Linux & Windows | Fresh/Upgrade
# ============================================================

set -euo pipefail

# Check Bash version (require 4.0+ for associative arrays)
if ((BASH_VERSINFO[0] < 4)); then
  echo "ERROR: This script requires Bash 4.0 or higher" >&2
  echo "Your version: $BASH_VERSION" >&2
  echo "Please upgrade Bash and try again" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
LOG_FILE="$SCRIPT_DIR/moodle-install.log"

# DEPENDENCY ORDER: colors → platform → platform_abstraction → version_config → upgrade_manager → utils → checks
source "$LIB_DIR/colors.sh"
# Validate colors.sh loaded
if [[ -z "${RED:-}" ]] || [[ -z "${GREEN:-}" ]] || [[ -z "${RESET:-}" ]]; then
  echo "ERROR: colors.sh failed to load required color variables" >&2
  exit 1
fi

# Load platform detection
source "$LIB_DIR/platform.sh"

# Detect platform early
if ! detect_platform; then
  echo "ERROR: Platform detection failed" >&2
  exit 1
fi

# Verify PLATFORM variable is set
if [[ -z "${PLATFORM:-}" ]]; then
  echo "ERROR: PLATFORM variable not set after detection" >&2
  exit 1
fi

# Load platform abstraction layer
source "$LIB_DIR/platform_abstraction.sh"

# Load platform-specific implementation
case "$PLATFORM" in
  linux)   
    source "$LIB_DIR/platform_linux.sh"
    ;;
  windows) 
    source "$LIB_DIR/platform_windows.sh"
    ;;
  *)
    echo "ERROR: Unsupported platform: $PLATFORM" >&2
    exit 1
    ;;
esac

# Load version configuration manager
source "$LIB_DIR/version_config.sh"

# Load upgrade manager
source "$LIB_DIR/upgrade_manager.sh"

# Load utilities
source "$LIB_DIR/utils.sh"
# Validate utils.sh loaded
if ! declare -f prompt >/dev/null || ! declare -f run_cmd >/dev/null; then
  echo "ERROR: utils.sh failed to load required functions (prompt, run_cmd)" >&2
  exit 1
fi

# Load checks
source "$LIB_DIR/checks.sh"
# Validate checks.sh loaded
if ! declare -f run_preflight >/dev/null || ! declare -f check_webserver >/dev/null; then
  echo "ERROR: checks.sh failed to load required functions (run_preflight, check_webserver)" >&2
  exit 1
fi

# Validate mysql_root function exists (needed by upgrade_manager)
if ! declare -f mysql_root >/dev/null; then
  echo "ERROR: mysql_root function not found in checks.sh" >&2
  exit 1
fi

# ── Logging ──────────────────────────────────────────────────
# Simple logging - create log file but don't redirect everything
touch "$LOG_FILE"
log_msg() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG_FILE"
}

# ── Banner ───────────────────────────────────────────────────
print_banner() {
  clear
  echo -e "${CYAN}"
  cat << 'EOF'
  ╔╦╗╔═╗╔═╗╔╦╗╦  ╔═╗  ╔╦╗╔═╗╔═╗╦  ╔═╗╦ ╦
  ║║║║ ║║ ║ ║║║  ║╣    ║║║╣ ╠═╝║  ║ ║╚╦╝
  ╩ ╩╚═╝╚═╝═╩╝╩═╝╚═╝  ═╩╝╚═╝╩  ╩═╝╚═╝ ╩
       Moodle 4.1-5.1 — Cross-Platform Installer
EOF
  echo -e "${RESET}"
  echo -e "${DIM}  Platform: $PLATFORM ($PLATFORM_VARIANT) | Arch: $PLATFORM_ARCH${RESET}"
  echo -e "${DIM}  Logs → $LOG_FILE${RESET}"
  echo ""
}

# ── Main menu ────────────────────────────────────────────────
main_menu() {
  while true; do
    print_banner
    echo -e "${BOLD}  Choose your installation scenario:${RESET}"
    echo ""
    echo -e "  ${GREEN}[A]${RESET} Fresh Linux server  ${DIM}(brand new VPS / bare metal)${RESET}"
    echo -e "  ${YELLOW}[B]${RESET} Existing Linux server  ${DIM}(Apache/Nginx already installed)${RESET}"
    echo -e "  ${MAGENTA}[C]${RESET} cPanel / Shared hosting  ${DIM}(no root, web-based panel)${RESET}"
    echo -e "  ${CYAN}[D]${RESET} CI/CD setup only  ${DIM}(GitHub Actions + deploy pipeline)${RESET}"
    echo -e "  ${RED}[Q]${RESET} Quit"
    echo ""
    read -rp "  Your choice [A/B/C/D/Q]: " CHOICE

    case "${CHOICE^^}" in
      A) source "$SCRIPT_DIR/scripts/case_a_fresh.sh" && run_fresh_install; break ;;
      B) source "$SCRIPT_DIR/scripts/case_b_existing.sh" && run_existing_install; break ;;
      C) source "$SCRIPT_DIR/scripts/case_c_cpanel.sh" && run_cpanel_guide; break ;;
      D) source "$SCRIPT_DIR/scripts/cicd_setup.sh" && run_cicd_setup; break ;;
      Q) echo -e "\n${DIM}  Goodbye.${RESET}\n"; exit 0 ;;
      *) warn "Invalid choice. Please try again."; sleep 1 ;;
    esac
  done
}

main_menu
