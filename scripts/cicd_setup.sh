#!/usr/bin/env bash
# scripts/cicd_setup.sh — CI/CD pipeline generator (GitHub Actions + deploy script)

run_cicd_setup() {
  write_section "CI/CD Pipeline Setup"
  echo -e "  This generates a complete CI/CD pipeline:"
  echo -e "  • GitHub Actions workflow (test → build → deploy)"
  echo -e "  • Server-side deploy script (pulls, upgrades Moodle)"
  echo -e "  • SSH key setup instructions"
  echo -e "  • Environment secrets checklist"
  echo ""
  pause

  # ── Collect config ────────────────────────────────────────
  write_section "Pipeline Configuration"

  prompt REPO_NAME    "GitHub repository (user/repo)" "yourname/moodle-site"
  prompt SERVER_IP    "Production server IP or hostname" "your-server-ip"
  prompt SERVER_USER  "SSH user on server (avoid root — use 'deploy' or 'ubuntu')" "deploy"
  prompt MOODLE_DIR   "Moodle directory on server (e.g. /var/www/html/moodle)"
  prompt MOODLE_DATA  "Moodle data directory (e.g. /var/moodledata)"
  prompt DEPLOY_BRANCH "Branch to deploy from" "main"
  prompt SLACK_NOTIFY "Slack webhook URL for notifications (leave blank to skip)" ""

  local OUTPUT_DIR="$SCRIPT_DIR/cicd-output"
  mkdir -p "$OUTPUT_DIR/.github/workflows"

  # ── GitHub Actions workflow ────────────────────────────────
  write_section "Generating GitHub Actions Workflow"

  local SLACK_STEP=""
  if [[ -n "$SLACK_NOTIFY" ]]; then
    SLACK_STEP="
      - name: Notify Slack
        if: always()
        run: |
          STATUS=\${{ job.status }}
          curl -X POST -H 'Content-type: application/json' \\
            --data \"{\\\"text\\\":\\\"Moodle Deploy: \$STATUS on \$(date)\\\"}\" \\
            $SLACK_NOTIFY"
  fi

  cat > "$OUTPUT_DIR/.github/workflows/deploy.yml" <<YAML
# ============================================================
#  Moodle CI/CD Pipeline
#  Repo: ${REPO_NAME}
#  Deploys: ${DEPLOY_BRANCH} → ${SERVER_IP}
# ============================================================

name: Deploy Moodle

on:
  push:
    branches: [ "${DEPLOY_BRANCH}" ]
  workflow_dispatch:   # allows manual trigger from GitHub UI

jobs:
  # ── Job 1: Run tests ──────────────────────────────────────
  test:
    name: PHP Lint & Basic Checks
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.3'
          extensions: mbstring, curl, xml, zip, gd, intl, soap, redis

      - name: Check PHP syntax
        run: find . -name "*.php" -not -path "./vendor/*" | xargs -r php -l

      - name: Verify Moodle version file
        run: |
          if [ -f "version.php" ]; then
            echo "version.php found"
            php -r "require 'version.php'; echo 'Moodle version: ' . \\\$release . PHP_EOL;"
          fi

  # ── Job 2: Deploy to production ───────────────────────────
  deploy:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/${DEPLOY_BRANCH}'

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup SSH key
        run: |
          mkdir -p ~/.ssh
          echo "\${{ secrets.DEPLOY_SSH_KEY }}" > ~/.ssh/deploy_key
          chmod 600 ~/.ssh/deploy_key
          ssh-keyscan -H ${SERVER_IP} >> ~/.ssh/known_hosts 2>/dev/null

      - name: Run deploy script on server
        run: |
          ssh -i ~/.ssh/deploy_key -o StrictHostKeyChecking=no \\
            ${SERVER_USER}@${SERVER_IP} \\
            "bash ${MOODLE_DIR}/deploy.sh" 2>&1
${SLACK_STEP}

  # ── Job 3: Post-deploy health check ───────────────────────
  healthcheck:
    name: Health Check
    runs-on: ubuntu-latest
    needs: deploy

    steps:
      - name: Check site responds
        run: |
          sleep 10
          STATUS=\$(curl -s -o /dev/null -w "%{http_code}" "\${{ secrets.MOODLE_URL }}/login/index.php")
          echo "HTTP status: \$STATUS"
          if [ "\$STATUS" != "200" ]; then
            echo "Health check FAILED — site returned HTTP \$STATUS"
            exit 1
          fi
          echo "Health check PASSED"
YAML

  success "GitHub Actions workflow generated"

  # ── Server-side deploy.sh ─────────────────────────────────
  write_section "Generating Server Deploy Script"

  cat > "$OUTPUT_DIR/deploy.sh" <<DEPLOY
#!/usr/bin/env bash
# ============================================================
#  Moodle Server Deploy Script
#  Place this at: ${MOODLE_DIR}/deploy.sh
#  Run by GitHub Actions via SSH on every push to ${DEPLOY_BRANCH}
# ============================================================

set -euo pipefail

MOODLE_DIR="${MOODLE_DIR}"
MOODLE_DATA="${MOODLE_DATA}"
TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
LOG="/var/log/moodle-deploy.log"

log() { echo "[\$TIMESTAMP] \$*" | tee -a "\$LOG"; }

log "====== Deploy started ======"

# 1. Enable maintenance mode
log "Enabling maintenance mode..."
sudo -u www-data php "\$MOODLE_DIR/admin/cli/maintenance.php" --enable

# 2. Pull latest code
log "Pulling latest code from git..."
cd "\$MOODLE_DIR"
git fetch origin ${DEPLOY_BRANCH}
git reset --hard origin/${DEPLOY_BRANCH}

# 3. Fix permissions
log "Fixing permissions..."
chown -R www-data:www-data "\$MOODLE_DIR"
chmod -R 755 "\$MOODLE_DIR"
chown -R www-data:www-data "\$MOODLE_DATA"

# 4. Run Moodle upgrade
log "Running Moodle upgrade..."
sudo -u www-data php "\$MOODLE_DIR/admin/cli/upgrade.php" --non-interactive

# 5. Purge caches
log "Purging caches..."
sudo -u www-data php "\$MOODLE_DIR/admin/cli/purge_caches.php"

# 6. Disable maintenance mode
log "Disabling maintenance mode..."
sudo -u www-data php "\$MOODLE_DIR/admin/cli/maintenance.php" --disable

log "====== Deploy complete ======"
DEPLOY

  chmod +x "$OUTPUT_DIR/deploy.sh"
  success "deploy.sh generated"

  # ── SSH key setup instructions ────────────────────────────
  write_section "Generating SSH Key Setup Guide"

  cat > "$OUTPUT_DIR/SSH_SETUP.md" <<MD
# SSH Key Setup for CI/CD

## Step 1 — Generate a deploy SSH key (run this on your local machine)

\`\`\`bash
ssh-keygen -t ed25519 -C "moodle-deploy@github" -f ~/.ssh/moodle_deploy_key -N ""
\`\`\`

This creates two files:
- \`~/.ssh/moodle_deploy_key\` — private key (goes into GitHub)
- \`~/.ssh/moodle_deploy_key.pub\` — public key (goes onto server)

## Step 2 — Add public key to your server

\`\`\`bash
ssh-copy-id -i ~/.ssh/moodle_deploy_key.pub ${SERVER_USER}@${SERVER_IP}
\`\`\`

Or manually append it:
\`\`\`bash
cat ~/.ssh/moodle_deploy_key.pub >> ~/.ssh/authorized_keys
\`\`\`

## Step 3 — Add private key to GitHub Secrets

1. Go to your GitHub repo → Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Name: \`DEPLOY_SSH_KEY\`
4. Value: paste the contents of \`~/.ssh/moodle_deploy_key\`

\`\`\`bash
cat ~/.ssh/moodle_deploy_key
\`\`\`

## Step 4 — Add remaining secrets to GitHub

| Secret name   | Value                              |
|---------------|------------------------------------|
| DEPLOY_SSH_KEY | (private key from step 3)         |
| MOODLE_URL     | https://your-moodle-domain.com    |

## Step 5 — Place deploy.sh on your server

\`\`\`bash
scp deploy.sh ${SERVER_USER}@${SERVER_IP}:${MOODLE_DIR}/deploy.sh
ssh ${SERVER_USER}@${SERVER_IP} "chmod +x ${MOODLE_DIR}/deploy.sh"
\`\`\`

## Step 6 — Allow www-data to run php as sudoer (on server)

Add to /etc/sudoers.d/moodle-deploy:
\`\`\`
www-data ALL=(ALL) NOPASSWD: /usr/bin/php
\`\`\`

## Step 7 — Test the pipeline

Push any commit to \`${DEPLOY_BRANCH}\` and watch the GitHub Actions tab.
MD

  success "SSH setup guide generated"

  # ── Secrets checklist ─────────────────────────────────────
  write_section "Generating Secrets Checklist"

  cat > "$OUTPUT_DIR/SECRETS_CHECKLIST.md" <<MD
# GitHub Secrets Checklist

Add these in: GitHub Repo → Settings → Secrets and variables → Actions

| Secret              | Description                         | Status |
|---------------------|-------------------------------------|--------|
| DEPLOY_SSH_KEY      | SSH private key for server access   | [ ]    |
| MOODLE_URL          | Full URL of your Moodle site        | [ ]    |

## Optional
| Secret              | Description                         | Status |
|---------------------|-------------------------------------|--------|
| SLACK_WEBHOOK       | Slack webhook for deploy alerts     | [ ]    |
| DB_BACKUP_KEY       | Key for encrypted DB backups        | [ ]    |
MD

  success "Secrets checklist generated"

  # ── README ────────────────────────────────────────────────
  cat > "$OUTPUT_DIR/README.md" <<MD
# Moodle CI/CD Pipeline

Generated by MoodleDeploy on $(date)

## Files in this package

| File | Purpose |
|------|---------|
| \`.github/workflows/deploy.yml\` | GitHub Actions workflow |
| \`deploy.sh\` | Server-side deploy script |
| \`SSH_SETUP.md\` | Step-by-step SSH key setup |
| \`SECRETS_CHECKLIST.md\` | GitHub secrets to configure |

## How the pipeline works

\`\`\`
Developer pushes to ${DEPLOY_BRANCH}
         │
         ▼
  GitHub Actions runs
         │
    ┌────┴────┐
    │  test   │  PHP lint + version check
    └────┬────┘
         │ (passes)
    ┌────┴────┐
    │ deploy  │  SSH into server → runs deploy.sh
    └────┴────┘
         │
   ┌─────┴──────┐
   │ healthcheck │  Checks site returns HTTP 200
   └────────────┘
\`\`\`

## Deploy script flow (on server)

1. Enable maintenance mode
2. \`git pull\` latest code
3. Fix file permissions
4. Run \`php admin/cli/upgrade.php\`
5. Purge caches
6. Disable maintenance mode

## Manual deploy trigger

You can trigger a deploy manually from:
GitHub Repo → Actions → Deploy Moodle → Run workflow
MD

  success "README generated"

  # ── Summary ───────────────────────────────────────────────
  write_section "CI/CD Setup Complete"
  echo -e "  ${BOLD}Output files:${RESET} ${CYAN}$OUTPUT_DIR${RESET}"
  echo ""
  echo -e "  ${BOLD}Next steps:${RESET}"
  echo -e "  1. Read ${CYAN}$OUTPUT_DIR/SSH_SETUP.md${RESET}"
  echo -e "  2. Copy ${CYAN}.github/workflows/deploy.yml${RESET} into your repo"
  echo -e "  3. Copy ${CYAN}deploy.sh${RESET} to your server's Moodle directory"
  echo -e "  4. Add secrets per ${CYAN}SECRETS_CHECKLIST.md${RESET}"
  echo -e "  5. Push to ${BOLD}${DEPLOY_BRANCH}${RESET} and watch it deploy automatically"
  divider
  pause
  main_menu
}
