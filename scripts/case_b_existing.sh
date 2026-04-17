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
  if check_php_version; then
    PHP_OK=true
  fi

  # Detect MariaDB
  local DB_OK=false
  local DB_VERSION=""
  if check_mariadb; then
    DB_OK=true
    DB_VERSION=$(detect_database_version)
  fi

  divider
  echo -e "  ${BOLD}Environment summary:${RESET}"
  echo -e "  Web server : ${CYAN}${WEB_SERVER}${RESET}"
  if [[ "$PHP_OK" == "true" ]]; then
    echo -e "  PHP 8.1+   : ${BOLD_GREEN}Yes (${PHP_VER})${RESET}"
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

  prompt SITE_DOMAIN "Your Moodle domain or IP" "localhost" "validate_domain"
  prompt MOODLE_DIR  "Moodle installation directory (e.g. /var/www/html/moodle)" "" "validate_path"
  prompt MOODLE_DATA "Moodle data directory — OUTSIDE webroot (e.g. /var/moodledata)" "" "validate_path"
  prompt DB_NAME     "Database name" "moodle"
  prompt DB_USER     "Database username" "moodleuser"
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

  prompt ADMIN_USER  "Moodle admin username" "admin"
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

  prompt ADMIN_EMAIL "Moodle admin email" "admin@example.com" "validate_email"
  prompt SITE_NAME   "Site full name" "My Moodle LMS"
  prompt SITE_SHORT  "Site short name" "LMS"

  # ── Version selection ─────────────────────────────────────
  local MOODLE_BRANCH
  pick_moodle_version MOODLE_BRANCH

  # ── Database version compatibility check ──────────────────
  if [[ "$DB_OK" == "true" ]]; then
    check_database_compatibility "$MOODLE_BRANCH" "$DB_VERSION" || { error "Installed database version incompatible with selected Moodle version"; exit 1; }
  fi

  # ── PHP: install/upgrade if needed ────────────────────────
  if [[ "$PHP_OK" == "false" ]]; then
    write_section "Installing PHP 8.3"
    run_cmd "Installing software-properties-common" apt_install software-properties-common || { error "Failed to install software-properties-common. See error above."; exit 1; }
    run_cmd "Adding ondrej/php PPA" add-apt-repository -y ppa:ondrej/php || { error "Failed to add ondrej/php PPA. See error above."; exit 1; }
    run_cmd "Updating package lists" apt-get update || { error "Failed to update package lists. See error above."; exit 1; }

    if [[ "$WEB_SERVER" == "nginx" ]]; then
      run_cmd "Installing PHP 8.3 core" platform_install_package php8.3 || { error "Failed to install PHP 8.3. See error above."; exit 1; }
      run_cmd "Installing PHP 8.3 CLI" platform_install_package php8.3-cli || { error "Failed to install PHP CLI. See error above."; exit 1; }
      run_cmd "Installing PHP 8.3 FPM" platform_install_package php8.3-fpm || { error "Failed to install PHP FPM. See error above."; exit 1; }
      run_cmd "Installing PHP MySQL extension" platform_install_package php8.3-mysql || { error "Failed to install PHP MySQL. See error above."; exit 1; }
      run_cmd "Installing PHP XML extension" platform_install_package php8.3-xml || { error "Failed to install PHP XML. See error above."; exit 1; }
      run_cmd "Installing PHP mbstring extension" platform_install_package php8.3-mbstring || { error "Failed to install PHP mbstring. See error above."; exit 1; }
      run_cmd "Installing PHP curl extension" platform_install_package php8.3-curl || { error "Failed to install PHP curl. See error above."; exit 1; }
      run_cmd "Installing PHP zip extension" platform_install_package php8.3-zip || { error "Failed to install PHP zip. See error above."; exit 1; }
      run_cmd "Installing PHP GD extension" platform_install_package php8.3-gd || { error "Failed to install PHP GD. See error above."; exit 1; }
      run_cmd "Installing PHP intl extension" platform_install_package php8.3-intl || { error "Failed to install PHP intl. See error above."; exit 1; }
      run_cmd "Installing PHP soap extension" platform_install_package php8.3-soap || { error "Failed to install PHP soap. See error above."; exit 1; }
      run_cmd "Installing PHP redis extension" platform_install_package php8.3-redis || { error "Failed to install PHP redis. See error above."; exit 1; }
      run_cmd "Installing PHP opcache extension" platform_install_package php8.3-opcache || { error "Failed to install PHP opcache. See error above."; exit 1; }
    else
      run_cmd "Installing PHP 8.3 core" platform_install_package php8.3 || { error "Failed to install PHP 8.3. See error above."; exit 1; }
      run_cmd "Installing PHP 8.3 CLI" platform_install_package php8.3-cli || { error "Failed to install PHP CLI. See error above."; exit 1; }
      run_cmd "Installing PHP MySQL extension" platform_install_package php8.3-mysql || { error "Failed to install PHP MySQL. See error above."; exit 1; }
      run_cmd "Installing PHP XML extension" platform_install_package php8.3-xml || { error "Failed to install PHP XML. See error above."; exit 1; }
      run_cmd "Installing PHP mbstring extension" platform_install_package php8.3-mbstring || { error "Failed to install PHP mbstring. See error above."; exit 1; }
      run_cmd "Installing PHP curl extension" platform_install_package php8.3-curl || { error "Failed to install PHP curl. See error above."; exit 1; }
      run_cmd "Installing PHP zip extension" platform_install_package php8.3-zip || { error "Failed to install PHP zip. See error above."; exit 1; }
      run_cmd "Installing PHP GD extension" platform_install_package php8.3-gd || { error "Failed to install PHP GD. See error above."; exit 1; }
      run_cmd "Installing PHP intl extension" platform_install_package php8.3-intl || { error "Failed to install PHP intl. See error above."; exit 1; }
      run_cmd "Installing PHP soap extension" platform_install_package php8.3-soap || { error "Failed to install PHP soap. See error above."; exit 1; }
      run_cmd "Installing PHP redis extension" platform_install_package php8.3-redis || { error "Failed to install PHP redis. See error above."; exit 1; }
      run_cmd "Installing PHP opcache extension" platform_install_package php8.3-opcache || { error "Failed to install PHP opcache. See error above."; exit 1; }
      run_cmd "Installing Apache PHP module" platform_install_package libapache2-mod-php8.3 || { error "Failed to install Apache PHP module. See error above."; exit 1; }
    fi
    PHP_BIN="php8.3"
    PHP_MAJOR_MINOR="8.3"
    success "PHP 8.3 installed"
  fi

  # ── PHP config ────────────────────────────────────────────
  write_section "Configuring PHP"
  local php_ini
  if [[ "$WEB_SERVER" == "nginx" ]]; then
    php_ini="/etc/php/${PHP_MAJOR_MINOR}/fpm/php.ini"
    # Ensure fpm is installed
    if ! check_cmd "php${PHP_MAJOR_MINOR}-fpm" && ! check_cmd php-fpm; then
      run_cmd "Installing php-fpm" platform_install_package "php${PHP_MAJOR_MINOR}-fpm"
    fi
    platform_enable_service "php${PHP_MAJOR_MINOR}-fpm"
    platform_start_service "php${PHP_MAJOR_MINOR}-fpm"
  else
    php_ini="/etc/php/${PHP_MAJOR_MINOR}/apache2/php.ini"
  fi

  if [[ -f "$php_ini" ]]; then
    sed -i 's/^;\?max_input_vars\s*=.*/max_input_vars = 5000/'           "$php_ini"
    sed -i 's/^;\?upload_max_filesize\s*=.*/upload_max_filesize = 512M/' "$php_ini"
    sed -i 's/^;\?post_max_size\s*=.*/post_max_size = 512M/'             "$php_ini"
    sed -i 's/^;\?memory_limit\s*=.*/memory_limit = 256M/'               "$php_ini"
    sed -i 's/^;\?max_execution_time\s*=.*/max_execution_time = 300/'     "$php_ini"
    success "PHP configured: $php_ini"
  else
    warn "PHP ini not found at $php_ini — skipping PHP config"
  fi

  # Also patch CLI php.ini — Moodle's install_database.php runs via CLI
  local php_cli_ini="/etc/php/${PHP_MAJOR_MINOR}/cli/php.ini"
  if [[ -f "$php_cli_ini" ]]; then
    sed -i 's/^;\?max_input_vars\s*=.*/max_input_vars = 5000/'           "$php_cli_ini"
    sed -i 's/^;\?memory_limit\s*=.*/memory_limit = 256M/'               "$php_cli_ini"
    sed -i 's/^;\?max_execution_time\s*=.*/max_execution_time = 300/'     "$php_cli_ini"
    success "PHP CLI configured: $php_cli_ini"
  fi

  # Reload php-fpm to apply fpm ini changes
  if [[ "$WEB_SERVER" == "nginx" ]]; then
    platform_reload_service "php${PHP_MAJOR_MINOR}-fpm" 2>/dev/null || platform_restart_service "php${PHP_MAJOR_MINOR}-fpm"
  fi

  # ── MariaDB: install if needed ────────────────────────────
  if [[ "$DB_OK" == "false" ]]; then
    write_section "Installing MariaDB"
    install_compatible_database "$MOODLE_BRANCH" || { error "Failed to install compatible MariaDB version. See error above."; exit 1; }
    platform_enable_service mariadb
    platform_start_service mariadb
    success "MariaDB installed"
  fi

  # ── Database setup ────────────────────────────────────────
  write_section "Database Setup"

  if mysql_root -e "USE \`${DB_NAME}\`;" &>/dev/null; then
    warn "Database '${DB_NAME}' already exists."
    if confirm "Drop and recreate it? (THIS DELETES ALL DATA)"; then
      mysql_root -e "DROP DATABASE \`${DB_NAME}\`;"
    fi
  fi

  mysql_root <<MYSQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
