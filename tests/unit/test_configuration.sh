#!/usr/bin/env bash

# KGSM Configuration Unit Tests
# Tests the configuration file handling and validation

echo "[INFO] Starting configuration unit tests"

# Check environment
if [[ -z "$KGSM_ROOT" ]]; then
    echo "[FAIL] KGSM_ROOT not set"
    exit 1
fi

# Test 1: Configuration files exist
echo "[STEP] Testing configuration file existence"
if [[ ! -f "$KGSM_ROOT/config.default.ini" ]]; then
    echo "[FAIL] config.default.ini not found"
    exit 1
fi

if [[ ! -f "$KGSM_ROOT/config.ini" ]]; then
    echo "[FAIL] config.ini not found"
    exit 1
fi
echo "[PASS] Configuration files exist"

# Test 2: Configuration files are readable
echo "[STEP] Testing configuration file readability"
if [[ ! -r "$KGSM_ROOT/config.default.ini" ]]; then
    echo "[FAIL] config.default.ini is not readable"
    exit 1
fi

if [[ ! -r "$KGSM_ROOT/config.ini" ]]; then
    echo "[FAIL] config.ini is not readable"
    exit 1
fi
echo "[PASS] Configuration files are readable"

# Test 3: Configuration files contain expected sections
echo "[STEP] Testing configuration file structure"
if ! grep -q "enable_logging" "$KGSM_ROOT/config.ini"; then
    echo "[FAIL] config.ini missing expected configuration options"
    exit 1
fi

if ! grep -q "default_install_directory" "$KGSM_ROOT/config.ini"; then
    echo "[FAIL] config.ini missing default_install_directory"
    exit 1
fi
echo "[PASS] Configuration files contain expected sections"

# Test 4: Test environment overrides are applied
echo "[STEP] Testing test environment overrides"
if grep -q "TEST ENVIRONMENT OVERRIDES" "$KGSM_ROOT/config.ini"; then
    echo "[PASS] Test environment overrides are applied"
else
    echo "[FAIL] Test environment overrides not found"
    exit 1
fi

# Test 5: Test that systemd is disabled in test environment
echo "[STEP] Testing systemd disabled in test environment"
if grep -q "enable_systemd=false" "$KGSM_ROOT/config.ini"; then
    echo "[PASS] systemd is disabled in test environment"
else
    echo "[FAIL] systemd not properly disabled in test environment"
    exit 1
fi

# Test 6: Test that firewall management is disabled
echo "[STEP] Testing firewall management disabled in test environment"
if grep -q "enable_firewall_management=false" "$KGSM_ROOT/config.ini"; then
    echo "[PASS] firewall management is disabled in test environment"
else
    echo "[FAIL] firewall management not properly disabled in test environment"
    exit 1
fi

# Test 7: Test configuration parsing (basic syntax check)
echo "[STEP] Testing configuration syntax"
# Check for basic ini file syntax - no obvious syntax errors
if grep -E "^[a-zA-Z_][a-zA-Z0-9_]*=" "$KGSM_ROOT/config.ini" >/dev/null; then
    echo "[PASS] Configuration syntax appears valid"
else
    echo "[FAIL] Configuration syntax issues detected"
    exit 1
fi

echo "[SUCCESS] All configuration unit tests passed"
exit 0
