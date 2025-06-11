#!/usr/bin/env bash
#
# Integration tests for files.sh module

log_header "Testing files.sh module"

# Test environment is already set up by the runner

install_dir="$TEST_ENV_DIR/server_installs"
blueprint_name="factorio"
instance_name="factorio-test-instance"

function setup_test_instance() {
  # Create a test instance using the blueprint
  ./modules/instances.sh --create "$blueprint_name" --name "$instance_name" --install-dir "$install_dir" >/dev/null
  assert_equals "$?" "0" "Instance creation should succeed"

  ./modules/directories.sh -i "$instance_name" --create >/dev/null
  assert_equals "$?" "0" "Directory creation should succeed"

  ./modules/files.sh -i "$instance_name" --create >/dev/null
  assert_equals "$?" "0" "File creation should succeed"
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


# Create a test instance for file testing
log_info "Setting up test instance for file operations"
setup_test_instance
assert_true "[[ -n \"$instance_name\" ]]" "Should create an instance and return its ID"
log_info "Created test instance: $instance_name"

# Create directories for the instance
log_info "Creating directories for test instance"
./modules/directories.sh -i "$instance_name" --create >/dev/null
assert_equals "$?" "0" "Directory creation should succeed"
log_info "Directories created"

# Test 1: Generate Instance Files
log_info "Test: Generate instance files"
./modules/files.sh -i "$instance_name" --create --manage >/dev/null
assert_equals "$?" "0" "File creation should succeed"
log_info "File creation completed"

# Test 2: Verify generated files
instance_dir="$install_dir/$blueprint_name/$instance_name"
manage_file="$instance_dir/$instance_name.manage.sh"
assert_file_exists "$manage_file" "Management script should be created"
assert_command_success "[[ -x \"$manage_file\" ]]" "Management script should be executable"
log_info "Generated files verified"

# Test 3: Remove Instance Files
log_info "Test: Remove instance files"
./modules/files.sh -i "$instance_name" --remove >/dev/null
assert_equals "$?" "0" "File removal should succeed"
log_info "File removal completed"

# Test 4: Verify files are removed
assert_false "[[ -f \"$manage_file\" ]]" "Management script should be removed"
log_info "File removal verified"

# Clean up
log_info "Cleaning up test instance"
cleanup_test_instance

log_success "All files.sh tests completed"

exit 0
