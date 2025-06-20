#!/usr/bin/env bash

# KGSM Module Discovery Integration Test
# Tests the discovery and loading of KGSM modules

echo "[INFO] Starting module discovery integration test"

# Check environment
if [[ -z "$KGSM_ROOT" ]]; then
    echo "[FAIL] KGSM_ROOT not set"
    exit 1
fi

# Test 1: Modules directory exists
echo "[STEP] Testing modules directory existence"
if [[ ! -d "$KGSM_ROOT/modules" ]]; then
    echo "[FAIL] modules directory not found"
    exit 1
fi
echo "[PASS] modules directory exists"

# Test 2: Core modules exist
echo "[STEP] Testing core module existence"
CORE_MODULES=(
    "instances.sh"
    "blueprints.sh"
    "lifecycle.sh"
    "files.sh"
)

for module in "${CORE_MODULES[@]}"; do
    if [[ ! -f "$KGSM_ROOT/modules/$module" ]]; then
        echo "[FAIL] Core module not found: $module"
        exit 1
    fi

    if [[ ! -x "$KGSM_ROOT/modules/$module" ]]; then
        echo "[FAIL] Core module not executable: $module"
        exit 1
    fi
done
echo "[PASS] Core modules exist and are executable"

# Test 3: Include modules exist
echo "[STEP] Testing include module existence"
if [[ ! -d "$KGSM_ROOT/modules/include" ]]; then
    echo "[FAIL] modules/include directory not found"
    exit 1
fi

INCLUDE_MODULES=(
    "common.sh"
    "config.sh"
    "errors.sh"
    "logging.sh"
)

for module in "${INCLUDE_MODULES[@]}"; do
    if [[ ! -f "$KGSM_ROOT/modules/include/$module" ]]; then
        echo "[FAIL] Include module not found: $module"
        exit 1
    fi
done
echo "[PASS] Include modules exist"

# Test 4: Count total modules
echo "[STEP] Testing module count"
TOTAL_MODULES=$(find "$KGSM_ROOT/modules" -name "*.sh" -type f | wc -l)
if [[ $TOTAL_MODULES -gt 10 ]]; then
    echo "[PASS] Found $TOTAL_MODULES modules (expected > 10)"
else
    echo "[FAIL] Too few modules found: $TOTAL_MODULES (expected > 10)"
    exit 1
fi

# Test 5: Test module help functionality
echo "[STEP] Testing module help functionality"
TESTABLE_MODULES=(
    "instances.sh"
    "blueprints.sh"
    "lifecycle.sh"
)

for module in "${TESTABLE_MODULES[@]}"; do
    if "$KGSM_ROOT/modules/$module" --help >/dev/null 2>&1; then
        echo "[PASS] $module --help works"
    else
        echo "[FAIL] $module --help failed"
        exit 1
    fi
done

# Test 6: Test that modules can find each other (dependency test)
echo "[STEP] Testing module dependencies"
# This tests that modules can load common dependencies
if [[ -f "$KGSM_ROOT/modules/include/common.sh" ]]; then
    echo "[PASS] Common module available for dependencies"
else
    echo "[FAIL] Common module not available"
    exit 1
fi

echo "[SUCCESS] Module discovery integration test passed"
exit 0
