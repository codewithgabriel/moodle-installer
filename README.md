# MoodleDeploy 🎓

**Cross-Platform Moodle Installer (4.1-5.1) + CI/CD Pipeline Generator**

Automated, interactive installer for Moodle versions 4.1 through 5.1 on **Linux and Windows** — covering fresh servers, existing servers, cPanel hosting, and upgrades — with a built-in CI/CD pipeline generator for GitHub Actions.

---

## ✨ New Features

- **🆕 Moodle 5.1 Support** — Install the latest Moodle version with PHP 8.1+ requirements
- **🪟 Windows Compatibility** — Run on Windows 10/11 using Git Bash, MSYS2, or WSL
- **⬆️ Upgrade Path** — Seamlessly upgrade from Moodle 4.x to 5.1 with automatic dependency management
- **🔧 Version-Specific Configuration** — Automatic PHP and database requirement detection per Moodle version

---

## Quick Start

### Linux
```bash
cd moodle-installer
chmod +x install.sh
sudo ./install.sh
```

### Windows
```bash
# Run in Git Bash or MSYS2 as Administrator
cd moodle-installer
./install.sh
```

---

## What it does

| Scenario | Description | Platforms |
|----------|-------------|-----------|
| **Case A** | Fresh server — installs everything from scratch (Apache, PHP, MariaDB, Redis, Moodle) | Linux, Windows |
| **Case B** | Existing server — detects what's already installed, fills in the gaps | Linux, Windows |
| **Case C** | cPanel / Shared hosting — interactive step-by-step guide, generates config.php | Linux only |
| **Case D** | CI/CD only — generates GitHub Actions workflow + server deploy script | Linux, Windows |

---

## Supported Moodle Versions

| Version | PHP Requirement | Database Requirement | Status |
|---------|----------------|---------------------|--------|
| **5.1** | PHP 8.1+ | MariaDB 10.6.7+ / MySQL 8.0.30+ | ✅ Latest |
| **4.5** | PHP 8.1+ | MariaDB 10.6.7+ / MySQL 8.0.30+ | ✅ LTS |
| **4.4** | PHP 8.1+ | MariaDB 10.6.7+ / MySQL 8.0.30+ | ✅ Supported |
| **4.3** | PHP 8.0+ | MariaDB 10.5.0+ / MySQL 8.0.0+ | ✅ Supported |
| **4.2** | PHP 8.0+ | MariaDB 10.5.0+ / MySQL 8.0.0+ | ✅ Supported |
| **4.1** | PHP 7.4+ | MariaDB 10.4.0+ / MySQL 5.7.0+ | ✅ LTS |

---

## System Requirements

### Linux
- **OS**: Ubuntu 20.04+, Debian 11+, or compatible distribution
- **Access**: Root or sudo privileges (Cases A & B)
- **Shell**: Bash 4.0+

### Windows
- **OS**: Windows 10 or Windows 11
- **Shell**: Git Bash, MSYS2, or Windows Subsystem for Linux (WSL)
- **Package Manager**: Chocolatey (will prompt for installation if missing)
- **Access**: Administrator privileges

---

## Upgrade Feature

### Supported Upgrade Paths

| From Version | Can Upgrade To |
|--------------|----------------|
| 4.1 | 4.2, 4.3, 4.4, 4.5, 5.1 |
| 4.2 | 4.3, 4.4, 4.5, 5.1 |
| 4.3 | 4.4, 4.5, 5.1 |
| 4.4 | 4.5, 5.1 |
| 4.5 | 5.1 |

### Upgrade Process

When you run the installer on a system with an existing Moodle installation:

1. **Detection** — Automatically detects your current Moodle version
2. **Validation** — Checks if the upgrade path is supported
3. **Dependency Check** — Verifies PHP, database, and extension requirements
4. **Automatic Upgrade** — Offers to upgrade system dependencies if needed
5. **Moodle Upgrade** — Performs git checkout and runs database upgrade
6. **Verification** — Confirms successful upgrade

**Example Upgrade Scenario:**
```bash
# You have Moodle 4.5 with PHP 8.1
sudo ./install.sh

# Installer detects Moodle 4.5
# You select Moodle 5.1
# Installer validates upgrade path (4.5 → 5.1 ✓)
# Checks dependencies (PHP 8.1 ✓, MariaDB 10.6.7 ✓)
# Performs upgrade automatically
# Your data, config, and database are preserved
```

---

## Platform-Specific Installation

### Linux Installation

**Prerequisites:**
- Ubuntu 20.04+ or Debian 11+
- Root or sudo access
- Internet connection

**Installation:**
```bash
cd moodle-installer
chmod +x install.sh
sudo ./install.sh
```

**Package Management:**
- Uses `apt` for package installation
- Uses `systemctl` for service management
- Installs from `ondrej/php` PPA for PHP 8.x

### Windows Installation

