#!/usr/bin/env bash
# scripts/case_c_cpanel.sh — cPanel / shared hosting interactive guide

run_cpanel_guide() {
  write_section "Case C — cPanel / Shared Hosting"
  info "cPanel doesn't allow root access — this guide walks you through the web panel."
  echo ""
  echo -e "  ${DIM}This wizard will:${RESET}"
  echo -e "  • Check if your host meets Moodle's requirements"
  echo -e "  • Guide you step by step through cPanel"
  echo -e "  • Generate a ready-to-upload config.php"
  echo -e "  • Generate a .htaccess for clean URLs"
  echo -e "  • Show exact SSH commands for your paths"
  echo ""
  pause

  # ── Step 1: Requirements ──────────────────────────────────
  write_section "Step 1 — Hosting Requirements"
  echo -e "  Confirm your host provides all of the following:"
  echo ""
  echo -e "  ${GREEN}[✔]${RESET} PHP 8.1+ (8.3 recommended)"
  echo -e "  ${GREEN}[✔]${RESET} MySQL 8.0+ or MariaDB 10.6+"
  echo -e "  ${GREEN}[✔]${RESET} At least 256MB PHP memory_limit"
  echo -e "  ${GREEN}[✔]${RESET} SSH access (strongly recommended)"
  echo -e "  ${GREEN}[✔]${RESET} Cron job support"
  echo -e "  ${GREEN}[✔]${RESET} Ability to create databases and users"
  echo ""
  warn "Moodle is NOT reliable on shared hosting with less than 256MB RAM or PHP < 8.1."
  warn "Consider a VPS (DigitalOcean, Hetzner, Vultr) for production use."
  echo ""
  confirm "My host meets these requirements. Continue?" || { main_menu; return; }

  # ── Step 2: Configuration ─────────────────────────────────
  write_section "Step 2 — Your Configuration"

  prompt SITE_DOMAIN  "Your domain (e.g. learn.yoursite.com)"
  prompt CPANEL_USER  "Your cPanel username (e.g. myuser)"
  prompt MOODLE_DIR   "Full path to Moodle (e.g. /home/myuser/public_html/moodle)"
  prompt MOODLE_DATA  "Full path to moodledata — OUTSIDE public_html (e.g. /home/myuser/moodledata)"
  prompt DB_HOST      "Database host" "localhost"
  prompt DB_NAME      "Database name (as created in cPanel, e.g. myuser_moodle)"
  prompt DB_USER      "Database username (e.g. myuser_moodleuser)"
  prompt_secret DB_PASS "Database password"
  prompt ADMIN_USER   "Moodle admin username" "admin"
  prompt_secret ADMIN_PASS "Moodle admin password"
  prompt ADMIN_EMAIL  "Moodle admin email"
  prompt SITE_NAME    "Site full name" "My Moodle LMS"
  prompt SITE_SHORT   "Site short name" "LMS"

  # ── Detect cPanel PHP path ────────────────────────────────
  # cPanel uses ea-php or /usr/local/bin/php — detect which is available
  local CPANEL_PHP_BIN="/usr/local/bin/php"
  echo ""
  echo -e "  ${BOLD}cPanel PHP binary detection:${RESET}"
  echo -e "  Common paths on cPanel hosts:"
  echo -e "  ${DIM}/usr/local/bin/php${RESET}                    (most cPanel hosts)"
  echo -e "  ${DIM}/opt/cpanel/ea-php83/root/usr/bin/php${RESET} (EasyApache 4, PHP 8.3)"
  echo -e "  ${DIM}/opt/cpanel/ea-php82/root/usr/bin/php${RESET} (EasyApache 4, PHP 8.2)"
  echo -e "  ${DIM}/opt/cpanel/ea-php81/root/usr/bin/php${RESET} (EasyApache 4, PHP 8.1)"
  echo ""
  prompt CPANEL_PHP_BIN "PHP binary path on your server" "/usr/local/bin/php"

  # ── Version selection ─────────────────────────────────────
  local MOODLE_BRANCH
  pick_moodle_version MOODLE_BRANCH

  # ── Detect existing install ───────────────────────────────
  local MOODLE_INSTALL_MODE="fresh"
  if [[ -f "$MOODLE_DIR/version.php" ]]; then
    warn "Existing Moodle installation detected in $MOODLE_DIR"
    echo -e "  ${GREEN}[1]${RESET} Upgrade to $MOODLE_BRANCH"
    echo -e "  ${YELLOW}[2]${RESET} Reinstall (wipe Moodle files, keep database)"
    echo -e "  ${RED}[3]${RESET} Cancel"
    echo ""
    while true; do
      local _mode_choice
      read -rp "$(echo -e "  ${BOLD_CYAN}→  Choice [1/2/3]: ${RESET}")" _mode_choice
      case "$_mode_choice" in
        1) MOODLE_INSTALL_MODE="upgrade"; break ;;
        2) MOODLE_INSTALL_MODE="fresh";   break ;;
        3) main_menu; return ;;
        *) warn "Please enter 1, 2, or 3." ;;
      esac
    done
  elif [[ -d "$MOODLE_DIR" ]]; then
    local file_count
    file_count=$(find "$MOODLE_DIR" -maxdepth 1 -mindepth 1 | wc -l)
    if (( file_count > 0 )); then
      warn "Directory $MOODLE_DIR exists with $file_count item(s) but no Moodle found."
      echo -e "  ${GREEN}[1]${RESET} Clone Moodle into this directory (existing files kept)"
      echo -e "  ${YELLOW}[2]${RESET} Wipe directory and do a clean clone"
      echo -e "  ${RED}[3]${RESET} Cancel"
      echo ""
      while true; do
        local _mode_choice
        read -rp "$(echo -e "  ${BOLD_CYAN}→  Choice [1/2/3]: ${RESET}")" _mode_choice
        case "$_mode_choice" in
          1) MOODLE_INSTALL_MODE="clone_into"; break ;;
          2) MOODLE_INSTALL_MODE="fresh";      break ;;
          3) main_menu; return ;;
          *) warn "Please enter 1, 2, or 3." ;;
        esac
      done
    fi
  fi

  local PARENT_DIR
  PARENT_DIR=$(dirname "$MOODLE_DIR")
  local MOODLE_FOLDER
  MOODLE_FOLDER=$(basename "$MOODLE_DIR")

  # ── Step 3: Database setup ────────────────────────────────
  write_section "Step 3 — cPanel Database Setup"
  echo -e "  ${BOLD}Follow these steps in cPanel → MySQL Databases:${RESET}"
  echo ""
  echo -e "  ${CYAN}3a. Create database${RESET}"
  echo -e "      Name: ${BOLD}${DB_NAME}${RESET}"
  echo ""
  echo -e "  ${CYAN}3b. Create database user${RESET}"
  echo -e "      Username: ${BOLD}${DB_USER}${RESET}"
  echo -e "      Password: ${BOLD}(your chosen password)${RESET}"
  echo ""
  echo -e "  ${CYAN}3c. Add user to database${RESET}"
  echo -e "      Select user + database → Grant ${BOLD}ALL PRIVILEGES${RESET}"
  echo ""
  warn "cPanel prefixes DB names and usernames with your cPanel username."
  warn "If your cPanel user is '${CPANEL_USER}', the DB name in MySQL will be '${CPANEL_USER}_${DB_NAME##*_}'"
  pause

  # ── Step 4: Upload Moodle files ───────────────────────────
  write_section "Step 4 — Upload Moodle Files"

  if [[ "$MOODLE_INSTALL_MODE" == "upgrade" ]]; then
    echo -e "  ${BOLD}Upgrading existing Moodle to ${MOODLE_BRANCH} via SSH:${RESET}"
    echo ""
    echo -e "  ${DIM}cd ${MOODLE_DIR}${RESET}"
    echo -e "  ${DIM}git fetch --depth=1 origin ${MOODLE_BRANCH}${RESET}"
    echo -e "  ${DIM}git checkout -B ${MOODLE_BRANCH} origin/${MOODLE_BRANCH}${RESET}"
    echo ""
    info "After switching branches, run the upgrade (Step 7)."
  else
    echo -e "  ${BOLD}Option A — Via SSH (recommended):${RESET}"
    echo ""
    if [[ "$MOODLE_INSTALL_MODE" == "clone_into" ]]; then
      echo -e "  ${DIM}# Directory not empty — clone to temp then copy:${RESET}"
      echo -e "  ${DIM}git clone --depth=1 --branch ${MOODLE_BRANCH} \\${RESET}"
      echo -e "  ${DIM}    https://github.com/moodle/moodle.git /tmp/moodle_tmp${RESET}"
      echo -e "  ${DIM}cp -a /tmp/moodle_tmp/. ${MOODLE_DIR}/${RESET}"
      echo -e "  ${DIM}rm -rf /tmp/moodle_tmp${RESET}"
    else
      echo -e "  ${DIM}cd ${PARENT_DIR}${RESET}"
      echo -e "  ${DIM}git clone --depth=1 --branch ${MOODLE_BRANCH} \\${RESET}"
      echo -e "  ${DIM}    https://github.com/moodle/moodle.git ${MOODLE_FOLDER}${RESET}"
    fi
    echo ""
    echo -e "  ${DIM}mkdir -p ${MOODLE_DATA}${RESET}"
    echo -e "  ${DIM}chmod 750 ${MOODLE_DATA}${RESET}"
    echo ""
    echo -e "  ${BOLD}Option B — Via File Manager (no SSH):${RESET}"
    echo -e "  1. Download Moodle ${MOODLE_BRANCH} zip from https://download.moodle.org"
    echo -e "  2. Upload via cPanel File Manager → ${PARENT_DIR}"
    echo -e "  3. Extract and rename folder to '${MOODLE_FOLDER}'"
    echo -e "  4. Create moodledata folder at: ${MOODLE_DATA}"
    echo -e "  5. Set moodledata permissions to 750"
  fi
  echo ""
  pause

  # ── Step 5: PHP settings ──────────────────────────────────
  write_section "Step 5 — PHP Settings"
  echo -e "  ${BOLD}Option A — cPanel MultiPHP INI Editor:${RESET}"
  echo -e "  cPanel → MultiPHP INI Editor → Editor Mode → select your domain"
  echo ""
  echo -e "  ${CYAN}max_input_vars     = 5000${RESET}"
  echo -e "  ${CYAN}memory_limit       = 256M${RESET}"
  echo -e "  ${CYAN}upload_max_filesize = 512M${RESET}"
  echo -e "  ${CYAN}post_max_size      = 512M${RESET}"
  echo -e "  ${CYAN}max_execution_time = 300${RESET}"
  echo ""
  echo -e "  ${BOLD}Option B — .user.ini (for PHP-FPM / CGI hosts):${RESET}"
  echo -e "  Create ${MOODLE_DIR}/.user.ini with:"
  echo ""
  echo -e "  ${DIM}max_input_vars = 5000${RESET}"
  echo -e "  ${DIM}memory_limit = 256M${RESET}"
  echo -e "  ${DIM}upload_max_filesize = 512M${RESET}"
  echo -e "  ${DIM}post_max_size = 512M${RESET}"
  echo -e "  ${DIM}max_execution_time = 300${RESET}"
  echo ""
  warn ".htaccess php_value directives only work with mod_php. Most modern cPanel hosts use PHP-FPM — use .user.ini instead."
  pause

  # ── Step 6: Generate config.php ───────────────────────────
  write_section "Step 6 — Generating config.php"

  local CONFIG_FILE="$SCRIPT_DIR/config.php"

  # cPanel uses mysqli (not mariadb native driver) for shared hosting
  cat > "$CONFIG_FILE" <<CONFIG
