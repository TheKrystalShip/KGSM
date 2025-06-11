#!/usr/bin/env bash
#
# Integration tests for instances.sh module

log_header "Testing instances.sh module"

# Test environment is already set up by the runner

install_dir="${TEST_ENV_DIR:?}/server_installs"
blueprint_name="factorio"
instance_name="test-instance"

function setup_test_instance() {
  # Create a test instance using the blueprint
  ./modules/instances.sh --create "$blueprint_name" --name "$instance_name" --install-dir "$install_dir" >/dev/null
  assert_equals "$?" "0" "Instance creation should succeed"

  ./modules/directories.sh -i "$instance_name" --create >/dev/null
  assert_equals "$?" "0" "Directory creation should succeed"

  ./modules/files.sh -i "$instance_name" --create --manage >/dev/null
  assert_equals "$?" "0" "File creation should succeed"

  # shellcheck disable=SC1090
  source "$(./modules/instances.sh --find "$instance_name")"
  assert_true "[[ -n \"$instance_name\" ]]" "Should create an instance and return its ID"

  echo "1.0.0" > "$instance_version_file"
  assert_file_exists "$instance_version_file" "Instance version file should exist"
}

function cleanup_test_instance() {
  # Remove the test instance
  ./modules/files.sh -i "$instance_name" --remove >/dev/null
  assert_equals "$?" "0" "File removal should succeed"

  ./modules/directories.sh -i "$instance_name" --remove >/dev/null
  assert_equals "$?" "0" "Directory removal should succeed"

  ./modules/instances.sh --remove "$instance_name" >/dev/null
  assert_equals "$?" "0" "Instance removal should succeed"
}

# Test 1: Generate Instance ID
log_info "Test: Generate instance ID"
instance_name=$(./modules/instances.sh --generate-id "$instance_name")
assert_true "[[ -n \"$instance_name\" ]]" "Should generate a valid instance ID"
log_info "Generated instance ID: $instance_name"

# Test 2: Create Instance Configuration
log_info "Test: Create instance configuration"
install_dir="${TEST_ENV_DIR:?}/server_installs"
instance_path=$(./modules/instances.sh --create "$blueprint_name" --install-dir "$install_dir" --name "$instance_name")
assert_true "[[ -n \"$instance_path\" ]]" "Should create an instance and return its ID"
log_info "Created instance: $instance_path"

# Test 3: Verify instance configuration file exists
config_file="${TEST_ENV_DIR:?}/instances/$blueprint_name/$instance_name.ini"
assert_file_exists "$config_file" "Instance configuration file should exist"
log_info "Instance configuration file created"

# Test 4: List instances
log_info "Test: List instances"
instances=$(./modules/instances.sh --list)
assert_contains "$instances" "$instance_name" "Listed instances should contain our test instance"
log_info "Instances listed successfully"

# Test 5: List instances with detailed information
log_info "Test: List instances with detailed info"
# Instances need a management script in order to list detailed info
setup_test_instance
detailed_info=$(./modules/instances.sh --list --detailed)
assert_contains "$detailed_info" "$instance_name" "Detailed instance list should contain our test instance"
assert_contains "$detailed_info" "Directory:" "Detailed info should include directory information"
log_info "Detailed instance information retrieved"

# Test 6: Get instance information
log_info "Test: Get instance info"
info=$(./modules/instances.sh --info "$instance_name")
assert_contains "$info" "Name:" "Instance info should contain a name field"
assert_contains "$info" "Directory:" "Instance info should contain a directory field"
log_info "Instance info retrieved successfully"

# Test 7: Get instance information as JSON
log_info "Test: Get instance info as JSON"
json_info=$(./modules/instances.sh --info "$instance_name" --json)
# Verify it's valid JSON and has expected structure
echo "$json_info" | jq . >/dev/null
assert_equals "$?" "0" "JSON output should be valid"
assert_contains "$json_info" "\"Name\":" "JSON should contain Name field"
log_info "JSON instance info retrieved successfully"

# Test 8: Remove instance
log_info "Test: Remove instance"
./modules/instances.sh --remove "$instance_name" >/dev/null
assert_equals "$?" "0" "Remove command should succeed"
# assert_file_exists "$config_file" "Instance configuration file should be removed"
log_info "Instance removed successfully"

cleanup_test_instance

log_success "All instances.sh tests completed"

exit 0
