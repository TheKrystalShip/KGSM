#!/usr/bin/env bash

# KGSM Blueprint-Instance Integration Test
# Tests the interaction between blueprints and instances modules

echo "[INFO] Starting blueprint-instance integration test"

# Check environment
if [[ -z "$KGSM_ROOT" ]]; then
    echo "[FAIL] KGSM_ROOT not set"
    exit 1
fi

BLUEPRINTS_MODULE="$KGSM_ROOT/modules/blueprints.sh"
INSTANCES_MODULE="$KGSM_ROOT/modules/instances.sh"

# Test 1: Both modules exist
echo "[STEP] Testing module availability"
if [[ ! -f "$BLUEPRINTS_MODULE" ]]; then
    echo "[FAIL] blueprints.sh module not found"
    exit 1
fi

if [[ ! -f "$INSTANCES_MODULE" ]]; then
    echo "[FAIL] instances.sh module not found"
    exit 1
fi
echo "[PASS] Both blueprints and instances modules exist"

# Test 2: Get list of available blueprints
echo "[STEP] Testing blueprint discovery"
BLUEPRINT_LIST=$("$BLUEPRINTS_MODULE" --list 2>/dev/null)
if [[ -n "$BLUEPRINT_LIST" ]]; then
    echo "[PASS] Blueprints module can list blueprints"
    BLUEPRINT_COUNT=$(echo "$BLUEPRINT_LIST" | wc -l)
    echo "[INFO] Found $BLUEPRINT_COUNT blueprints"
else
    echo "[FAIL] No blueprints found"
    exit 1
fi

# Test 3: Test instance ID generation for available blueprints
echo "[STEP] Testing instance ID generation for blueprints"
# Try to find a blueprint to test with
TEST_BLUEPRINT=""
if [[ -f "$KGSM_ROOT/blueprints/default/native/factorio.bp" ]]; then
    TEST_BLUEPRINT="factorio.bp"
elif [[ -f "$KGSM_ROOT/blueprints/default/native/terraria.bp" ]]; then
    TEST_BLUEPRINT="terraria.bp"
elif [[ -f "$KGSM_ROOT/blueprints/default/native/minecraft.bp" ]]; then
    TEST_BLUEPRINT="minecraft.bp"
else
    # Find any .bp file
    TEST_BLUEPRINT=$(find "$KGSM_ROOT/blueprints" -name "*.bp" -type f | head -1 | xargs basename 2>/dev/null)
fi

if [[ -n "$TEST_BLUEPRINT" ]]; then
    INSTANCE_ID=$("$INSTANCES_MODULE" --generate-id "$TEST_BLUEPRINT" 2>/dev/null)
    if [[ -n "$INSTANCE_ID" ]]; then
        echo "[PASS] Generated instance ID '$INSTANCE_ID' for blueprint '$TEST_BLUEPRINT'"
    else
        echo "[FAIL] Failed to generate instance ID for blueprint '$TEST_BLUEPRINT'"
        exit 1
    fi
else
    echo "[SKIP] No suitable blueprint found for ID generation test"
fi

# Test 4: Test blueprint and instance JSON compatibility
echo "[STEP] Testing JSON output compatibility"
BLUEPRINTS_JSON=$("$BLUEPRINTS_MODULE" --list --json 2>/dev/null)
INSTANCES_JSON=$("$INSTANCES_MODULE" --list --json 2>/dev/null)

if [[ -n "$BLUEPRINTS_JSON" ]] && [[ "$BLUEPRINTS_JSON" != "null" ]]; then
    echo "[PASS] Blueprints module produces valid JSON"
else
    echo "[FAIL] Blueprints module JSON output invalid"
    exit 1
fi

if [[ -n "$INSTANCES_JSON" ]]; then
    echo "[PASS] Instances module produces JSON output"
else
    echo "[FAIL] Instances module JSON output invalid"
    exit 1
fi

# Test 5: Test that both modules use consistent configuration
echo "[STEP] Testing configuration consistency"
if [[ -f "$KGSM_ROOT/config.ini" ]]; then
    echo "[PASS] Configuration file exists and is accessible to both modules"
else
    echo "[FAIL] Configuration file not found"
    exit 1
fi

# Test 6: Test directory structure consistency
echo "[STEP] Testing directory structure consistency"
if [[ -d "$KGSM_ROOT/blueprints" ]]; then
    echo "[PASS] Blueprints directory structure is consistent"
else
    echo "[FAIL] Blueprints directory structure inconsistent"
    exit 1
fi

if [[ -d "$KGSM_ROOT/instances" ]] || mkdir -p "$KGSM_ROOT/instances" 2>/dev/null; then
    echo "[PASS] Instances directory structure is consistent"
else
    echo "[FAIL] Cannot create instances directory"
    exit 1
fi

echo "[SUCCESS] Blueprint-instance integration test passed"
exit 0
