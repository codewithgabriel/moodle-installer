#!/usr/bin/env bash
# ============================================================
#  MoodleDeploy — Interactive Moodle 4.5 Installer + CI/CD
#  Supports: Fresh Linux | Existing Linux | cPanel hosting
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
LOG_FILE="$SCRIPT_DIR/moodle-install.log"

source "$LIB_DIR/colors.sh"
source "$LIB_DIR/utils.sh"
source "$LIB_DIR/checks.sh"

# ── Logging ──────────────────────────────────────────────────
exec > >(tee -a "$LOG_FILE") 2>&1

# ── Banner ───────────────────────────────────────────────────
print_banner() {
  clear
  echo -e "${CYAN}"
  cat << 'EOF'
  ╔╦╗╔═╗╔═╗╔╦╗╦  ╔═╗  ╔╦╗╔═╗╔═╗╦  ╔═╗╦ ╦
  ║║║║ ║║ ║ ║║║  ║╣    ║║║╣ ╠═╝║  ║ ║╚╦╝
  ╩ ╩╚═╝╚═╝═╩╝╩═╝╚═╝  ═╩╝╚═╝╩  ╩═╝╚═╝ ╩
       Moodle 4.5 — Automated Installer & CI/CD
EOF
  echo -e "${RESET}"
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
