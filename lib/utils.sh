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

# ── Input validation functions ────────────────────────────────
validate_domain() {
  local domain="$1"
  # Domain must be non-empty and match hostname pattern
  if [[ -z "$domain" ]]; then
    warn "Domain cannot be empty"
    return 1
  fi
  # Basic hostname pattern: alphanumeric, hyphens, dots
  if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
    warn "Invalid domain. Must be a valid hostname (e.g., example.com or learn.example.com)"
    return 1
  fi
  return 0
}

validate_email() {
  local email="$1"
  # Email must contain @ and match basic email pattern
  if [[ -z "$email" ]]; then
    warn "Email cannot be empty"
    return 1
  fi
  if [[ ! "$email" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
    warn "Invalid email. Must contain @ and be in format user@domain.com"
    return 1
  fi
  return 0
}

validate_path() {
  local path="$1"
  # Path must not contain unquoted spaces or special characters that break sed
  if [[ -z "$path" ]]; then
    warn "Path cannot be empty"
    return 1
  fi
  # Check for problematic characters: unescaped spaces, quotes, backticks, $, etc.
  if [[ "$path" =~ [[:space:]\'\"\`\$] ]]; then
    warn "Invalid path. Must not contain spaces, quotes, or special shell characters"
    return 1
  fi
  return 0
}

validate_password() {
  local password="$1"
  # Password must not contain characters that break sed substitution or MySQL heredocs
  if [[ -z "$password" ]]; then
    warn "Password cannot be empty"
    return 1
  fi
  # Check for problematic characters: /, &, \, ', ", `, $
  if [[ "$password" =~ [/\&\\\'\"\`\$] ]]; then
    warn "Invalid password. Must not contain: / & \\ ' \" \` \$"
    return 1
  fi
  return 0
}

prompt() {
  # prompt <varname> <message> [default] [validator]
  # If default is omitted entirely → field is required
  # If default is "" (empty string) → field is optional
  # If default is a non-empty string → shown as hint, used when input is blank
  local varname="$1" msg="$2" validator="${4:-}" hint=""
  local has_default=false default=""
  if [[ $# -ge 3 ]]; then
    has_default=true
    default="$3"
    [[ -n "$default" ]] && hint=" ${DIM}[${default}]${RESET}"
  fi

  while true; do
    local val
    read -rp "$(echo -e "  ${BOLD_CYAN}→  $msg$hint: ${RESET}")" val
    val="${val:-$default}"
    ! $has_default && [[ -z "$val" ]] && { warn "This field is required. Please enter a value."; continue; }
    [[ -n "$validator" ]] && ! "$validator" "$val" && continue
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
  
  # Check if process exists before starting spinner
  if ! kill -0 "$pid" 2>/dev/null; then
    # Process already finished, check exit status
    wait "$pid" 2>/dev/null
    local status=$?
    if [[ $status -eq 0 ]]; then
      printf "\r  ${BOLD_GREEN}✔${RESET}  $msg\n"
    else
      printf "\r  ${BOLD_RED}✖${RESET}  $msg (failed)\n"
    fi
    return $status
  fi
  
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${CYAN}${frames[$i]}${RESET}  $msg"
    i=$(( (i+1) % ${#frames[@]} ))
    sleep 0.1
  done
  
  # Get exit status after process completes
  wait "$pid" 2>/dev/null
  local status=$?
  if [[ $status -eq 0 ]]; then
    printf "\r  ${BOLD_GREEN}✔${RESET}  $msg\n"
  else
    printf "\r  ${BOLD_RED}✖${RESET}  $msg (failed)\n"
  fi
  return $status
}

run_cmd() {
  local msg="$1"; shift
  local tmp_err
  tmp_err=$(mktemp)
  "$@" >"$tmp_err" 2>&1 &
  local pid=$!
  spinner "$pid" "$msg"
  wait "$pid"
  local status=$?
  if [[ $status -ne 0 ]]; then
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local error_output
    error_output=$(cat "$tmp_err")
    
    # Display comprehensive error information
    echo "" >&2
    echo "================================================================================" >&2
    echo "ERROR: Command failed at $timestamp" >&2
    echo "Step: $msg" >&2
    echo "Command: $*" >&2
    echo "Exit Code: $status" >&2
    echo "--------------------------------------------------------------------------------" >&2
    echo "Error Output:" >&2
    echo "$error_output" >&2
    echo "================================================================================" >&2
    
    # Also log to file if LOG_FILE is set
    if [[ -n "${LOG_FILE:-}" && -f "$LOG_FILE" ]]; then
      {
        echo ""
        echo "================================================================================"
        echo "ERROR: Command failed at $timestamp"
        echo "Step: $msg"
        echo "Command: $*"
        echo "Exit Code: $status"
        echo "--------------------------------------------------------------------------------"
        echo "Error Output:"
        echo "$error_output"
        echo "================================================================================"
      } >> "$LOG_FILE"
    fi
    
    rm -f "$tmp_err"
    return 1
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
    "$@"
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
  echo -e "  ${GREEN}[1]${RESET} Moodle 5.1  ${DIM}(MOODLE_501_STABLE — Latest)${RESET}"
  echo -e "  ${GREEN}[2]${RESET} Moodle 4.5  ${DIM}(MOODLE_405_STABLE — LTS, recommended)${RESET}"
  echo -e "  ${GREEN}[3]${RESET} Moodle 4.4  ${DIM}(MOODLE_404_STABLE)${RESET}"
  echo -e "  ${GREEN}[4]${RESET} Moodle 4.3  ${DIM}(MOODLE_403_STABLE)${RESET}"
  echo -e "  ${GREEN}[5]${RESET} Moodle 4.2  ${DIM}(MOODLE_402_STABLE)${RESET}"
  echo -e "  ${GREEN}[6]${RESET} Moodle 4.1  ${DIM}(MOODLE_401_STABLE — LTS)${RESET}"
  echo -e "  ${YELLOW}[7]${RESET} Moodle main ${DIM}(bleeding edge — NOT for production)${RESET}"
  echo ""
  while true; do
    local _ver_choice
    read -rp "$(echo -e "  ${BOLD_CYAN}→  Version [1-7]: ${RESET}")" _ver_choice
    case "$_ver_choice" in
      1) printf -v "$varname" '%s' "MOODLE_501_STABLE"; break ;;
      2) printf -v "$varname" '%s' "MOODLE_405_STABLE"; break ;;
      3) printf -v "$varname" '%s' "MOODLE_404_STABLE"; break ;;
      4) printf -v "$varname" '%s' "MOODLE_403_STABLE"; break ;;
      5) printf -v "$varname" '%s' "MOODLE_402_STABLE"; break ;;
      6) printf -v "$varname" '%s' "MOODLE_401_STABLE"; break ;;
      7)
        warn "The 'main' branch is unstable and not suitable for production."
        confirm "Are you sure you want to use main?" && { printf -v "$varname" '%s' "main"; break; }
        ;;
      *) warn "Please enter a number between 1 and 7." ;;
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
    # Detect current version
    local current_version
    current_version=$(detect_installed_version "$dir")
    
    local current_branch=""
    if [[ -d "$dir/.git" ]]; then
      current_branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    fi
    
    # Map target branch to version number
    local target_version
    target_version=$(get_version_display_name "$branch")
    
    warn "Existing Moodle installation detected in $dir"
    info "Current version: Moodle $current_version"
    [[ -n "$current_branch" ]] && info "Current branch: $current_branch"
    info "Target version:  Moodle $target_version ($branch)"
    echo ""
    
    # Check if this is an upgrade
    if [[ "$current_version" != "$target_version" && "$current_version" != "unknown" ]]; then
      echo -e "  ${BOLD}What would you like to do?${RESET}"
      echo -e "  ${GREEN}[1]${RESET} Upgrade to Moodle $target_version ${DIM}(preserves config.php, database, moodledata)${RESET}"
      echo -e "  ${YELLOW}[2]${RESET} Reinstall ${DIM}(wipe Moodle files only — database untouched)${RESET}"
      echo -e "  ${RED}[3]${RESET} Cancel"
      echo ""
      
      while true; do
        local _dir_choice
        read -rp "$(echo -e "  ${BOLD_CYAN}→  Choice [1/2/3]: ${RESET}")" _dir_choice
        case "$_dir_choice" in
          1)
            # Validate upgrade path
            if ! validate_upgrade_path "$current_version" "$target_version"; then
              pause
              return 1
            fi
            
            # Check dependencies
            if ! check_upgrade_dependencies "$target_version"; then
              warn ""
              warn "System dependencies need to be upgraded first"
              if confirm "Upgrade dependencies now?"; then
                upgrade_dependencies "$current_version" "$target_version" || {
                  error "Failed to upgrade dependencies"
                  return 1
                }
              else
                error "Cannot proceed without upgrading dependencies"
                return 1
              fi
            fi
            
            MOODLE_INSTALL_MODE="upgrade"
            return 0
            ;;
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
      # Same version or unknown - offer reinstall or cancel
      echo -e "  ${BOLD}Moodle $current_version is already installed.${RESET}"
      echo -e "  ${YELLOW}[1]${RESET} Reinstall ${DIM}(wipe and reinstall same version)${RESET}"
      echo -e "  ${RED}[2]${RESET} Cancel"
      echo ""
      
      while true; do
        local _dir_choice
        read -rp "$(echo -e "  ${BOLD_CYAN}→  Choice [1/2]: ${RESET}")" _dir_choice
        case "$_dir_choice" in
          1)
            if confirm "Wipe $dir and reinstall Moodle $current_version?"; then
              rm -rf "$dir"
              mkdir -p "$dir"
              MOODLE_INSTALL_MODE="fresh"
              return 0
            fi
            ;;
          2) main_menu; return 1 ;;
          *) warn "Please enter 1 or 2." ;;
        esac
      done
    fi
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

    git -C "$dir" fetch --depth=1 origin "$branch" &
    local fetch_pid=$!
    spinner $fetch_pid "Fetching $branch..."
    wait $fetch_pid || { error "git fetch failed. Check your internet connection."; exit 1; }

    # Preserve config.php across checkout
    local config_backup=""
    if [[ -f "$dir/config.php" ]]; then
      config_backup=$(cat "$dir/config.php")
    fi

    git -C "$dir" checkout -B "$branch" "origin/$branch" &
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
      https://github.com/moodle/moodle.git "$tmp_dir" &
    local clone_pid=$!
    spinner $clone_pid "Cloning Moodle $branch..."
    wait $clone_pid || { error "git clone failed."; rm -rf "$tmp_dir"; exit 1; }
    cp -a "$tmp_dir/." "$dir/"
    rm -rf "$tmp_dir"
    success "Moodle $branch cloned into $dir"

  else
    write_section "Downloading Moodle $branch"
    git clone --depth=1 --branch "$branch" \
      https://github.com/moodle/moodle.git "$dir" &
    local clone_pid=$!
    spinner $clone_pid "Cloning Moodle $branch..."
    wait $clone_pid || { error "git clone failed. Check your internet connection and that the branch '$branch' exists."; exit 1; }
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
