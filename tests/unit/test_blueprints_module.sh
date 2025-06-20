#!/usr/bin/env bash

# KGSM Blueprints Module Unit Tests
# Tests the core functionality of the blueprints.sh module

echo "[INFO] Starting blueprints module unit tests"

# Check environment
if [[ -z "$KGSM_ROOT" ]]; then
    echo "[FAIL] KGSM_ROOT not set"
    exit 1
fi

BLUEPRINTS_MODULE="$KGSM_ROOT/modules/blueprints.sh"

# Test 1: Module exists and is executable
echo "[STEP] Testing module existence and permissions"
if [[ ! -f "$BLUEPRINTS_MODULE" ]]; then
    echo "[FAIL] blueprints.sh module not found at $BLUEPRINTS_MODULE"
    exit 1
fi

if [[ ! -x "$BLUEPRINTS_MODULE" ]]; then
    echo "[FAIL] blueprints.sh module is not executable"
    exit 1
fi
echo "[PASS] blueprints.sh module exists and is executable"

# Test 2: Module help functionality
echo "[STEP] Testing module help functionality"
if "$BLUEPRINTS_MODULE" --help >/dev/null 2>&1; then
    echo "[PASS] blueprints.sh --help works"
else
    echo "[FAIL] blueprints.sh --help failed"
    exit 1
fi

# Test 3: List blueprints functionality
echo "[STEP] Testing blueprint listing functionality"
if "$BLUEPRINTS_MODULE" --list >/dev/null 2>&1; then
    echo "[PASS] blueprints.sh --list works"
else
    echo "[FAIL] blueprints.sh --list failed"
    exit 1
fi

# Test 4: List blueprints with JSON output
echo "[STEP] Testing blueprint JSON listing functionality"
if "$BLUEPRINTS_MODULE" --list --json >/dev/null 2>&1; then
    echo "[PASS] blueprints.sh --list --json works"
else
    echo "[FAIL] blueprints.sh --list --json failed"
    exit 1
fi

# Test 5: Check if blueprint directories exist
echo "[STEP] Testing blueprint directory structure"
if [[ -d "$KGSM_ROOT/blueprints" ]]; then
    echo "[PASS] blueprints directory exists"
else
    echo "[FAIL] blueprints directory not found"
    exit 1
fi

if [[ -d "$KGSM_ROOT/blueprints/default" ]]; then
    echo "[PASS] default blueprints directory exists"
else
    echo "[FAIL] default blueprints directory not found"
    exit 1
fi

# Test 6: Count available blueprints
echo "[STEP] Testing blueprint availability"
NATIVE_BLUEPRINTS=$(find "$KGSM_ROOT/blueprints" -name "*.bp" 2>/dev/null | wc -l)
CONTAINER_BLUEPRINTS=$(find "$KGSM_ROOT/blueprints" -name "*.docker-compose.yml" -o -name "*.yml" 2>/dev/null | wc -l)
TOTAL_BLUEPRINTS=$((NATIVE_BLUEPRINTS + CONTAINER_BLUEPRINTS))

if [[ $TOTAL_BLUEPRINTS -gt 0 ]]; then
    echo "[PASS] Found $TOTAL_BLUEPRINTS blueprints ($NATIVE_BLUEPRINTS native, $CONTAINER_BLUEPRINTS container)"
else
    echo "[FAIL] No blueprints found"
    exit 1
fi

# Test 7: Test specific blueprint existence (factorio should exist)
echo "[STEP] Testing specific blueprint existence"
if [[ -f "$KGSM_ROOT/blueprints/default/native/factorio.bp" ]]; then
    echo "[PASS] factorio.bp blueprint exists"
else
    echo "[SKIP] factorio.bp blueprint not found (expected in default installation)"
fi

# Test 8: Test invalid arguments
echo "[STEP] Testing invalid argument handling"
if "$BLUEPRINTS_MODULE" --invalid-argument >/dev/null 2>&1; then
    echo "[FAIL] Module should reject invalid arguments"
    exit 1
else
    echo "[PASS] Module properly rejects invalid arguments"
fi

echo "[SUCCESS] All blueprints module unit tests passed"
exit 0
