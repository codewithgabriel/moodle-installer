# MoodleDeploy 🎓

**Interactive Moodle 4.5 Installer + CI/CD Pipeline Generator**

Automated, interactive installer for Moodle 4.5 on Linux — covering fresh servers, existing servers, and cPanel hosting — with a built-in CI/CD pipeline generator for GitHub Actions.

---

## Quick Start

```bash
# Extract the zip, then:
cd moodle-installer
chmod +x install.sh
sudo ./install.sh
```

---

## What it does

| Scenario | Description |
|----------|-------------|
| **Case A** | Fresh Linux VPS — installs everything from scratch (Apache, PHP 8.3, MariaDB, Redis, Moodle) |
| **Case B** | Existing Linux server — detects what's already installed, fills in the gaps |
| **Case C** | cPanel / Shared hosting — interactive step-by-step guide, generates config.php |
| **Case D** | CI/CD only — generates GitHub Actions workflow + server deploy script |

---

## Requirements

| Case | Requirement |
|------|-------------|
| A & B | Ubuntu 20.04+ or Debian 11+ with root/sudo |
| C | Any Linux with bash (runs guidance only — no root needed) |
| D | Any Linux with bash (generates files only) |

---

## File Structure

```
moodle-installer/
├── install.sh              ← Main entry point
├── lib/
│   ├── colors.sh           ← ANSI color constants
│   ├── utils.sh            ← Shared helpers (prompts, spinners, etc.)
│   └── checks.sh           ← Pre-flight system checks
└── scripts/
    ├── case_a_fresh.sh     ← Fresh Linux install
    ├── case_b_existing.sh  ← Existing server install
    ├── case_c_cpanel.sh    ← cPanel guided install
    └── cicd_setup.sh       ← GitHub Actions CI/CD generator
```

---

## CI/CD Pipeline Flow

```
Push to main
     │
     ▼
GitHub Actions
     │
  [test] → PHP lint + version check
     │
  [deploy] → SSH → maintenance mode → git pull → upgrade → purge cache → back online
     │
  [healthcheck] → HTTP 200 check
```

---

## After Installation

- Credentials saved to `credentials.txt` — keep secure, delete after use
- Cron runs every minute via `www-data` crontab
- Redis session handling configured by default
- Log file at `moodle-install.log`

---

## Notes

- Moodle version: **4.5 (MOODLE_405_STABLE)**
- Database driver: **MariaDB native** (Cases A & B) / **mysqli** (Case C cPanel)
- PHP target: **8.3**
- Web server: **Apache2** (default) or **Nginx** (auto-detected in Case B)
# moodle-installer
