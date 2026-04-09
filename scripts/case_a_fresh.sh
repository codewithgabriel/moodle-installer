#!/usr/bin/env bash
# scripts/case_a_fresh.sh — Fresh Linux server installation

run_fresh_install() {
  require_root
  run_preflight

  write_section "Case A — Fresh Linux Server Install"
  info "This will install: Apache2, PHP 8.3, MariaDB, Redis, and Moodle"
  confirm "Ready to begin?" || { main_menu; return; }

  # ── Collect configuration ─────────────────────────────────
  write_section "Configuration"

  # Input validation: domain (hostname pattern), email (@), paths (no spaces/special chars), passwords (no sed/MySQL breaking chars)
  prompt SITE_DOMAIN  "Your Moodle domain or IP" "localhost" "validate_domain"
  prompt MOODLE_DIR   "Moodle installation directory (e.g. /var/www/html/moodle)" "" "validate_path"
  prompt MOODLE_DATA  "Moodle data directory — OUTSIDE webroot (e.g. /var/moodledata)" "" "validate_path"
  prompt DB_NAME      "Database name" "moodle"
  prompt DB_USER      "Database username" "moodleuser"
  prompt_secret DB_PASS "Database password (leave blank to auto-generate)"
  if [[ -z "$DB_PASS" ]]; then
    DB_PASS=$(generate_password)
    echo -e "  ${BOLD_YELLOW}  ★  Generated DB password — saved to credentials file${RESET}" >/dev/tty
  else
    # Validate manually entered password
    while ! validate_password "$DB_PASS"; do
      warn "Invalid password. Must not contain: / & \\ ' \" \` \$"
      prompt_secret DB_PASS "Database password (leave blank to auto-generate)"
      [[ -z "$DB_PASS" ]] && { DB_PASS=$(generate_password); echo -e "  ${BOLD_YELLOW}  ★  Generated DB password — saved to credentials file${RESET}" >/dev/tty; break; }
    done
  fi

  prompt ADMIN_USER   "Moodle admin username" "admin"
  prompt_secret ADMIN_PASS "Moodle admin password (leave blank to auto-generate)"
  if [[ -z "$ADMIN_PASS" ]]; then
    ADMIN_PASS=$(generate_password)
    echo -e "  ${BOLD_YELLOW}  ★  Generated admin password — saved to credentials file${RESET}" >/dev/tty
  else
    # Validate manually entered password
    while ! validate_password "$ADMIN_PASS"; do
      warn "Invalid password. Must not contain: / & \\ ' \" \` \$"
      prompt_secret ADMIN_PASS "Moodle admin password (leave blank to auto-generate)"
      [[ -z "$ADMIN_PASS" ]] && { ADMIN_PASS=$(generate_password); echo -e "  ${BOLD_YELLOW}  ★  Generated admin password — saved to credentials file${RESET}" >/dev/tty; break; }
    done
  fi

  prompt ADMIN_EMAIL  "Moodle admin email" "admin@example.com" "validate_email"
  prompt SITE_NAME    "Site full name" "My Moodle LMS"
  prompt SITE_SHORT   "Site short name" "LMS"

  # ── Version selection ─────────────────────────────────────
  local MOODLE_BRANCH
  pick_moodle_version MOODLE_BRANCH

  # ── SSL choice ────────────────────────────────────────────
  echo ""
  echo -e "  ${BOLD}SSL / HTTPS:${RESET}"
  echo -e "  ${GREEN}[1]${RESET} Let's Encrypt  ${DIM}(requires real domain + port 80 open)${RESET}"
  echo -e "  ${YELLOW}[2]${RESET} Self-signed    ${DIM}(local/dev use)${RESET}"
  echo -e "  ${DIM}[3]${RESET} Skip SSL for now"
  local SSL_CHOICE
  while true; do
    read -rp "  SSL choice [1/2/3]: " SSL_CHOICE
    [[ "$SSL_CHOICE" =~ ^[123]$ ]] && break
    warn "Please enter 1, 2, or 3."
  done

  # ── Step 1: System update ─────────────────────────────────
  write_section "Step 1 — System Update"
  run_cmd "Updating package lists" apt-get update
  # Use noninteractive to avoid kernel upgrade prompts
  run_cmd "Upgrading packages" env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
    -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
  success "System updated"

  # ── Step 2: Add PHP repository ────────────────────────────
  write_section "Step 2 — Adding PHP 8.3 Repository"
  # ondrej/php PPA is required on Ubuntu for PHP 8.3
  run_cmd "Installing software-properties-common" apt_install software-properties-common || { error "Failed to install software-properties-common. See error above."; exit 1; }
  run_cmd "Adding ondrej/php PPA" add-apt-repository -y ppa:ondrej/php || { error "Failed to add ondrej/php PPA. See error above."; exit 1; }
  run_cmd "Updating package lists" apt-get update || { error "Failed to update package lists. See error above."; exit 1; }
  success "PHP repository added"

  # ── Step 3: Install dependencies ──────────────────────────
  write_section "Step 3 — Installing Dependencies"

  run_cmd "Installing Apache2"   apt_install apache2                                    || { error "Failed to install Apache2. See error above."; exit 1; }
  run_cmd "Installing MariaDB"   apt_install mariadb-server mariadb-client              || { error "Failed to install MariaDB. See error above."; exit 1; }
  run_cmd "Installing Redis"     apt_install redis-server                               || { error "Failed to install Redis. See error above."; exit 1; }
  run_cmd "Installing PHP 8.3 + extensions" apt_install \
    php8.3 php8.3-cli php8.3-fpm php8.3-mysql php8.3-xml \
    php8.3-mbstring php8.3-curl php8.3-zip php8.3-gd php8.3-intl \
    php8.3-soap php8.3-redis php8.3-opcache libapache2-mod-php8.3                                   || { error "Failed to install PHP 8.3 packages. See error above."; exit 1; }
  run_cmd "Installing utilities" apt_install git curl wget unzip cron                   || { error "Failed to install utilities. See error above."; exit 1; }

  # Set PHP_BIN for this session
  PHP_BIN="php8.3"
  PHP_MAJOR_MINOR="8.3"
  success "All dependencies installed"

  # ── Step 4: PHP configuration ─────────────────────────────
  write_section "Step 4 — PHP Configuration"
  local php_ini="/etc/php/${PHP_MAJOR_MINOR}/apache2/php.ini"

  if [[ ! -f "$php_ini" ]]; then
    warn "PHP ini not found at $php_ini — skipping PHP config"
  else
    sed -i 's/^;\?max_input_vars\s*=.*/max_input_vars = 5000/'         "$php_ini"
    sed -i 's/^;\?upload_max_filesize\s*=.*/upload_max_filesize = 512M/' "$php_ini"
    sed -i 's/^;\?post_max_size\s*=.*/post_max_size = 512M/'             "$php_ini"
    sed -i 's/^;\?memory_limit\s*=.*/memory_limit = 256M/'               "$php_ini"
    sed -i 's/^;\?max_execution_time\s*=.*/max_execution_time = 300/'     "$php_ini"
    sed -i 's/^;\?opcache\.enable\s*=.*/opcache.enable = 1/'              "$php_ini"
    sed -i 's/^;\?opcache\.memory_consumption\s*=.*/opcache.memory_consumption = 128/' "$php_ini"
    success "PHP configured: $php_ini"
  fi

  # ── Step 5: MariaDB setup ─────────────────────────────────
  write_section "Step 5 — Database Setup"

  svc_start  mariadb
  svc_enable mariadb

  mysql_root <<MYSQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
MYSQL

  success "Database '${DB_NAME}' and user '${DB_USER}' created"

  # ── Step 6: Redis ─────────────────────────────────────────
  write_section "Step 6 — Redis Setup"
  svc_enable redis-server
  svc_start  redis-server
  success "Redis running"

  # ── Step 7: Download Moodle ───────────────────────────────
  MOODLE_INSTALL_MODE=""
  handle_moodle_dir "$MOODLE_DIR" "$MOODLE_BRANCH" || return
  mkdir -p "$MOODLE_DATA"
  fetch_moodle "$MOODLE_DIR" "$MOODLE_BRANCH" "$MOODLE_INSTALL_MODE"

  # ── Step 8: Permissions ───────────────────────────────────
  write_section "Step 8 — Setting Permissions"
  if [[ "$MOODLE_DIR" == /root/* || "$MOODLE_DIR" == /root ]]; then
    warn "Moodle is under /root — www-data cannot traverse /root by default."
    warn "Making /root world-executable so the web server can reach the files."
    chmod o+x /root
    chown -R root:www-data "$MOODLE_DIR" "$MOODLE_DATA"
  else
    chown -R www-data:www-data "$MOODLE_DIR" "$MOODLE_DATA"
  fi
  chmod -R 755 "$MOODLE_DIR"
  chmod -R 770 "$MOODLE_DATA"
  success "Permissions set"

  # ── Step 9: Apache vhost ──────────────────────────────────
  write_section "Step 9 — Apache Configuration"

  local VHOST_FILE="/etc/apache2/sites-available/moodle.conf"
  cat > "$VHOST_FILE" <<VHOST
<VirtualHost *:80>
    ServerName ${SITE_DOMAIN}
    DocumentRoot ${MOODLE_DIR}

    <Directory ${MOODLE_DIR}>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/moodle_error.log
    CustomLog \${APACHE_LOG_DIR}/moodle_access.log combined
</VirtualHost>
VHOST

  a2ensite moodle.conf &>/dev/null
  # Only disable default if it's currently enabled
  a2dissite 000-default.conf &>/dev/null || true
  a2enmod rewrite &>/dev/null
  svc_restart apache2
  success "Apache configured for $SITE_DOMAIN"

  # ── Step 10: SSL ──────────────────────────────────────────
  write_section "Step 10 — SSL Setup"
  local WWWROOT="http://${SITE_DOMAIN}"
  case "$SSL_CHOICE" in
    1)
      run_cmd "Installing certbot" apt_install certbot python3-certbot-apache
      if certbot --apache -d "$SITE_DOMAIN" --non-interactive --agree-tos -m "$ADMIN_EMAIL"; then
        WWWROOT="https://${SITE_DOMAIN}"
        success "Let's Encrypt certificate installed"
      else
        warn "Let's Encrypt failed. Ensure your domain points to this server and port 80 is open."
        warn "Continuing with HTTP — add SSL manually later."
      fi
      ;;
    2)
      run_cmd "Installing openssl" apt_install openssl
      openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/moodle-selfsigned.key \
        -out /etc/ssl/certs/moodle-selfsigned.crt \
        -subj "/CN=${SITE_DOMAIN}" &>/dev/null
      # Add SSL vhost
      cat >> "$VHOST_FILE" <<SSLVHOST

<VirtualHost *:443>
    ServerName ${SITE_DOMAIN}
    DocumentRoot ${MOODLE_DIR}
    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/moodle-selfsigned.crt
    SSLCertificateKeyFile /etc/ssl/private/moodle-selfsigned.key
    <Directory ${MOODLE_DIR}>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
SSLVHOST
      a2enmod ssl &>/dev/null
      svc_restart apache2
      WWWROOT="https://${SITE_DOMAIN}"
      success "Self-signed certificate configured"
      ;;
    3)
      info "SSL skipped. Add HTTPS before going live."
      ;;
  esac

  # ── Step 11: Generate config.php ──────────────────────────
  write_section "Step 11 — Generating config.php"

  # Only write config.php on fresh install — preserve existing on upgrade
  if [[ "$MOODLE_INSTALL_MODE" != "upgrade" ]]; then
    cat > "$MOODLE_DIR/config.php" <<CONFIG
<?php  // Moodle configuration file

unset(\$CFG);
global \$CFG;
\$CFG = new stdClass();

\$CFG->dbtype    = 'mariadb';
\$CFG->dblibrary = 'native';
\$CFG->dbhost    = 'localhost';
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

\$CFG->wwwroot   = '${WWWROOT}';
\$CFG->dataroot  = '${MOODLE_DATA}';
\$CFG->admin     = 'admin';
\$CFG->directorypermissions = 0750;

// Redis session cache
\$CFG->session_handler_class = '\core\session\redis';
\$CFG->session_redis_host = '127.0.0.1';
\$CFG->session_redis_port = 6379;
\$CFG->session_redis_database = 0;
\$CFG->session_redis_acquire_lock_timeout = 120;
\$CFG->session_redis_lock_expire = 7200;

require_once(__DIR__ . '/lib/setup.php');
CONFIG
    chown www-data:www-data "$MOODLE_DIR/config.php"
    chmod 640 "$MOODLE_DIR/config.php"
    success "config.php written"
  else
    info "Upgrade mode — existing config.php preserved"
  fi

  # ── Step 12: CLI install or upgrade ───────────────────────
  local PHP_RUNNER="sudo -u www-data"
  if [[ "$MOODLE_DIR" == /root/* || "$MOODLE_DIR" == /root ]]; then
    PHP_RUNNER=""
  fi

  if [[ "$MOODLE_INSTALL_MODE" == "upgrade" ]]; then
    write_section "Step 12 — Running Moodle Upgrade"
    $PHP_RUNNER "$PHP_BIN" "$MOODLE_DIR/admin/cli/upgrade.php" --non-interactive &
    local upgrade_pid=$!
    spinner $upgrade_pid "Upgrading Moodle database..."
    wait $upgrade_pid || { error "Moodle upgrade failed. Check $LOG_FILE for details."; exit 1; }
    $PHP_RUNNER "$PHP_BIN" "$MOODLE_DIR/admin/cli/purge_caches.php" &>/dev/null
    success "Moodle upgraded to $MOODLE_BRANCH"
  else
    write_section "Step 12 — Running Moodle CLI Install"
    info "Installing database tables and admin account. May take 2–5 minutes..."
    $PHP_RUNNER "$PHP_BIN" "$MOODLE_DIR/admin/cli/install_database.php" \
      --agree-license \
      --fullname="$SITE_NAME" \
      --shortname="$SITE_SHORT" \
      --adminuser="$ADMIN_USER" \
      --adminpass="$ADMIN_PASS" \
      --adminemail="$ADMIN_EMAIL" &
    local install_pid=$!
    spinner $install_pid "Installing Moodle database..."
    wait $install_pid || { error "Moodle CLI install failed. Check $LOG_FILE for details."; exit 1; }
    success "Moodle database installed"
  fi

  # ── Step 13: Cron ─────────────────────────────────────────
  write_section "Step 13 — Setting Up Cron"
  local cron_entry="*/1 * * * * /usr/bin/${PHP_BIN} ${MOODLE_DIR}/admin/cli/cron.php >/dev/null 2>&1"
  add_cron_job "www-data" "$cron_entry"

  # ── Step 14: Firewall guidance ────────────────────────────
  write_section "Step 14 — Firewall"
  if check_cmd ufw; then
    info "UFW detected. Opening ports 80 and 443..."
    ufw allow 80/tcp &>/dev/null
    ufw allow 443/tcp &>/dev/null
    success "Ports 80 and 443 opened in UFW"
  else
    warn "No UFW detected. Ensure ports 80 and 443 are open in your cloud provider's firewall/security group."
  fi

  # ── Step 15: Save credentials ─────────────────────────────
  write_section "Step 15 — Saving Credentials"
  local CREDS_FILE="$HOME/moodle-credentials.txt"
  cat > "$CREDS_FILE" <<CREDS
====================================
  MOODLE INSTALL CREDENTIALS
  Generated: $(date)
  Version:   ${MOODLE_BRANCH}
====================================

Site URL:         ${WWWROOT}
Moodle Dir:       ${MOODLE_DIR}
Moodle Data:      ${MOODLE_DATA}

Admin User:       ${ADMIN_USER}
Admin Password:   ${ADMIN_PASS}
Admin Email:      ${ADMIN_EMAIL}

Database Name:    ${DB_NAME}
Database User:    ${DB_USER}
Database Pass:    ${DB_PASS}
Database Host:    localhost

====================================
KEEP THIS FILE SECURE — DELETE AFTER USE
====================================
CREDS
  chmod 600 "$CREDS_FILE"
  success "Credentials saved to $CREDS_FILE"

  # ── Done ──────────────────────────────────────────────────
  write_section "Installation Complete"
  echo -e "  ${BOLD_GREEN}Moodle ${MOODLE_BRANCH} is installed and running!${RESET}"
  echo ""
  echo -e "  ${BOLD}Access your site:${RESET}  ${CYAN}${WWWROOT}${RESET}"
  echo -e "  ${BOLD}Admin login:${RESET}       ${CYAN}${WWWROOT}/login/index.php${RESET}"
  echo -e "  ${BOLD}Credentials:${RESET}       ${CYAN}$CREDS_FILE${RESET}"
  echo ""
  divider

  if confirm "Set up CI/CD pipeline now?"; then
    source "$SCRIPT_DIR/scripts/cicd_setup.sh"
    run_cicd_setup
  else
    info "You can run CI/CD setup anytime by choosing option D from the main menu."
    pause
    main_menu
  fi
}
