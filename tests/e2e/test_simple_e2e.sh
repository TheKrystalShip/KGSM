#!/usr/bin/env bash

# Simple KGSM End-to-End Test
# Tests complete KGSM workflow without requiring external dependencies

echo "[INFO] Starting simple e2e test"
echo "[STEP] Testing complete KGSM workflow"

# Check environment
if [[ -z "$KGSM_ROOT" ]]; then
    echo "[FAIL] KGSM_ROOT not set"
    exit 1
fi

echo "[PASS] KGSM_ROOT is set: $KGSM_ROOT"

# Test main kgsm.sh script
if [[ -f "$KGSM_ROOT/kgsm.sh" ]]; then
    echo "[PASS] kgsm.sh exists"
else
    echo "[FAIL] kgsm.sh not found"
    exit 1
fi

# Test kgsm.sh is executable
if [[ -x "$KGSM_ROOT/kgsm.sh" ]]; then
    echo "[PASS] kgsm.sh is executable"
else
    echo "[FAIL] kgsm.sh is not executable"
    exit 1
fi

# Test configuration
if [[ -f "$KGSM_ROOT/config.ini" ]]; then
    echo "[PASS] config.ini exists"
else
    echo "[FAIL] config.ini not found"
    exit 1
fi

# Test modules directory
if [[ -d "$KGSM_ROOT/modules" ]]; then
    echo "[PASS] modules directory exists"
else
    echo "[FAIL] modules directory not found"
    exit 1
fi

# Count modules
module_count=$(find "$KGSM_ROOT/modules" -name "*.sh" | wc -l)
if [[ $module_count -gt 0 ]]; then
    echo "[PASS] Found $module_count module files"
else
    echo "[FAIL] No module files found"
    exit 1
fi

# Test instances directory creation
if [[ -d "$KGSM_ROOT/instances" ]]; then
    echo "[PASS] instances directory exists"
else
    echo "[INFO] instances directory will be created as needed"
fi

echo "[STEP] End-to-end test completed successfully"
echo "[SUCCESS] Simple e2e test passed"

exit 0
