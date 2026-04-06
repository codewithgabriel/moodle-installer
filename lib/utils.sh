#!/usr/bin/env bash
# lib/utils.sh — shared helper functions

info()    { echo -e "\n${CYAN}  ℹ  $*${RESET}" >&2; }
success() { echo -e "\n${BOLD_GREEN}  ✔  $*${RESET}" >&2; }
warn()    { echo -e "\n${BOLD_YELLOW}  ⚠  $*${RESET}" >&2; }
error()   { echo -e "\n${BOLD_RED}  ✖  $*${RESET}" >&2; }
step()    { echo -e "\n${BOLD}  ──  $*${RESET}"; }
divider() { echo -e "\n${DIM}  ────────────────────────────────────────${RESET}"; }

confirm() {
  local msg="${1:-Are you sure?}"
  read -rp "$(echo -e "  ${YELLOW}?  $msg [y/N]: ${RESET}")" ans
  [[ "${ans,,}" == "y" ]]
}

prompt() {
  # prompt <varname> <message> [default]
  local varname="$1"
  local msg="$2"
  local default="${3:-}"
  local hint=""
  [[ -n "$default" ]] && hint=" ${DIM}[${default}]${RESET}"
  
  while true; do
    read -rp "$(echo -e "  ${BOLD_CYAN}→  $msg$hint: ${RESET}")" val
    val="${val:-$default}"
    
    # If no default and value is empty, require input
    if [[ -z "$default" && -z "$val" ]]; then
      warn "This field is required. Please enter a value."
      continue
    fi
    
    break
  done
  
  printf -v "$varname" '%s' "$val"
}

prompt_secret() {
  local varname="$1"
  local msg="$2"
  read -rsp "$(echo -e "  ${BOLD_CYAN}→  $msg: ${RESET}")" val
  echo ""
  printf -v "$varname" '%s' "$val"
}

require_root() {
  if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root or with sudo."
    exit 1
  fi
}

require_not_root() {
  if [[ $EUID -eq 0 ]]; then
    warn "Running as root is not recommended for this step."
  fi
}

spinner() {
  local pid=$1
  local msg="${2:-Working...}"
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${CYAN}${frames[$i]}${RESET}  $msg"
    i=$(( (i+1) % ${#frames[@]} ))
    sleep 0.1
  done
  printf "\r  ${BOLD_GREEN}✔${RESET}  $msg\n"
}

run_cmd() {
  local msg="$1"; shift
  local tmp_err
  tmp_err=$(mktemp)
  "$@" >"$tmp_err" 2>&1 &
  local pid=$!
  spinner "$pid" "$msg"
  wait "$pid" || {
    error "Command failed: $*"
    echo -e "\n${BOLD_RED}  Error output:${RESET}" >&2
    cat "$tmp_err" >&2
    rm -f "$tmp_err"
    exit 1
  }
  rm -f "$tmp_err"
}

pause() {
  echo ""
  read -rp "$(echo -e "  ${DIM}Press Enter to continue...${RESET}")"
}

generate_password() {
  tr -dc 'A-Za-z0-9!@#%^&*' </dev/urandom | head -c 20
}

check_cmd() {
  command -v "$1" &>/dev/null
}

apt_install() {
  DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" &>/dev/null
}

write_section() {
  local title="$1"
  divider
  echo -e "  ${BOLD_CYAN}$title${RESET}"
  divider
}
