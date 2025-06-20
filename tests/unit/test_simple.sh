#!/usr/bin/env bash

# Simple KGSM Test - Unit Test Example
# This test demonstrates the framework working without complex assertions

echo "[INFO] Starting simple unit test"
echo "[STEP] Testing basic KGSM functionality"

# Check if KGSM_ROOT is set
if [[ -z "$KGSM_ROOT" ]]; then
    echo "[FAIL] KGSM_ROOT not set"
    exit 1
fi

echo "[PASS] KGSM_ROOT is set: $KGSM_ROOT"

# Check if kgsm.sh exists
if [[ -f "$KGSM_ROOT/kgsm.sh" ]]; then
    echo "[PASS] kgsm.sh exists"
else
    echo "[FAIL] kgsm.sh not found"
    exit 1
fi

# Check if instances module exists
INSTANCES_MODULE="$KGSM_ROOT/modules/instances.sh"
if [[ -f "$INSTANCES_MODULE" ]]; then
    echo "[PASS] instances.sh module exists"
else
    echo "[FAIL] instances.sh module not found"
    exit 1
fi

# Test module help
if "$INSTANCES_MODULE" --help >/dev/null 2>&1; then
    echo "[PASS] instances.sh help works"
else
    echo "[FAIL] instances.sh help failed"
    exit 1
fi

# Test module list command
if "$INSTANCES_MODULE" --list >/dev/null 2>&1; then
    echo "[PASS] instances.sh list works"
else
    echo "[FAIL] instances.sh list failed"
    exit 1
fi

echo "[STEP] All tests passed successfully"
echo "[SUCCESS] Simple unit test completed"

exit 0