MYSQL
  success "Database configured"

  # ── Redis ─────────────────────────────────────────────────
  if ! check_cmd redis-cli; then
    write_section "Installing Redis"
    run_cmd "Installing Redis" platform_install_package redis-server
    platform_enable_service redis-server
    platform_start_service redis-server
    success "Redis installed"
  else
    success "Redis already present"
  fi

  # ── Download Moodle ───────────────────────────────────────
  MOODLE_INSTALL_MODE=""
  handle_moodle_dir "$MOODLE_DIR" "$MOODLE_BRANCH" || return
  mkdir -p "$MOODLE_DATA"
  fetch_moodle "$MOODLE_DIR" "$MOODLE_BRANCH" "$MOODLE_INSTALL_MODE"

  # ── Permissions ───────────────────────────────────────────
  # Ensure www-data owns the moodle files and can traverse parent dirs
  local web_user
  web_user=$(platform_get_web_user)
  platform_set_permissions "$MOODLE_DIR" "$web_user:$web_user" "755"
  platform_set_permissions "$MOODLE_DATA" "$web_user:$web_user" "770"
  # Make all parent directories of MOODLE_DIR traversable by www-data
  local _parent="$MOODLE_DIR"
  while [[ "$_parent" != "/" ]]; do
    _parent="$(dirname "$_parent")"
    [[ -d "$_parent" ]] && chmod o+x "$_parent" 2>/dev/null || true
  done

  # ── Web server config ─────────────────────────────────────
  write_section "Web Server Configuration"
  local WWWROOT="http://${SITE_DOMAIN}"

  if [[ "$WEB_SERVER" == "nginx" ]]; then
    local fpm_sock="/var/run/php/php${PHP_MAJOR_MINOR}-fpm.sock"
    local nginx_conf="/etc/nginx/sites-available/${SITE_DOMAIN}"

    # Disable any existing config for this domain before writing ours
    rm -f "/etc/nginx/sites-enabled/${SITE_DOMAIN}"
    rm -f "/etc/nginx/sites-enabled/moodle"

    cat > "$nginx_conf" <<NGINX
