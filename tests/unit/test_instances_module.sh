#!/usr/bin/env bash

# KGSM Instances Module Unit Tests
# Tests the core functionality of the instances.sh module

echo "[INFO] Starting instances module unit tests"

# Check environment
if [[ -z "$KGSM_ROOT" ]]; then
    echo "[FAIL] KGSM_ROOT not set"
    exit 1
fi

INSTANCES_MODULE="$KGSM_ROOT/modules/instances.sh"

# Test 1: Module exists and is executable
echo "[STEP] Testing module existence and permissions"
if [[ ! -f "$INSTANCES_MODULE" ]]; then
    echo "[FAIL] instances.sh module not found at $INSTANCES_MODULE"
    exit 1
fi

if [[ ! -x "$INSTANCES_MODULE" ]]; then
    echo "[FAIL] instances.sh module is not executable"
    exit 1
fi
echo "[PASS] instances.sh module exists and is executable"

# Test 2: Module help functionality
echo "[STEP] Testing module help functionality"
if "$INSTANCES_MODULE" --help >/dev/null 2>&1; then
    echo "[PASS] instances.sh --help works"
else
    echo "[FAIL] instances.sh --help failed"
    exit 1
fi

# Test 3: Module list functionality (should work even with no instances)
echo "[STEP] Testing module list functionality"
if "$INSTANCES_MODULE" --list >/dev/null 2>&1; then
    echo "[PASS] instances.sh --list works"
else
    echo "[FAIL] instances.sh --list failed"
    exit 1
fi

# Test 4: Module list with JSON output
echo "[STEP] Testing module JSON list functionality"
if "$INSTANCES_MODULE" --list --json >/dev/null 2>&1; then
    echo "[PASS] instances.sh --list --json works"
else
    echo "[FAIL] instances.sh --list --json failed"
    exit 1
fi

# Test 5: Generate unique instance ID
echo "[STEP] Testing instance ID generation"
# First, ensure we have a blueprint to test with
if [[ -f "$KGSM_ROOT/blueprints/default/native/factorio.bp" ]]; then
    INSTANCE_ID=$("$INSTANCES_MODULE" --generate-id factorio.bp 2>/dev/null)
    if [[ -n "$INSTANCE_ID" ]]; then
        echo "[PASS] Generated instance ID: $INSTANCE_ID"
    else
        echo "[FAIL] Failed to generate instance ID"
        exit 1
    fi
else
    echo "[SKIP] No factorio.bp found, skipping ID generation test"
fi

# Test 6: Test invalid arguments
echo "[STEP] Testing invalid argument handling"
if "$INSTANCES_MODULE" --invalid-argument >/dev/null 2>&1; then
    echo "[FAIL] Module should reject invalid arguments"
    exit 1
else
    echo "[PASS] Module properly rejects invalid arguments"
fi

# Test 7: Test missing required arguments
echo "[STEP] Testing missing argument handling"
if "$INSTANCES_MODULE" --create >/dev/null 2>&1; then
    echo "[FAIL] Module should require arguments for --create"
    exit 1
else
    echo "[PASS] Module properly requires arguments for --create"
fi

# Test 8: Test find functionality with non-existent instance
echo "[STEP] Testing find functionality with non-existent instance"
if "$INSTANCES_MODULE" --find non-existent-instance >/dev/null 2>&1; then
    echo "[FAIL] Module should fail when finding non-existent instance"
    exit 1
else
    echo "[PASS] Module properly fails when instance doesn't exist"
fi

echo "[SUCCESS] All instances module unit tests passed"
exit 0
