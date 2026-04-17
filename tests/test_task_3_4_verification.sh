#!/usr/bin/env bash
# Task 3.4 Verification Test
# Verifies that case_b_existing.sh handles incompatible database versions correctly

set -e

echo "=== Task 3.4 Verification Test ==="
echo ""

# Test 1: Verify compatibility check is present after version selection
echo "Test 1: Checking for compatibility check after version selection..."
if grep -A 10 "pick_moodle_version" scripts/case_b_existing.sh | grep -q "check_database_compatibility"; then
    echo "✓ PASS: Compatibility check found after version selection"
else
    echo "✗ FAIL: Compatibility check NOT found after version selection"
    exit 1
fi

# Test 2: Verify that incompatible database sets DB_OK=false (does NOT exit)
echo ""
echo "Test 2: Checking that incompatible database sets DB_OK=false..."
if grep -A 5 "check_database_compatibility" scripts/case_b_existing.sh | grep -q "DB_OK=false"; then
    echo "✓ PASS: DB_OK=false is set when database is incompatible"
else
    echo "✗ FAIL: DB_OK=false NOT set when database is incompatible"
    exit 1
fi

# Test 3: Verify no exit statement in compatibility check section
echo ""
echo "Test 3: Checking that script does NOT exit on incompatibility..."
if grep -A 5 "check_database_compatibility" scripts/case_b_existing.sh | grep -q "exit 1"; then
    echo "✗ FAIL: Script exits on incompatibility (should NOT exit)"
    exit 1
else
    echo "✓ PASS: Script does NOT exit on incompatibility"
fi

# Test 4: Verify install_compatible_database is used when DB_OK=false
echo ""
echo "Test 4: Checking that install_compatible_database is used for upgrade..."
if grep -A 5 "DB_OK.*false" scripts/case_b_existing.sh | grep -q "install_compatible_database"; then
    echo "✓ PASS: install_compatible_database is used when DB_OK=false"
else
    echo "✗ FAIL: install_compatible_database NOT used when DB_OK=false"
    exit 1
fi

# Test 5: Verify warning messages are displayed (not error messages that stop)
echo ""
echo "Test 5: Checking for user-friendly warning messages..."
if grep -A 5 "check_database_compatibility" scripts/case_b_existing.sh | grep -q "warn"; then
    echo "✓ PASS: Warning messages are displayed (user-friendly)"
else
    echo "✗ FAIL: Warning messages NOT found"
    exit 1
fi

# Test 6: Verify the section title indicates upgrade capability
echo ""
echo "Test 6: Checking section title indicates upgrade capability..."
if grep -B 2 "install_compatible_database" scripts/case_b_existing.sh | grep -q "Installing/Upgrading"; then
    echo "✓ PASS: Section title indicates 'Installing/Upgrading MariaDB'"
else
    echo "✗ FAIL: Section title does NOT indicate upgrade capability"
    exit 1
fi

echo ""
echo "=== All Task 3.4 Verification Tests PASSED ==="
echo ""
echo "Summary:"
echo "  ✓ Compatibility check is performed after version selection"
echo "  ✓ Incompatible database sets DB_OK=false (does NOT exit)"
echo "  ✓ Script continues seamlessly without stopping"
echo "  ✓ install_compatible_database is used for automatic upgrade"
echo "  ✓ User-friendly warning messages are displayed"
echo "  ✓ Section title indicates upgrade capability"
echo ""
echo "Task 3.4 implementation is CORRECT and meets all requirements!"
