#!/usr/bin/env bash
# scripts/case_b_existing.sh — Existing Linux server (Apache/Nginx already present)

run_existing_install() {
  require_root
  run_preflight

  write_section "Case B — Existing Linux Server"
  info "Detecting your current environment..."

  # Detect web server
  local WEB_SERVER
  WEB_SERVER=$(check_webserver)

  # Detect PHP
  local PHP_OK=false
  check_php_version && PHP_OK=true

  # Detect MariaDB
  local DB_OK=false
  check_mariadb && DB_OK=true

  divider
  echo -e "  ${BOLD}Environment summary:${RESET}"
  echo -e "  Web server : ${CYAN}${WEB_SERVER}${RESET}"
  if [[ "$PHP_OK" == "true" ]]; then
    echo -e "  PHP 8.1+   : ${BOLD_GREEN}Yes${RESET}"
  else
    echo -e "  PHP 8.1+   : ${BOLD_YELLOW}Needs install/upgrade${RESET}"
  fi
  if [[ "$DB_OK" == "true" ]]; then
    echo -e "  MariaDB    : ${BOLD_GREEN}Yes${RESET}"
  else
    echo -e "  MariaDB    : ${BOLD_YELLOW}Needs install${RESET}"
  fi
  divider

  confirm "Proceed with installation?" || { main_menu; return; }

  # ── Collect configuration ─────────────────────────────────
  write_section "Configuration"

  prompt SITE_DOMAIN "Your Moodle domain or IP" "localhost"
  prompt MOODLE_DIR  "Moodle installation directory (e.g. /var/www/html/moodle)"
  prompt MOODLE_DATA "Moodle data directory (outside webroot, e.g. /var/moodledata)"
  prompt DB_NAME     "Database name" "kbm_moodle"
  prompt DB_USER     "Database username" "moodleuser"
  prompt_secret DB_PASS "Database password (leave blank to auto-generate)"
  if [[ -z "$DB_PASS" ]]; then
    DB_PASS=$(generate_password)
    echo -e "  ${BOLD_YELLOW}  ★  Generated DB password — saved to credentials file${RESET}" >/dev/tty
  fi

  prompt ADMIN_USER  "Moodle admin username" "admin"
  prompt_secret ADMIN_PASS "Moodle admin password (leave blank to auto-generate)"
  if [[ -z "$ADMIN_PASS" ]]; then
    ADMIN_PASS=$(generate_password)
    echo -e "  ${BOLD_YELLOW}  ★  Generated admin password — saved to credentials file${RESET}" >/dev/tty
  fi

  prompt ADMIN_EMAIL "Moodle admin email" "admin@example.com"
  prompt SITE_NAME   "Site full name" "My Moodle LMS"
  prompt SITE_SHORT  "Site short name" "LMS"

  # ── PHP: install/upgrade if needed ────────────────────────
  if [[ "$PHP_OK" == "false" ]]; then
    write_section "Installing PHP 8.3"
    run_cmd "Adding PHP repository" add-apt-repository -y ppa:ondrej/php
    run_cmd "Updating package lists" apt-get update
    run_cmd "Installing PHP 8.3 + extensions" apt_install \
      php8.3 php8.3-cli php8.3-mysql php8.3-xml \
      php8.3-mbstring php8.3-curl php8.3-zip php8.3-gd php8.3-intl \
      php8.3-soap php8.3-redis php8.3-opcache php8.3-sodium \
      php8.3-exif php8.3-fileinfo libapache2-mod-php8.3
    success "PHP 8.3 installed"
  fi

  # ── PHP config ────────────────────────────────────────────
  write_section "Configuring PHP"
  local php_ini
  if [[ "$WEB_SERVER" == "nginx" ]]; then
    php_ini="/etc/php/8.3/fpm/php.ini"
    run_cmd "Installing php8.3-fpm" apt_install php8.3-fpm
  else
    php_ini="/etc/php/8.3/apache2/php.ini"
  fi

  [[ -f "$php_ini" ]] && {
    sed -i 's/^;\?max_input_vars\s*=.*/max_input_vars = 5000/' "$php_ini"
    sed -i 's/^;\?upload_max_filesize\s*=.*/upload_max_filesize = 512M/' "$php_ini"
    sed -i 's/^;\?post_max_size\s*=.*/post_max_size = 512M/' "$php_ini"
    sed -i 's/^;\?memory_limit\s*=.*/memory_limit = 256M/' "$php_ini"
    sed -i 's/^;\?max_execution_time\s*=.*/max_execution_time = 300/' "$php_ini"
    success "PHP configured: $php_ini"
  }

  # ── MariaDB: install if needed ────────────────────────────
  if [[ "$DB_OK" == "false" ]]; then
    write_section "Installing MariaDB"
    run_cmd "Installing MariaDB" apt_install mariadb-server mariadb-client
    systemctl enable mariadb
    systemctl start mariadb
    success "MariaDB installed"
  fi

  # ── Database setup ────────────────────────────────────────
  write_section "Database Setup"

  # Check if DB already exists
  if mysql -u root -e "USE \`${DB_NAME}\`;" &>/dev/null; then
    warn "Database '${DB_NAME}' already exists."
    confirm "Drop and recreate it? (THIS DELETES ALL DATA)" && \
      mysql -u root -e "DROP DATABASE \`${DB_NAME}\`;"
  fi

  mysql -u root <<MYSQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
MYSQL
  success "Database configured"

  # ── Redis ─────────────────────────────────────────────────
  if ! check_cmd redis-cli; then
    write_section "Installing Redis"
    run_cmd "Installing Redis" apt_install redis-server
    systemctl enable redis-server
    systemctl start redis-server
    success "Redis installed"
  else
    success "Redis already present"
  fi

  # ── Download Moodle ───────────────────────────────────────
  write_section "Downloading Moodle 4.5"

  if [[ -d "$MOODLE_DIR" ]]; then
    warn "Directory $MOODLE_DIR already exists."
    confirm "Remove existing Moodle files?" && rm -rf "$MOODLE_DIR"
  fi

  mkdir -p "$MOODLE_DIR" "$MOODLE_DATA"
  git clone --depth=1 --branch MOODLE_405_STABLE \
    https://github.com/moodle/moodle.git "$MOODLE_DIR" &>/dev/null &
  local clone_pid=$!
  spinner $clone_pid "Cloning Moodle 4.5..."
  wait $clone_pid || { error "git clone failed. Check your internet connection and try again."; exit 1; }
  success "Moodle downloaded"

  # ── Permissions ───────────────────────────────────────────
  chown -R www-data:www-data "$MOODLE_DIR" "$MOODLE_DATA"
  chmod -R 755 "$MOODLE_DIR"
  chmod -R 770 "$MOODLE_DATA"

  # ── Web server config ─────────────────────────────────────
  write_section "Web Server Configuration"

  local WWWROOT="http://${SITE_DOMAIN}"

  if [[ "$WEB_SERVER" == "nginx" ]]; then
    cat > "/etc/nginx/sites-available/moodle" <<NGINX
server {
    listen 80;
    server_name ${SITE_DOMAIN};
    root ${MOODLE_DIR};
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht { deny all; }
}
NGINX
    ln -sf /etc/nginx/sites-available/moodle /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx
    success "Nginx configured"
  else
    cat > "/etc/apache2/sites-available/moodle.conf" <<VHOST
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
    a2enmod rewrite &>/dev/null
    systemctl restart apache2
    success "Apache configured"
  fi

  # ── config.php ────────────────────────────────────────────
  write_section "Generating config.php"
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

\$CFG->wwwroot  = '${WWWROOT}';
\$CFG->dataroot = '${MOODLE_DATA}';
\$CFG->admin    = 'admin';
\$CFG->directorypermissions = 0750;

\$CFG->session_handler_class = '\core\session\redis';
\$CFG->session_redis_host = '127.0.0.1';
\$CFG->session_redis_port = 6379;

require_once(__DIR__ . '/lib/setup.php');
CONFIG
  chown www-data:www-data "$MOODLE_DIR/config.php"
  chmod 640 "$MOODLE_DIR/config.php"
  success "config.php written"

  # ── CLI install ───────────────────────────────────────────
  write_section "Running Moodle CLI Install"
  sudo -u www-data php "$MOODLE_DIR/admin/cli/install_database.php" \
    --agree-license \
    --fullname="$SITE_NAME" \
    --shortname="$SITE_SHORT" \
    --adminuser="$ADMIN_USER" \
    --adminpass="$ADMIN_PASS" \
    --adminemail="$ADMIN_EMAIL" &
  local install_pid=$!
  spinner $install_pid "Installing Moodle database..."
  wait $install_pid || { error "Moodle CLI install failed. Check the log for details."; exit 1; }
  success "Database installed"

  # ── Cron ──────────────────────────────────────────────────
  (crontab -u www-data -l 2>/dev/null; \
    echo "*/1 * * * * /usr/bin/php ${MOODLE_DIR}/admin/cli/cron.php >/dev/null 2>&1") \
    | crontab -u www-data -
  success "Cron configured"

  # ── Save credentials ──────────────────────────────────────
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
====================================
CREDS
  chmod 600 "$CREDS_FILE"

  # ── Done ──────────────────────────────────────────────────
  write_section "Installation Complete"
  echo -e "  ${BOLD_GREEN}Moodle 4.5 installed on existing server!${RESET}"
  echo -e "  Access: ${CYAN}${WWWROOT}${RESET}"
  echo -e "  Credentials: ${CYAN}$CREDS_FILE${RESET}"
  divider

  if confirm "Set up CI/CD pipeline now?"; then
    source "$SCRIPT_DIR/scripts/cicd_setup.sh"
    run_cicd_setup
  else
    pause
    main_menu
  fi
}
