#!/usr/bin/env bash

# KGSM Instance Lifecycle End-to-End Test
# Tests the complete lifecycle of creating and managing an instance

echo "[INFO] Starting instance lifecycle e2e test"

# Check environment
if [[ -z "$KGSM_ROOT" ]]; then
    echo "[FAIL] KGSM_ROOT not set"
    exit 1
fi

INSTANCES_MODULE="$KGSM_ROOT/modules/instances.sh"
TEST_INSTALL_DIR="$KGSM_ROOT/test_instances"

# Cleanup function
cleanup() {
    echo "[STEP] Cleaning up test instance"
    if [[ -n "$TEST_INSTANCE_NAME" ]]; then
        "$INSTANCES_MODULE" --remove "$TEST_INSTANCE_NAME" >/dev/null 2>&1 || true
    fi
    if [[ -d "$TEST_INSTALL_DIR" ]]; then
        rm -rf "$TEST_INSTALL_DIR" >/dev/null 2>&1 || true
    fi
}

# Set up cleanup trap
trap cleanup EXIT

# Test 1: Find a suitable blueprint for testing
echo "[STEP] Finding suitable blueprint for testing"
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
    echo "[PASS] Using blueprint: $TEST_BLUEPRINT"
else
    echo "[FAIL] No suitable blueprint found for testing"
    exit 1
fi

# Test 2: Create test install directory
echo "[STEP] Creating test install directory"
if mkdir -p "$TEST_INSTALL_DIR"; then
    echo "[PASS] Test install directory created: $TEST_INSTALL_DIR"
else
    echo "[FAIL] Failed to create test install directory"
    exit 1
fi

# Test 3: Generate instance ID
echo "[STEP] Generating instance ID"
TEST_INSTANCE_NAME=$("$INSTANCES_MODULE" --generate-id "$TEST_BLUEPRINT" 2>/dev/null)
if [[ -n "$TEST_INSTANCE_NAME" ]]; then
    echo "[PASS] Generated instance ID: $TEST_INSTANCE_NAME"
else
    echo "[FAIL] Failed to generate instance ID"
    exit 1
fi

# Test 4: Create instance
echo "[STEP] Creating instance"
CREATED_INSTANCE=$("$INSTANCES_MODULE" --create "$TEST_BLUEPRINT" --install-dir "$TEST_INSTALL_DIR" --name "$TEST_INSTANCE_NAME" 2>/dev/null)
if [[ "$CREATED_INSTANCE" == "$TEST_INSTANCE_NAME" ]]; then
    echo "[PASS] Instance created successfully: $CREATED_INSTANCE"
else
    echo "[FAIL] Failed to create instance. Expected: $TEST_INSTANCE_NAME, Got: $CREATED_INSTANCE"
    exit 1
fi

# Test 5: Verify instance exists in list
echo "[STEP] Verifying instance appears in list"
INSTANCE_LIST=$("$INSTANCES_MODULE" --list 2>/dev/null)
if echo "$INSTANCE_LIST" | grep -q "$TEST_INSTANCE_NAME"; then
    echo "[PASS] Instance appears in instance list"
else
    echo "[FAIL] Instance does not appear in instance list"
    echo "[DEBUG] Instance list: $INSTANCE_LIST"
    exit 1
fi

# Test 6: Find instance config file
echo "[STEP] Finding instance configuration file"
INSTANCE_CONFIG=$("$INSTANCES_MODULE" --find "$TEST_INSTANCE_NAME" 2>/dev/null)
if [[ -f "$INSTANCE_CONFIG" ]]; then
    echo "[PASS] Instance config file found: $INSTANCE_CONFIG"
else
    echo "[FAIL] Instance config file not found"
    exit 1
fi

# Test 7: Get instance info
echo "[STEP] Getting instance information"
if "$INSTANCES_MODULE" --info "$TEST_INSTANCE_NAME" >/dev/null 2>&1; then
    echo "[PASS] Instance info command works"
else
    echo "[FAIL] Instance info command failed"
    exit 1
fi

# Test 8: Get instance info in JSON format
echo "[STEP] Getting instance information in JSON format"
INSTANCE_JSON=$("$INSTANCES_MODULE" --info "$TEST_INSTANCE_NAME" --json 2>/dev/null)
if [[ -n "$INSTANCE_JSON" ]] && [[ "$INSTANCE_JSON" != "null" ]]; then
    echo "[PASS] Instance JSON info command works"
else
    echo "[FAIL] Instance JSON info command failed"
    exit 1
fi

# Test 9: Get instance status
echo "[STEP] Getting instance status"
if "$INSTANCES_MODULE" --status "$TEST_INSTANCE_NAME" >/dev/null 2>&1; then
    echo "[PASS] Instance status command works"
else
    echo "[FAIL] Instance status command failed"
    exit 1
fi

# Test 10: Verify instance configuration exists (directory created during install)
echo "[STEP] Verifying instance configuration"
# The instance directory is created during installation, not just configuration
# So we verify the config file exists instead
if [[ -f "$INSTANCE_CONFIG" ]]; then
    echo "[PASS] Instance configuration verified: $INSTANCE_CONFIG"
else
    echo "[FAIL] Instance configuration not found: $INSTANCE_CONFIG"
    exit 1
fi

# Test 11: Remove instance
echo "[STEP] Removing instance"
INSTANCE_NAME_TO_REMOVE="$TEST_INSTANCE_NAME"
if "$INSTANCES_MODULE" --remove "$TEST_INSTANCE_NAME" >/dev/null 2>&1; then
    echo "[PASS] Instance removed successfully"
    TEST_INSTANCE_NAME="" # Clear so cleanup doesn't try to remove again
else
    echo "[FAIL] Failed to remove instance"
    exit 1
fi

# Test 12: Verify instance no longer exists
echo "[STEP] Verifying instance removal"
INSTANCE_LIST_AFTER=$("$INSTANCES_MODULE" --list 2>/dev/null)
if echo "$INSTANCE_LIST_AFTER" | grep -q "$INSTANCE_NAME_TO_REMOVE"; then
    echo "[FAIL] Instance still appears in list after removal"
    echo "[DEBUG] Instance name: '$INSTANCE_NAME_TO_REMOVE'"
    echo "[DEBUG] List after removal: '$INSTANCE_LIST_AFTER'"
    exit 1
else
    echo "[PASS] Instance successfully removed from list"
fi

echo "[SUCCESS] Instance lifecycle e2e test completed successfully"
exit 0