<?php  // Moodle configuration file

unset(\$CFG);
global \$CFG;
\$CFG = new stdClass();

\$CFG->dbtype    = 'mysqli';
\$CFG->dblibrary = 'native';
\$CFG->dbhost    = '${DB_HOST}';
\$CFG->dbname    = '${DB_NAME}';
\$CFG->dbuser    = '${DB_USER}';
\$CFG->dbpass    = '${DB_PASS}';
\$CFG->prefix    = 'mdl_';
\$CFG->dboptions = array(
  'dbpersist' => 0,
  'dbport'    => '',
  'dbsocket'  => '',
  'dbcollation' => 'utf8mb4_unicode_ci',
);

\$CFG->wwwroot  = 'https://${SITE_DOMAIN}';
\$CFG->dataroot = '${MOODLE_DATA}';
\$CFG->admin    = 'admin';
\$CFG->directorypermissions = 0750;

// Increase performance on shared hosting
\$CFG->cachetype = 'file';
\$CFG->pathtophp = '${CPANEL_PHP_BIN}';

require_once(__DIR__ . '/lib/setup.php');
CONFIG

  success "config.php generated → $CONFIG_FILE"

  # Generate .htaccess for clean URLs
  local HTACCESS_FILE="$SCRIPT_DIR/moodle.htaccess"
  cat > "$HTACCESS_FILE" <<HTACCESS