server {
    listen 80;
    server_name ${SITE_DOMAIN};
    root ${MOODLE_DIR};
    index index.php index.html;

    client_max_body_size 512M;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ [^/]\.php(/|\$) {
        fastcgi_split_path_info ^(.+?\.php)(/.*)\$;
        fastcgi_pass unix:${fpm_sock};
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
        include fastcgi_params;
        fastcgi_read_timeout 300;
    }

    # Block access to sensitive files
    location ~ /\.ht          { deny all; }
    location ~ /\.git          { deny all; }
    location /dataroot/        { deny all; }
}
NGINX
    ln -sf "$nginx_conf" "/etc/nginx/sites-enabled/${SITE_DOMAIN}"
    # Remove generic default if it conflicts
    rm -f /etc/nginx/sites-enabled/default
    if nginx -t &>/dev/null; then
      platform_reload_service nginx
      success "Nginx configured"
    else
      error "Nginx config test failed. Check $nginx_conf"
      nginx -t
      exit 1
    fi
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
    a2dissite 000-default.conf &>/dev/null || true
    a2enmod rewrite &>/dev/null
    platform_restart_service apache2
    success "Apache configured"
  fi

  # ── config.php ────────────────────────────────────────────
  write_section "Generating config.php"

  if [[ "$MOODLE_INSTALL_MODE" != "upgrade" ]]; then
    # Detect DB type — prefer mariadb driver, fall back to mysqli
    local DB_TYPE="mariadb"
    if mysql_root -e "SELECT VERSION();" 2>/dev/null | grep -qi "mariadb"; then
      DB_TYPE="mariadb"
    else
      DB_TYPE="mysqli"
    fi

    cat > "$MOODLE_DIR/config.php" <<CONFIG