**Prerequisites:**
- Windows 10 or Windows 11
- Git Bash, MSYS2, or WSL
- Administrator privileges
- [Chocolatey](https://chocolatey.org/install) package manager

**Installing Chocolatey:**
```powershell
# Run in PowerShell as Administrator
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

**Installation:**
```bash
# Run in Git Bash as Administrator
cd moodle-installer
./install.sh
```

**Package Management:**
- Uses Chocolatey for package installation
- Uses PowerShell for service management
- Installs Apache, PHP, MariaDB, Redis via Chocolatey

**Windows-Specific Notes:**
- cPanel option (Case C) is not available on Windows
- File paths use Windows conventions (backslashes)
- Services are managed via Windows Service Manager
- NTFS permissions are automatically configured

---

## Features Comparison

| Feature | Linux | Windows |
|---------|-------|---------|
| Fresh Installation (Case A) | ✅ | ✅ |
| Existing Server (Case B) | ✅ | ✅ |
| cPanel Hosting (Case C) | ✅ | ❌ |
| CI/CD Setup (Case D) | ✅ | ✅ |
| Moodle 4.1-5.1 Support | ✅ | ✅ |
| Upgrade from 4.x to 5.1 | ✅ | ✅ |
| Apache Web Server | ✅ | ✅ |
| Nginx Web Server | ✅ | ❌ |
| Automatic Dependency Upgrade | ✅ | ⚠️ Manual |
| Let's Encrypt SSL | ✅ | ❌ |
| Self-Signed SSL | ✅ | ✅ |

---

## File Structure

```
moodle-installer/
├── install.sh                    ← Main entry point
├── lib/
│   ├── colors.sh                 ← ANSI color constants
│   ├── platform.sh               ← Platform detection (Linux/Windows/WSL)
│   ├── platform_abstraction.sh   ← Platform-agnostic interfaces
│   ├── platform_linux.sh         ← Linux-specific implementations
│   ├── platform_windows.sh       ← Windows-specific implementations
│   ├── version_config.sh         ← Version-specific requirements (4.1-5.1)
│   ├── upgrade_manager.sh        ← Upgrade path validation and execution
│   ├── utils.sh                  ← Shared helpers (prompts, spinners, etc.)
│   └── checks.sh                 ← Pre-flight system checks
└── scripts/
    ├── case_a_fresh.sh           ← Fresh server install
    ├── case_b_existing.sh        ← Existing server install
    ├── case_c_cpanel.sh          ← cPanel guided install (Linux only)
    └── cicd_setup.sh             ← GitHub Actions CI/CD generator
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

- **Credentials** saved to `moodle-credentials.txt` — keep secure, delete after use
- **Cron** runs every minute (Linux: via `www-data` crontab, Windows: Task Scheduler)
- **Redis** session handling configured by default
- **Log file** at `moodle-install.log`
- **Backup** of config.php created during upgrades with timestamp

---

## Troubleshooting

### Linux

**Issue: "Permission denied" errors**
```bash
# Ensure you're running with sudo
sudo ./install.sh
```

**Issue: PHP version too old**
```bash
# The installer will automatically add ondrej/php PPA
# and install the required PHP version
```

**Issue: Port 80/443 already in use**
```bash
# Check what's using the port
sudo netstat -tlnp | grep :80
# Stop the conflicting service
sudo systemctl stop <service-name>
```

### Windows

**Issue: "Chocolatey is not installed"**
```powershell
# Install Chocolatey first (see Windows Installation section above)
# Then run the installer again
```

**Issue: "Access denied" errors**
```bash
# Ensure you're running Git Bash as Administrator
# Right-click Git Bash → "Run as administrator"
```

**Issue: Services won't start**
```powershell
# Check Windows Services
services.msc
# Look for Apache2.4, MySQL (MariaDB), Redis
# Start them manually if needed
```

**Issue: cPanel option shows error on Windows**
```
# This is expected - cPanel is Linux-only
# Use Option A (Fresh) or B (Existing) instead
```

### Common Issues (All Platforms)

**Issue: Git clone fails**
```bash
# Check internet connection
ping github.com

# Try with increased buffer
git config --global http.postBuffer 524288000
```

**Issue: Database connection fails**
```bash
# Verify database is running
# Linux: sudo systemctl status mariadb
# Windows: Check services.msc for MySQL service

# Test connection manually
mysql -u root -p
```

**Issue: Moodle shows "Error reading from database"**
```bash
# Check config.php has correct database credentials
# Verify database user has ALL PRIVILEGES
# Ensure database collation is utf8mb4_unicode_ci
```

---

## Version-Specific Notes

### Moodle 5.1
- **New Requirements**: PHP 8.1+, sodium extension
- **Performance**: Enhanced OPcache settings (256MB vs 128MB)
- **Breaking Changes**: Some deprecated features from 4.x removed
- **Upgrade**: Automatic dependency upgrade from 4.x versions

### Moodle 4.5 (LTS)
- **Long Term Support**: Recommended for production
- **Requirements**: PHP 8.1+, MariaDB 10.6.7+
- **Stability**: Most stable release in 4.x series

### Moodle 4.1 (LTS)
- **Legacy Support**: PHP 7.4+ still supported
- **Compatibility**: Works with older systems
- **Upgrade Path**: Can upgrade directly to 5.1

---

## Contributing

Contributions welcome! Please ensure:
- Cross-platform compatibility (test on Linux and Windows)
- Version-specific configuration updates in `lib/version_config.sh`
- Platform abstraction for new features
- Documentation updates for new capabilities

---

## License

MIT License - see LICENSE file for details

---

## Support

- **Issues**: Report bugs via GitHub Issues
- **Documentation**: [Moodle Official Docs](https://docs.moodle.org)
- **Community**: [Moodle Forums](https://moodle.org/forums)

---

**Made with ❤️ for the Moodle community**
