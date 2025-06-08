#!/usr/bin/env bash
#
# Integration tests for blueprints.sh module

log_header "Testing blueprints.sh module"

# Test environment is already set up by the runner

# Test 1: List Blueprints
log_info "Test: List blueprints"
blueprints=$(./modules/blueprints.sh --list)
assert_true "[[ -n \"${blueprints[*]}\" ]]" "Should list available blueprints"
assert_contains "$blueprints" "factorio" "Blueprint list should contain factorio"
log_info "Blueprints listed successfully"

# Test 2: List Blueprints with JSON format
log_info "Test: List blueprints as JSON"
json_blueprints=$(./modules/blueprints.sh --list --json)
# Verify it's valid JSON
echo "$json_blueprints" | jq . > /dev/null
assert_equals "$?" "0" "JSON output should be valid"
log_info "JSON blueprints retrieved successfully"

# Test 3: List Blueprints with detailed information
log_info "Test: List blueprints with detailed info"
detailed_blueprints=$(./modules/blueprints.sh --list --detailed)
assert_contains "$detailed_blueprints" "factorio" "Detailed blueprint list should contain factorio"
assert_contains "$detailed_blueprints" "Description:" "Detailed info should include description"
log_info "Detailed blueprint information retrieved"

# Test 4: Find specific blueprint
log_info "Test: Find blueprint 'factorio.bp'"
factorio_bp_path=$(./modules/blueprints.sh --find factorio.bp)
assert_true "[[ -n \"$factorio_bp_path\" ]]" "Should find factorio.bp"
assert_true "[[ -f \"$factorio_bp_path\" ]]" "Factorio blueprint file should exist"
log_info "Blueprint found at: $factorio_bp_path"

# Test 5: Create a simple test blueprint
log_info "Test: Create test blueprint"
test_bp_name="test-blueprint-$(date +%s)"
test_bp_content="NAME=\"Test Blueprint\"
DESCRIPTION=\"A test blueprint for integration testing\"
VERSION=\"1.0.0\"
EXECUTABLE=\"test-server\"
ARGS=\"--test\"
PORT=28000
STEAM_APP_ID=0"

# Create a temporary blueprint file
test_bp_file="$TEST_ENV_DIR/blueprints/custom/native/$test_bp_name.bp"
mkdir -p "$(dirname "$test_bp_file")"
echo "$test_bp_content" > "$test_bp_file"

# Verify blueprint is recognized
log_info "Verifying test blueprint is recognized"
blueprints_after=$(./modules/blueprints.sh --list)
assert_contains "$blueprints_after" "$test_bp_name" "Blueprint list should contain the new test blueprint"
log_info "Test blueprint created and recognized"

log_success "All blueprints.sh tests completed"

exit 0
