#!/usr/bin/env bash
# Test script for Task 3.3 - Verify case_a_fresh.sh uses version-aware database installation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Testing Task 3.3 Implementation..."
echo "=================================="
echo ""

# Test 1: Verify compatibility check is called after pick_moodle_version
echo -n "Test 1: Checking for compatibility check after pick_moodle_version... "
if grep -A 3 "pick_moodle_version MOODLE_BRANCH" scripts/case_a_fresh.sh | grep -q "check_database_compatibility"; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    echo "  Expected: check_database_compatibility call after pick_moodle_version"
    exit 1
fi

# Test 2: Verify install_compatible_database is used instead of direct mariadb-server installation
echo -n "Test 2: Checking for install_compatible_database usage... "
if grep -q "install_compatible_database" scripts/case_a_fresh.sh; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    echo "  Expected: install_compatible_database function call"
    exit 1
fi

# Test 3: Verify direct mariadb-server installation is removed
echo -n "Test 3: Checking that direct mariadb-server installation is removed... "
if ! grep -q 'platform_install_package mariadb-server' scripts/case_a_fresh.sh; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    echo "  Expected: No direct platform_install_package mariadb-server call"
    exit 1
fi

# Test 4: Verify verify_database_version is called after database installation
echo -n "Test 4: Checking for verify_database_version call... "
if grep -q "verify_database_version" scripts/case_a_fresh.sh; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    echo "  Expected: verify_database_version function call"
    exit 1
fi

# Test 5: Verify the order of operations is correct
echo -n "Test 5: Checking order of operations... "
line_install=$(grep -n "install_compatible_database" scripts/case_a_fresh.sh | cut -d: -f1)
line_verify=$(grep -n "verify_database_version" scripts/case_a_fresh.sh | cut -d: -f1)

if [ "$line_install" -lt "$line_verify" ]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    echo "  Expected: install_compatible_database before verify_database_version"
    exit 1
fi

# Test 6: Verify all other installation steps are preserved
echo -n "Test 6: Checking preservation of other installation steps... "
preserved_steps=0
if grep -q "platform_install_package apache2" scripts/case_a_fresh.sh; then
    preserved_steps=$((preserved_steps + 1))
fi
if grep -q "platform_install_package redis-server" scripts/case_a_fresh.sh; then
    preserved_steps=$((preserved_steps + 1))
fi
if grep -q "platform_install_package php8.3" scripts/case_a_fresh.sh; then
    preserved_steps=$((preserved_steps + 1))
fi
if grep -q "platform_install_package git" scripts/case_a_fresh.sh; then
    preserved_steps=$((preserved_steps + 1))
fi

if [ "$preserved_steps" -eq 4 ]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    echo "  Expected: All other installation steps preserved (found $preserved_steps/4)"
    exit 1
fi

# Test 7: Verify bash syntax is valid
echo -n "Test 7: Checking bash syntax... "
if bash -n scripts/case_a_fresh.sh 2>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    echo "  Expected: Valid bash syntax"
    exit 1
fi

echo ""
echo "=================================="
echo -e "${GREEN}All tests passed!${NC}"
echo ""
echo "Summary of changes:"
echo "  1. Added check_database_compatibility after pick_moodle_version"
echo "  2. Replaced direct mariadb-server installation with install_compatible_database"
echo "  3. Added verify_database_version after database installation"
echo "  4. Preserved all other installation steps (Apache, PHP, Redis, Git, etc.)"
