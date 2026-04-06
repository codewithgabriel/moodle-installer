#!/usr/bin/env bash
# scripts/case_c_cpanel.sh — cPanel / shared hosting interactive guide

run_cpanel_guide() {
  write_section "Case C — cPanel / Shared Hosting"
  info "cPanel doesn't allow root access, so this guide walks you through the web panel instead."
  echo ""
  echo -e "  ${DIM}This wizard will:${RESET}"
  echo -e "  • Check if your host meets Moodle's requirements"
  echo -e "  • Guide you step by step through cPanel"
  echo -e "  • Generate a config.php ready to upload"
  echo -e "  • Set up a deploy script you can run via SSH or cron"
  echo ""
  pause

  # ── Requirement check ──────────────────────────────────────
  write_section "Step 1 — Check Your Hosting Requirements"
  echo -e "  Before we start, confirm your host provides:"
  echo ""
  echo -e "  ${GREEN}[✔]${RESET} PHP 8.1 or above (8.3 recommended)"
  echo -e "  ${GREEN}[✔]${RESET} MySQL 8.0+ or MariaDB 10.6+"
  echo -e "  ${GREEN}[✔]${RESET} At least 512MB PHP memory limit"
  echo -e "  ${GREEN}[✔]${RESET} SSH access (strongly recommended)"
  echo -e "  ${GREEN}[✔]${RESET} Ability to create subdomains"
  echo -e "  ${GREEN}[✔]${RESET} Cron job support"
  echo ""
  warn "If your host does not meet these, Moodle will NOT run reliably on shared hosting."
  warn "Consider a VPS (DigitalOcean, Hetzner, AWS Lightsail) instead."
  echo ""
  confirm "My host meets these requirements. Continue?" || { main_menu; return; }

  # ── Collect configuration ──────────────────────────────────
  write_section "Step 2 — Enter Your Configuration"

  prompt SITE_DOMAIN  "Your domain (e.g. learn.yoursite.com)" "learn.yoursite.com"
  prompt MOODLE_DIR   "Path to Moodle in public_html (e.g. /home/user/public_html/moodle)" "/home/cpanelusername/public_html/moodle"
  prompt MOODLE_DATA  "Moodle data dir OUTSIDE public_html" "/home/cpanelusername/moodledata"
  prompt DB_HOST      "Database host (check cPanel MySQL — often 'localhost')" "localhost"
  prompt DB_NAME      "Database name (as created in cPanel)" "cpanelusername_kbm"
  prompt DB_USER      "Database username (as created in cPanel)" "cpanelusername_moodleuser"
  prompt_secret DB_PASS "Database password"
  prompt ADMIN_USER   "Moodle admin username" "admin"
  prompt_secret ADMIN_PASS "Moodle admin password"
  prompt ADMIN_EMAIL  "Moodle admin email" "admin@yoursite.com"
  prompt SITE_NAME    "Site full name" "My Moodle LMS"
  prompt SITE_SHORT   "Site short name" "LMS"

  # ── cPanel step-by-step guide ─────────────────────────────
  write_section "Step 3 — cPanel Database Setup (Manual Steps)"
  echo -e "  ${BOLD}Follow these steps in your cPanel:${RESET}"
  echo ""
  echo -e "  ${CYAN}3a. Create the database${RESET}"
  echo -e "      cPanel → MySQL Databases → Create New Database"
  echo -e "      Name: ${BOLD}${DB_NAME}${RESET}"
  echo ""
  echo -e "  ${CYAN}3b. Create the database user${RESET}"
  echo -e "      MySQL Databases → Add New User"
  echo -e "      Username: ${BOLD}${DB_USER}${RESET}"
  echo -e "      Password: ${BOLD}${DB_PASS}${RESET}"
  echo ""
  echo -e "  ${CYAN}3c. Add user to database${RESET}"
  echo -e "      MySQL Databases → Add User to Database"
  echo -e "      Select user + database → Grant ALL PRIVILEGES"
  echo ""
  pause

  # ── Moodle download guide ─────────────────────────────────
  write_section "Step 4 — Upload Moodle Files"
  echo -e "  ${BOLD}Option A — Via SSH (recommended if you have SSH access):${RESET}"
  echo ""
  echo -e "  ${DIM}cd /home/cpanelusername/public_html${RESET}"
  echo -e "  ${DIM}git clone --depth=1 --branch MOODLE_405_STABLE \\${RESET}"
  echo -e "  ${DIM}    https://github.com/moodle/moodle.git moodle${RESET}"
  echo -e "  ${DIM}mkdir -p /home/cpanelusername/moodledata${RESET}"
  echo -e "  ${DIM}chmod 750 /home/cpanelusername/moodledata${RESET}"
  echo ""
  echo -e "  ${BOLD}Option B — Via File Manager (no SSH):${RESET}"
  echo -e "  1. Download Moodle from https://download.moodle.org (choose .zip)"
  echo -e "  2. Upload via cPanel File Manager → public_html"
  echo -e "  3. Extract the zip"
  echo -e "  4. Create moodledata folder ABOVE public_html"
  echo ""
  pause

  # ── PHP settings ─────────────────────────────────────────
  write_section "Step 5 — PHP Settings in cPanel"
  echo -e "  Go to: ${BOLD}cPanel → MultiPHP INI Editor → Editor Mode${RESET}"
  echo -e "  Set the following values:"
  echo ""
  echo -e "  ${CYAN}max_input_vars    = 5000${RESET}"
  echo -e "  ${CYAN}memory_limit      = 256M${RESET}"
  echo -e "  ${CYAN}upload_max_filesize = 512M${RESET}"
  echo -e "  ${CYAN}post_max_size     = 512M${RESET}"
  echo -e "  ${CYAN}max_execution_time = 300${RESET}"
  echo ""
  echo -e "  Or create a ${BOLD}.htaccess${RESET} file in your moodle directory:"
  echo ""
  echo -e "  ${DIM}php_value max_input_vars 5000${RESET}"
  echo -e "  ${DIM}php_value memory_limit 256M${RESET}"
  echo -e "  ${DIM}php_value upload_max_filesize 512M${RESET}"
  echo -e "  ${DIM}php_value post_max_size 512M${RESET}"
  echo ""
  pause

  # ── Generate config.php ───────────────────────────────────
  write_section "Step 6 — Generating config.php"

  local CONFIG_FILE="$SCRIPT_DIR/config.php"
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

require_once(__DIR__ . '/lib/setup.php');
CONFIG

  success "config.php generated → $CONFIG_FILE"
  echo -e "  ${BOLD}Upload this file to:${RESET} ${CYAN}${MOODLE_DIR}/config.php${RESET}"
  echo ""
  # Offer to copy if the Moodle dir already exists locally
  if [[ -d "$MOODLE_DIR" ]]; then
    if confirm "Copy config.php to $MOODLE_DIR now?"; then
      cp "$CONFIG_FILE" "$MOODLE_DIR/config.php"
      chmod 640 "$MOODLE_DIR/config.php"
      success "config.php copied to $MOODLE_DIR/config.php"
    fi
  else
    warn "Moodle directory $MOODLE_DIR not found locally — upload config.php manually via SFTP/File Manager."
  fi
  echo ""
  pause

  # ── Moodle CLI or web install ──────────────────────────────
  write_section "Step 7 — Running the Installer"
  echo -e "  ${BOLD}Option A — SSH (recommended):${RESET}"
  echo ""
  echo -e "  ${DIM}php ${MOODLE_DIR}/admin/cli/install_database.php \\${RESET}"
  echo -e "  ${DIM}  --agree-license \\${RESET}"
  echo -e "  ${DIM}  --fullname=\"${SITE_NAME}\" \\${RESET}"
  echo -e "  ${DIM}  --shortname=\"${SITE_SHORT}\" \\${RESET}"
  echo -e "  ${DIM}  --adminuser=\"${ADMIN_USER}\" \\${RESET}"
  echo -e "  ${DIM}  --adminpass=\"${ADMIN_PASS}\" \\${RESET}"
  echo -e "  ${DIM}  --adminemail=\"${ADMIN_EMAIL}\"${RESET}"
  echo ""
  echo -e "  ${BOLD}Option B — Web browser:${RESET}"
  echo -e "  Visit https://${SITE_DOMAIN} and follow the on-screen installer."
  echo ""
  pause

  # ── Cron setup ────────────────────────────────────────────
  write_section "Step 8 — Cron Job"
  echo -e "  Go to: ${BOLD}cPanel → Cron Jobs${RESET}"
  echo -e "  Set frequency: Every minute (*/1)"
  echo -e "  Command:"
  echo ""
  echo -e "  ${DIM}/usr/local/bin/php ${MOODLE_DIR}/admin/cli/cron.php >/dev/null 2>&1${RESET}"
  echo ""
  warn "If /usr/local/bin/php doesn't work, check cPanel PHP path or ask your host."
  pause

  # ── Save credentials ──────────────────────────────────────
  local CREDS_FILE="$HOME/moodle-credentials.txt"
  cat > "$CREDS_FILE" <<CREDS
====================================
  MOODLE cPANEL CREDENTIALS
  Generated: $(date)
====================================
Site URL:         https://${SITE_DOMAIN}
Moodle Dir:       ${MOODLE_DIR}
Moodle Data:      ${MOODLE_DATA}
Admin User:       ${ADMIN_USER}
Admin Password:   ${ADMIN_PASS}
Admin Email:      ${ADMIN_EMAIL}
Database Host:    ${DB_HOST}
Database Name:    ${DB_NAME}
Database User:    ${DB_USER}
Database Pass:    ${DB_PASS}
====================================
CREDS
  chmod 600 "$CREDS_FILE"
  success "Credentials saved to $CREDS_FILE"

  write_section "cPanel Guide Complete"
  echo -e "  ${BOLD_GREEN}Follow the steps above and your Moodle will be live!${RESET}"
  echo -e "  Generated files in: ${CYAN}$SCRIPT_DIR${RESET}"
  divider
  pause
  main_menu
}
