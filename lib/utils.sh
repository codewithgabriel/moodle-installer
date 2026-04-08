#!/usr/bin/env bash
# lib/utils.sh — shared helper functions

info()    { echo -e "\n${CYAN}  ℹ  $*${RESET}" >&2; [[ -n "${LOG_FILE:-}" && -f "$LOG_FILE" ]] && echo "$(date '+%Y-%m-%d %H:%M:%S') INFO: $*" >> "$LOG_FILE"; }
success() { echo -e "\n${BOLD_GREEN}  ✔  $*${RESET}" >&2; [[ -n "${LOG_FILE:-}" && -f "$LOG_FILE" ]] && echo "$(date '+%Y-%m-%d %H:%M:%S') SUCCESS: $*" >> "$LOG_FILE"; }
warn()    { echo -e "\n${BOLD_YELLOW}  ⚠  $*${RESET}" >&2; [[ -n "${LOG_FILE:-}" && -f "$LOG_FILE" ]] && echo "$(date '+%Y-%m-%d %H:%M:%S') WARN: $*" >> "$LOG_FILE"; }
error()   { echo -e "\n${BOLD_RED}  ✖  $*${RESET}" >&2; [[ -n "${LOG_FILE:-}" && -f "$LOG_FILE" ]] && echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR: $*" >> "$LOG_FILE"; }
step()    { echo -e "\n${BOLD}  ──  $*${RESET}"; }
divider() { echo -e "\n${DIM}  ────────────────────────────────────────${RESET}"; }

confirm() {
  local msg="${1:-Are you sure?}"
  local ans
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
    local val
    read -rp "$(echo -e "  ${BOLD_CYAN}→  $msg$hint: ${RESET}")" val
    val="${val:-$default}"
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
  local val
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
  if ! wait "$pid"; then
    error "Command failed: $*"
    echo -e "\n${BOLD_RED}  Error output:${RESET}" >&2
    cat "$tmp_err" >&2
    rm -f "$tmp_err"
    exit 1
  fi
  rm -f "$tmp_err"
}

pause() {
  echo ""
  read -rp "$(echo -e "  ${DIM}Press Enter to continue...${RESET}")"
}

generate_password() {
  tr -dc 'A-Za-z0-9@#%^&*' </dev/urandom | head -c 20
}

check_cmd() {
  command -v "$1" &>/dev/null
}

apt_install() {
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    "$@" &>/dev/null
}

write_section() {
  local title="$1"
  divider
  echo -e "  ${BOLD_CYAN}$title${RESET}"
  divider
}

# ── Resolve PHP binary ────────────────────────────────────────
# After detect_php runs, PHP_BIN is set. Use this for all php calls.
php_bin() {
  echo "${PHP_BIN:-php}"
}

# ── Moodle version picker ─────────────────────────────────────
pick_moodle_version() {
  local varname="$1"
  echo ""
  echo -e "  ${BOLD}Select Moodle version:${RESET}"
  echo ""
  echo -e "  ${GREEN}[1]${RESET} Moodle 4.5  ${DIM}(MOODLE_405_STABLE — LTS, recommended)${RESET}"
  echo -e "  ${GREEN}[2]${RESET} Moodle 4.4  ${DIM}(MOODLE_404_STABLE)${RESET}"
  echo -e "  ${GREEN}[3]${RESET} Moodle 4.3  ${DIM}(MOODLE_403_STABLE)${RESET}"
  echo -e "  ${GREEN}[4]${RESET} Moodle 4.2  ${DIM}(MOODLE_402_STABLE)${RESET}"
  echo -e "  ${GREEN}[5]${RESET} Moodle 4.1  ${DIM}(MOODLE_401_STABLE — LTS)${RESET}"
  echo -e "  ${YELLOW}[6]${RESET} Moodle main ${DIM}(bleeding edge — NOT for production)${RESET}"
  echo ""
  while true; do
    local _ver_choice
    read -rp "$(echo -e "  ${BOLD_CYAN}→  Version [1-6]: ${RESET}")" _ver_choice
    case "$_ver_choice" in
      1) printf -v "$varname" '%s' "MOODLE_405_STABLE"; break ;;
      2) printf -v "$varname" '%s' "MOODLE_404_STABLE"; break ;;
      3) printf -v "$varname" '%s' "MOODLE_403_STABLE"; break ;;
      4) printf -v "$varname" '%s' "MOODLE_402_STABLE"; break ;;
      5) printf -v "$varname" '%s' "MOODLE_401_STABLE"; break ;;
      6)
        warn "The 'main' branch is unstable and not suitable for production."
        confirm "Are you sure you want to use main?" && { printf -v "$varname" '%s' "main"; break; }
        ;;
      *) warn "Please enter a number between 1 and 6." ;;
    esac
  done
  success "Selected: ${!varname}"
}

