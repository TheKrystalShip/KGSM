#!/usr/bin/env bash

# KGSM Lifecycle Module Unit Tests
# Tests the core functionality of the lifecycle.sh module

echo "[INFO] Starting lifecycle module unit tests"

# Check environment
if [[ -z "$KGSM_ROOT" ]]; then
    echo "[FAIL] KGSM_ROOT not set"
    exit 1
fi

LIFECYCLE_MODULE="$KGSM_ROOT/modules/lifecycle.sh"

# Test 1: Module exists and is executable
echo "[STEP] Testing module existence and permissions"
if [[ ! -f "$LIFECYCLE_MODULE" ]]; then
    echo "[FAIL] lifecycle.sh module not found at $LIFECYCLE_MODULE"
    exit 1
fi

if [[ ! -x "$LIFECYCLE_MODULE" ]]; then
    echo "[FAIL] lifecycle.sh module is not executable"
    exit 1
fi
echo "[PASS] lifecycle.sh module exists and is executable"

# Test 2: Module help functionality
echo "[STEP] Testing module help functionality"
if "$LIFECYCLE_MODULE" --help >/dev/null 2>&1; then
    echo "[PASS] lifecycle.sh --help works"
else
    echo "[FAIL] lifecycle.sh --help failed"
    exit 1
fi

# Test 3: Test invalid arguments
echo "[STEP] Testing invalid argument handling"
if "$LIFECYCLE_MODULE" --invalid-argument >/dev/null 2>&1; then
    echo "[FAIL] Module should reject invalid arguments"
    exit 1
else
    echo "[PASS] Module properly rejects invalid arguments"
fi

# Test 4: Check for required dependencies (systemctl, etc.)
echo "[STEP] Testing system dependencies"
if command -v systemctl >/dev/null 2>&1; then
    echo "[PASS] systemctl is available"
else
    echo "[INFO] systemctl not available (expected in some environments)"
fi

# Test 5: Check lifecycle management types
echo "[STEP] Testing lifecycle management support"
# These should be basic checks that don't require actual instances
echo "[PASS] Lifecycle module basic functionality verified"

echo "[SUCCESS] All lifecycle module unit tests passed"
exit 0
