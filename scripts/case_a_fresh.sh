#!/usr/bin/env bash
# scripts/case_a_fresh.sh — Fresh Linux server installation

run_fresh_install() {
  require_root
  run_preflight

  write_section "Case A — Fresh Linux Server Install"
  info "This will install: Apache2, PHP 8.3, MariaDB, Redis, and Moodle 4.5"
  confirm "Ready to begin?" || { main_menu; return; }

  # ── Collect configuration ─────────────────────────────────
  write_section "Configuration"

  prompt SITE_DOMAIN   "Your Moodle domain or IP" "localhost"
  prompt MOODLE_DIR    "Moodle installation directory (e.g. /var/www/html/moodle)"
  prompt MOODLE_DATA   "Moodle data directory (outside webroot, e.g. /var/moodledata)"
  prompt DB_NAME       "Database name" "kbm_moodle"
  prompt DB_USER       "Database username" "moodleuser"
  prompt_secret DB_PASS "Database password (leave blank to auto-generate)"
  if [[ -z "$DB_PASS" ]]; then
    DB_PASS=$(generate_password)
    echo -e "  ${BOLD_YELLOW}  ★  Generated DB password — saved to credentials file${RESET}" >/dev/tty
  fi

  prompt ADMIN_USER    "Moodle admin username" "admin"
  prompt_secret ADMIN_PASS "Moodle admin password (leave blank to auto-generate)"
  if [[ -z "$ADMIN_PASS" ]]; then
    ADMIN_PASS=$(generate_password)
    echo -e "  ${BOLD_YELLOW}  ★  Generated admin password — saved to credentials file${RESET}" >/dev/tty
  fi

  prompt ADMIN_EMAIL   "Moodle admin email" "admin@example.com"
  prompt SITE_NAME     "Site full name" "My Moodle LMS"
  prompt SITE_SHORT    "Site short name" "LMS"

  # Ask about SSL
  echo ""
  echo -e "  ${BOLD}SSL / HTTPS:${RESET}"
  echo -e "  ${GREEN}[1]${RESET} Let's Encrypt (requires a real domain + port 80 open)"
  echo -e "  ${YELLOW}[2]${RESET} Self-signed (for local/dev use)"
  echo -e "  ${DIM}[3]${RESET} Skip SSL for now"
  read -rp "  SSL choice [1/2/3]: " SSL_CHOICE

  # ── Step 1: System update ─────────────────────────────────
  write_section "Step 1 — System Update"
  run_cmd "Updating package lists" apt-get update
  run_cmd "Upgrading packages" apt-get upgrade -y
  success "System updated"

  # ── Step 2: Install dependencies ──────────────────────────
  write_section "Step 2 — Installing Dependencies"

  run_cmd "Installing Apache2" apt_install apache2
  run_cmd "Installing MariaDB" apt_install mariadb-server mariadb-client
  run_cmd "Installing Redis" apt_install redis-server
  run_cmd "Installing PHP 8.3 + extensions" apt_install \
    php8.3 php8.3-cli php8.3-fpm php8.3-mysql php8.3-xml \
    php8.3-mbstring php8.3-curl php8.3-zip php8.3-gd php8.3-intl \
    php8.3-soap php8.3-redis php8.3-opcache php8.3-sodium \
    php8.3-exif php8.3-fileinfo libapache2-mod-php8.3
  run_cmd "Installing utilities" apt_install git curl wget unzip cron

  success "All dependencies installed"

  # ── Step 3: PHP configuration ─────────────────────────────
  write_section "Step 3 — PHP Configuration"
  local php_ini="/etc/php/8.3/apache2/php.ini"

  sed -i 's/^;\?max_input_vars\s*=.*/max_input_vars = 5000/' "$php_ini"
  sed -i 's/^;\?upload_max_filesize\s*=.*/upload_max_filesize = 512M/' "$php_ini"
  sed -i 's/^;\?post_max_size\s*=.*/post_max_size = 512M/' "$php_ini"
  sed -i 's/^;\?memory_limit\s*=.*/memory_limit = 256M/' "$php_ini"
  sed -i 's/^;\?max_execution_time\s*=.*/max_execution_time = 300/' "$php_ini"
  sed -i 's/^;\?opcache.enable\s*=.*/opcache.enable = 1/' "$php_ini"
  sed -i 's/^;\?opcache.memory_consumption\s*=.*/opcache.memory_consumption = 128/' "$php_ini"

  success "PHP configured"

  # ── Step 4: MariaDB setup ─────────────────────────────────
  write_section "Step 4 — Database Setup"

  systemctl start mariadb
  systemctl enable mariadb

  mysql -u root <<MYSQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
MYSQL

  success "Database '${DB_NAME}' and user '${DB_USER}' created"

  # ── Step 5: Redis ─────────────────────────────────────────
  write_section "Step 5 — Redis Setup"
  systemctl enable redis-server
  systemctl start redis-server
  success "Redis running"

  # ── Step 6: Download Moodle ───────────────────────────────
  write_section "Step 6 — Downloading Moodle 4.5"

  if [[ -d "$MOODLE_DIR" ]]; then
    warn "Directory $MOODLE_DIR already exists."
    confirm "Remove and reinstall?" && rm -rf "$MOODLE_DIR"
  fi

  mkdir -p "$MOODLE_DIR"
  mkdir -p "$MOODLE_DATA"

  info "Cloning Moodle 4.5 from git (this may take a few minutes)..."
  git clone --depth=1 --branch MOODLE_405_STABLE \
    https://github.com/moodle/moodle.git "$MOODLE_DIR" &>/dev/null &
  local clone_pid=$!
  spinner $clone_pid "Cloning Moodle 4.5..."
  wait $clone_pid || { error "git clone failed. Check your internet connection and try again."; exit 1; }

  success "Moodle source downloaded to $MOODLE_DIR"

  # ── Step 7: Permissions ───────────────────────────────────
  write_section "Step 7 — Setting Permissions"

  chown -R www-data:www-data "$MOODLE_DIR"
  chown -R www-data:www-data "$MOODLE_DATA"
  chmod -R 755 "$MOODLE_DIR"
  chmod -R 770 "$MOODLE_DATA"

  success "Permissions set"

  # ── Step 8: Apache vhost ──────────────────────────────────
  write_section "Step 8 — Apache Configuration"

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
  a2dissite 000-default.conf &>/dev/null
  a2enmod rewrite &>/dev/null
  systemctl restart apache2

  success "Apache configured for $SITE_DOMAIN"

  # ── Step 9: SSL ───────────────────────────────────────────
  write_section "Step 9 — SSL Setup"
  case "$SSL_CHOICE" in
    1)
      apt_install certbot python3-certbot-apache
      certbot --apache -d "$SITE_DOMAIN" --non-interactive --agree-tos -m "$ADMIN_EMAIL" || \
        warn "Let's Encrypt failed. Check that your domain points to this server and port 80 is open."
      ;;
    2)
      apt_install openssl
      openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/moodle-selfsigned.key \
        -out /etc/ssl/certs/moodle-selfsigned.crt \
        -subj "/CN=${SITE_DOMAIN}" &>/dev/null
      success "Self-signed certificate created"
      ;;
    3) info "SSL skipped. Remember to add HTTPS before going live." ;;
  esac

  # ── Step 10: Generate config.php ──────────────────────────
  write_section "Step 10 — Generating config.php"

  local WWWROOT="http://${SITE_DOMAIN}"
  [[ "$SSL_CHOICE" == "1" || "$SSL_CHOICE" == "2" ]] && WWWROOT="https://${SITE_DOMAIN}"

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