<?php  // Moodle configuration file

unset(\$CFG);
global \$CFG;
\$CFG = new stdClass();

\$CFG->dbtype    = '${DB_TYPE}';
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
\$CFG->session_redis_database = 0;
\$CFG->session_redis_acquire_lock_timeout = 120;
\$CFG->session_redis_lock_expire = 7200;

require_once(__DIR__ . '/lib/setup.php');
CONFIG
    local web_user
    web_user=$(platform_get_web_user)
    platform_set_permissions "$MOODLE_DIR/config.php" "$web_user:$web_user" "640"
    success "config.php written"
  else
    info "Upgrade mode — existing config.php preserved"
  fi

  # ── CLI install or upgrade ────────────────────────────────
  write_section "Running Moodle Install / Upgrade"

  # Ensure www-data can traverse every component of MOODLE_DIR
  # Walk each directory segment and add o+x if missing
  local _path_check="/"
  for _seg in $(echo "$MOODLE_DIR" | tr '/' ' '); do
    [[ -z "$_seg" ]] && continue
    _path_check="${_path_check%/}/$_seg"
    if [[ -d "$_path_check" ]]; then
      local _perms
      _perms=$(stat -c '%a' "$_path_check")
      # If others have no execute bit, add it so www-data can traverse
      if (( (_perms & 1) == 0 )); then
        chmod o+x "$_path_check"
        info "Added traverse permission to $_path_check for www-data"
      fi
    fi
  done

  local web_user
  web_user=$(platform_get_web_user)
  local PHP_RUNNER="sudo -u $web_user"

  if [[ "$MOODLE_INSTALL_MODE" == "upgrade" ]]; then
    execute_moodle_upgrade "$MOODLE_DIR" "$(get_version_display_name "$MOODLE_BRANCH")" || { error "Moodle upgrade failed. Check the log for details."; exit 1; }
    success "Moodle upgraded to $MOODLE_BRANCH"
  else
    $PHP_RUNNER "$PHP_BIN" "$MOODLE_DIR/admin/cli/install_database.php" \
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
  fi

  # ── Cron ──────────────────────────────────────────────────
  local cron_entry="*/1 * * * * /usr/bin/${PHP_BIN} ${MOODLE_DIR}/admin/cli/cron.php >/dev/null 2>&1"
  add_cron_job "www-data" "$cron_entry"
  success "Cron configured"

  # ── Save credentials ──────────────────────────────────────
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
====================================
KEEP THIS FILE SECURE — DELETE AFTER USE
====================================
CREDS
  chmod 600 "$CREDS_FILE"

  # ── Done ──────────────────────────────────────────────────
  write_section "Installation Complete"
  echo -e "  ${BOLD_GREEN}Moodle ${MOODLE_BRANCH} installed!${RESET}"
  echo -e "  Access:      ${CYAN}${WWWROOT}${RESET}"
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