# ── Moodle directory handler ──────────────────────────────────
# Sets MOODLE_INSTALL_MODE = "fresh" | "upgrade" | "clone_into"
handle_moodle_dir() {
  local dir="$1"
  local branch="$2"

  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
    MOODLE_INSTALL_MODE="fresh"
    return 0
  fi

  if [[ -f "$dir/version.php" ]]; then
    local current_branch=""
    if [[ -d "$dir/.git" ]]; then
      current_branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    fi
    warn "Existing Moodle installation detected in $dir"
    [[ -n "$current_branch" ]] && info "Current branch: $current_branch"
    info "Target branch:  $branch"
    echo ""
    echo -e "  ${BOLD}What would you like to do?${RESET}"
    echo -e "  ${GREEN}[1]${RESET} Upgrade to $branch ${DIM}(keeps config.php, moodledata, database)${RESET}"
    echo -e "  ${YELLOW}[2]${RESET} Reinstall ${DIM}(wipe Moodle files only — database untouched)${RESET}"
    echo -e "  ${RED}[3]${RESET} Cancel"
    echo ""
    while true; do
      local _dir_choice
      read -rp "$(echo -e "  ${BOLD_CYAN}→  Choice [1/2/3]: ${RESET}")" _dir_choice
      case "$_dir_choice" in
        1) MOODLE_INSTALL_MODE="upgrade"; return 0 ;;
        2)
          warn "This will DELETE all Moodle files in $dir (database and moodledata are untouched)."
          if confirm "Are you absolutely sure?"; then
            rm -rf "$dir"
            mkdir -p "$dir"
            MOODLE_INSTALL_MODE="fresh"
            return 0
          fi
          ;;
        3) main_menu; return 1 ;;
        *) warn "Please enter 1, 2, or 3." ;;
      esac
    done
  else
    local file_count
    file_count=$(find "$dir" -maxdepth 1 -mindepth 1 | wc -l)
    if (( file_count > 0 )); then
      warn "Directory $dir exists with $file_count item(s) but no Moodle found."
      echo -e "  ${GREEN}[1]${RESET} Clone Moodle into this directory ${DIM}(existing files kept)${RESET}"
      echo -e "  ${YELLOW}[2]${RESET} Wipe directory and do a clean clone"
      echo -e "  ${RED}[3]${RESET} Cancel"
      echo ""
      while true; do
        local _dir_choice
        read -rp "$(echo -e "  ${BOLD_CYAN}→  Choice [1/2/3]: ${RESET}")" _dir_choice
        case "$_dir_choice" in
          1) MOODLE_INSTALL_MODE="clone_into"; return 0 ;;
          2)
            if confirm "Wipe $dir and all its contents?"; then
              rm -rf "$dir"
              mkdir -p "$dir"
              MOODLE_INSTALL_MODE="fresh"
              return 0
            fi
            ;;
          3) main_menu; return 1 ;;
          *) warn "Please enter 1, 2, or 3." ;;
        esac
      done
    else
      MOODLE_INSTALL_MODE="fresh"
      return 0
    fi
  fi
}

# ── Clone or upgrade Moodle ───────────────────────────────────
fetch_moodle() {
  local dir="$1"
  local branch="$2"
  local mode="$3"

  if [[ "$mode" == "upgrade" ]]; then
    write_section "Upgrading Moodle to $branch"

    # Backup config.php before anything
    if [[ -f "$dir/config.php" ]]; then
      cp "$dir/config.php" "$dir/config.php.bak.$(date +%Y%m%d_%H%M%S)"
      info "config.php backed up"
    fi

    if [[ ! -d "$dir/.git" ]]; then
      warn "Existing install is not a git repo. Initialising git..."
      git -C "$dir" init &>/dev/null
      git -C "$dir" remote add origin https://github.com/moodle/moodle.git &>/dev/null
    fi

    git -C "$dir" fetch --depth=1 origin "$branch" &>/dev/null &
    local fetch_pid=$!
    spinner $fetch_pid "Fetching $branch..."
    wait $fetch_pid || { error "git fetch failed. Check your internet connection."; exit 1; }

    # Preserve config.php across checkout
    local config_backup=""
    if [[ -f "$dir/config.php" ]]; then
      config_backup=$(cat "$dir/config.php")
    fi

    git -C "$dir" checkout -B "$branch" "origin/$branch" &>/dev/null &
    local checkout_pid=$!
    spinner $checkout_pid "Switching to $branch..."
    wait $checkout_pid || { error "git checkout failed."; exit 1; }

    # Restore config.php if git wiped it
    if [[ -n "$config_backup" && ! -f "$dir/config.php" ]]; then
      echo "$config_backup" > "$dir/config.php"
      info "config.php restored after checkout"
    fi

    success "Moodle code updated to $branch"

  elif [[ "$mode" == "clone_into" ]]; then
    write_section "Cloning Moodle $branch into existing directory"
    local tmp_dir
    tmp_dir=$(mktemp -d)
    git clone --depth=1 --branch "$branch" \
      https://github.com/moodle/moodle.git "$tmp_dir" &>/dev/null &
    local clone_pid=$!
    spinner $clone_pid "Cloning Moodle $branch..."
    wait $clone_pid || { error "git clone failed."; rm -rf "$tmp_dir"; exit 1; }
    cp -a "$tmp_dir/." "$dir/"
    rm -rf "$tmp_dir"
    success "Moodle $branch cloned into $dir"

  else
    write_section "Downloading Moodle $branch"
    git clone --depth=1 --branch "$branch" \
      https://github.com/moodle/moodle.git "$dir" &>/dev/null &
    local clone_pid=$!
    spinner $clone_pid "Cloning Moodle $branch..."
    wait $clone_pid || { error "git clone failed."; exit 1; }
    success "Moodle $branch downloaded to $dir"
  fi
}

# ── Cron dedup helper ─────────────────────────────────────────
# Adds a cron entry only if it doesn't already exist
add_cron_job() {
  local user="$1"
  local entry="$2"
  local existing
  existing=$(crontab -u "$user" -l 2>/dev/null || true)
  if echo "$existing" | grep -qF "$entry"; then
    info "Cron job already exists — skipping duplicate"
  else
    (echo "$existing"; echo "$entry") | crontab -u "$user" -
    success "Cron job added"
  fi
}