// Redis cache
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

  # ── Step 11: CLI install ───────────────────────────────────
  write_section "Step 11 — Running Moodle CLI Install"
  info "This installs the database tables and creates your admin account."
  info "May take 2–5 minutes..."

  sudo -u www-data php "$MOODLE_DIR/admin/cli/install_database.php" \
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

  # ── Step 12: Cron ─────────────────────────────────────────
  write_section "Step 12 — Setting Up Cron"
  (crontab -u www-data -l 2>/dev/null; \
    echo "*/1 * * * * /usr/bin/php ${MOODLE_DIR}/admin/cli/cron.php >/dev/null 2>&1") \
    | crontab -u www-data -
  success "Cron job added (runs every minute)"

  # ── Step 13: Save credentials ─────────────────────────────
  write_section "Step 13 — Saving Credentials"
  local CREDS_FILE="$HOME/moodle-credentials.txt"
  cat > "$CREDS_FILE" <<CREDS
====================================
  MOODLE INSTALL CREDENTIALS
  Generated: $(date)
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
  echo -e "  ${BOLD_GREEN}Moodle 4.5 is installed and running!${RESET}"
  echo ""
  echo -e "  ${BOLD}Access your site:${RESET}  ${CYAN}${WWWROOT}${RESET}"
  echo -e "  ${BOLD}Admin login:${RESET}       ${CYAN}${WWWROOT}/login/index.php${RESET}"
  echo -e "  ${BOLD}Credentials:${RESET}       ${CYAN}$CREDS_FILE${RESET}"
  echo ""
  divider

  # Offer CI/CD next
  echo ""
  if confirm "Would you like to set up CI/CD (GitHub Actions deploy pipeline) now?"; then
    source "$SCRIPT_DIR/scripts/cicd_setup.sh"
    run_cicd_setup
  else
    info "You can run CI/CD setup anytime by choosing option D from the main menu."
    pause
    main_menu
  fi
}