# Moodle .htaccess — rename to .htaccess and place in Moodle root
Options -Indexes
DirectoryIndex index.php index.html

<IfModule mod_rewrite.c>
  RewriteEngine On
  RewriteBase /
  RewriteCond %{REQUEST_FILENAME} !-f
  RewriteCond %{REQUEST_FILENAME} !-d
  RewriteRule ^(.*)$ index.php [QSA,L]
</IfModule>

# PHP settings (only works with mod_php — use .user.ini for PHP-FPM)
<IfModule mod_php.c>
  php_value max_input_vars 5000
  php_value memory_limit 256M
  php_value upload_max_filesize 512M
  php_value post_max_size 512M
  php_value max_execution_time 300
</IfModule>
HTACCESS

  success ".htaccess template generated → $HTACCESS_FILE"
  echo ""
  echo -e "  ${BOLD}Upload these files:${RESET}"
  echo -e "  ${CYAN}$CONFIG_FILE${RESET}  →  ${MOODLE_DIR}/config.php"
  echo -e "  ${CYAN}$HTACCESS_FILE${RESET}  →  ${MOODLE_DIR}/.htaccess"
  echo ""

  if [[ -d "$MOODLE_DIR" ]]; then
    if confirm "Copy config.php and .htaccess to $MOODLE_DIR now?"; then
      cp "$CONFIG_FILE"   "$MOODLE_DIR/config.php"
      cp "$HTACCESS_FILE" "$MOODLE_DIR/.htaccess"
      chmod 640 "$MOODLE_DIR/config.php"
      success "Files copied to $MOODLE_DIR"
    fi
  else
    warn "Moodle directory not found locally — upload files manually via SFTP/File Manager."
  fi
  pause

  # ── Step 7: Install / Upgrade ─────────────────────────────
  write_section "Step 7 — Install / Upgrade Moodle"

  if [[ "$MOODLE_INSTALL_MODE" == "upgrade" ]]; then
    echo -e "  ${BOLD}Run via SSH:${RESET}"
    echo ""
    echo -e "  ${DIM}${CPANEL_PHP_BIN} ${MOODLE_DIR}/admin/cli/upgrade.php --non-interactive${RESET}"
    echo -e "  ${DIM}${CPANEL_PHP_BIN} ${MOODLE_DIR}/admin/cli/purge_caches.php${RESET}"
    echo ""
    echo -e "  ${BOLD}Or via browser:${RESET}"
    echo -e "  Visit https://${SITE_DOMAIN}/admin and follow the upgrade prompts."
  else
    echo -e "  ${BOLD}Option A — SSH (recommended):${RESET}"
    echo ""
    echo -e "  ${DIM}${CPANEL_PHP_BIN} ${MOODLE_DIR}/admin/cli/install_database.php \\${RESET}"
    echo -e "  ${DIM}  --agree-license \\${RESET}"
    echo -e "  ${DIM}  --fullname=\"${SITE_NAME}\" \\${RESET}"
    echo -e "  ${DIM}  --shortname=\"${SITE_SHORT}\" \\${RESET}"
    echo -e "  ${DIM}  --adminuser=\"${ADMIN_USER}\" \\${RESET}"
    echo -e "  ${DIM}  --adminpass=\"${ADMIN_PASS}\" \\${RESET}"
    echo -e "  ${DIM}  --adminemail=\"${ADMIN_EMAIL}\"${RESET}"
    echo ""
    echo -e "  ${BOLD}Option B — Browser:${RESET}"
    echo -e "  Visit https://${SITE_DOMAIN} and follow the on-screen installer."
  fi
  echo ""
  pause

  # ── Step 8: Cron ──────────────────────────────────────────
  write_section "Step 8 — Cron Job"
  echo -e "  cPanel → Cron Jobs → Add New Cron Job"
  echo -e "  Frequency: Every minute (*/1 * * * *)"
  echo -e "  Command:"
  echo ""
  echo -e "  ${DIM}${CPANEL_PHP_BIN} ${MOODLE_DIR}/admin/cli/cron.php >/dev/null 2>&1${RESET}"
  echo ""
  warn "If the PHP path doesn't work, check cPanel → MultiPHP Manager for your active PHP version."
  pause

  # ── Step 9: Save credentials ──────────────────────────────
  local CREDS_FILE="$HOME/moodle-credentials.txt"
  cat > "$CREDS_FILE" <<CREDS
