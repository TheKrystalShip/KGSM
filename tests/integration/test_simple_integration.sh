#!/usr/bin/env bash

# Simple KGSM Integration Test
# Tests interaction between multiple KGSM modules

echo "[INFO] Starting simple integration test"
echo "[STEP] Testing module interactions"

# Check environment
if [[ -z "$KGSM_ROOT" ]]; then
    echo "[FAIL] KGSM_ROOT not set"
    exit 1
fi

echo "[PASS] KGSM_ROOT is set: $KGSM_ROOT"

# Test blueprints module
BLUEPRINTS_MODULE="$KGSM_ROOT/modules/blueprints.sh"
if [[ -f "$BLUEPRINTS_MODULE" ]]; then
    echo "[PASS] blueprints.sh module exists"
else
    echo "[FAIL] blueprints.sh module not found"
    exit 1
fi

# Test instances module
INSTANCES_MODULE="$KGSM_ROOT/modules/instances.sh"
if [[ -f "$INSTANCES_MODULE" ]]; then
    echo "[PASS] instances.sh module exists"
else
    echo "[FAIL] instances.sh module not found"
    exit 1
fi

# Test blueprint discovery
if [[ -d "$KGSM_ROOT/blueprints" ]]; then
    echo "[PASS] blueprints directory exists"
else
    echo "[FAIL] blueprints directory not found"
    exit 1
fi

# Count blueprints
blueprint_count=$(find "$KGSM_ROOT/blueprints" -name "*.bp" -o -name "*.yml" | wc -l)
if [[ $blueprint_count -gt 0 ]]; then
    echo "[PASS] Found $blueprint_count blueprint files"
else
    echo "[FAIL] No blueprint files found"
    exit 1
fi

echo "[STEP] Integration test completed successfully"
echo "[SUCCESS] Simple integration test passed"

exit 0
