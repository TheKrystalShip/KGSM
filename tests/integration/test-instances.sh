#!/usr/bin/env bash
#
# Integration tests for instances.sh module

log_header "Testing instances.sh module"

# Test environment is already set up by the runner

# Test 1: Generate Instance ID
log_info "Test: Generate instance ID"
instance_id=$(./modules/instances.sh --generate-id factorio.bp)
assert_true "[[ -n \"$instance_id\" ]]" "Should generate a valid instance ID"
log_info "Generated instance ID: $instance_id"

# Test 2: Create Instance Configuration
log_info "Test: Create instance configuration"
install_dir="$TEST_ENV_DIR/server_installs"
instance_path=$(./modules/instances.sh --create factorio.bp --install-dir "$install_dir" --id "test-instance")
assert_true "[[ -n \"$instance_path\" ]]" "Should create an instance and return its ID"
log_info "Created instance: $instance_path"

# Test 3: Verify instance configuration file exists
config_file="$TEST_ENV_DIR/instances/factorio/test-instance.ini"
assert_file_exists "$config_file" "Instance configuration file should exist"
log_info "Instance configuration file created"

# Test 4: List instances
log_info "Test: List instances"
instances=$(./modules/instances.sh --list)
assert_contains "$instances" "test-instance" "Listed instances should contain our test instance"
log_info "Instances listed successfully"

# Test 5: List instances with detailed information
log_info "Test: List instances with detailed info"
detailed_info=$(./modules/instances.sh --list --detailed)
assert_contains "$detailed_info" "test-instance" "Detailed instance list should contain our test instance"
assert_contains "$detailed_info" "Directory:" "Detailed info should include directory information"
log_info "Detailed instance information retrieved"

# Test 6: Get instance information
log_info "Test: Get instance info"
info=$(./modules/instances.sh --info test-instance)
assert_contains "$info" "Name:" "Instance info should contain a name field"
assert_contains "$info" "Directory:" "Instance info should contain a directory field"
log_info "Instance info retrieved successfully"

# Test 7: Get instance information as JSON
log_info "Test: Get instance info as JSON"
json_info=$(./modules/instances.sh --info test-instance --json)
# Verify it's valid JSON and has expected structure
echo "$json_info" | jq . > /dev/null
assert_equals "$?" "0" "JSON output should be valid"
assert_contains "$json_info" "\"Name\":" "JSON should contain Name field"
log_info "JSON instance info retrieved successfully"

# Test 8: Remove instance
log_info "Test: Remove instance"
remove_result=$(./modules/instances.sh --remove test-instance)
assert_equals "$?" "0" "Remove command should succeed"
assert_file_exists "$config_file" "Instance configuration file should be removed" false
log_info "Instance removed successfully"

log_success "All instances.sh tests completed"

exit 0