====================================
  MOODLE cPANEL CREDENTIALS
  Generated: $(date)
  Version:   ${MOODLE_BRANCH}
====================================
Site URL:         https://${SITE_DOMAIN}
Moodle Dir:       ${MOODLE_DIR}
Moodle Data:      ${MOODLE_DATA}
cPanel User:      ${CPANEL_USER}
PHP Binary:       ${CPANEL_PHP_BIN}
Admin User:       ${ADMIN_USER}
Admin Password:   ${ADMIN_PASS}
Admin Email:      ${ADMIN_EMAIL}
Database Host:    ${DB_HOST}
Database Name:    ${DB_NAME}
Database User:    ${DB_USER}
Database Pass:    ${DB_PASS}
====================================
KEEP THIS FILE SECURE — DELETE AFTER USE
====================================
CREDS
  chmod 600 "$CREDS_FILE"
  success "Credentials saved to $CREDS_FILE"

  write_section "cPanel Guide Complete"
  echo -e "  ${BOLD_GREEN}Follow the steps above and your Moodle will be live!${RESET}"
  echo ""
  echo -e "  Generated files:"
  echo -e "  ${CYAN}$CONFIG_FILE${RESET}   → upload to ${MOODLE_DIR}/config.php"
  echo -e "  ${CYAN}$HTACCESS_FILE${RESET} → upload to ${MOODLE_DIR}/.htaccess"
  echo -e "  ${CYAN}$CREDS_FILE${RESET}    → keep secure"
  divider
  pause
  main_menu
}
