#!/usr/bin/env bash
#
# Integration tests for files.sh module

log_header "Testing files.sh module"

# Test environment is already set up by the runner

# Create a test instance for file testing
log_info "Setting up test instance for file operations"
install_dir="$TEST_ENV_DIR/server_installs"
instance_id=$(./modules/instances.sh --create factorio.bp --install-dir "$install_dir" --id "file-test-instance")
assert_true "[[ -n \"$instance_id\" ]]" "Should create an instance and return its ID"
log_info "Created test instance: $instance_id"

# Create directories for the instance
log_info "Creating directories for test instance"
./modules/directories.sh -i "$instance_id" --create > /dev/null
assert_equals "$?" "0" "Directory creation should succeed"
log_info "Directories created"

# Test 1: Generate Instance Files
log_info "Test: Generate instance files"
file_create_result=$(./modules/files.sh -i "$instance_id" --create)
assert_equals "$?" "0" "File creation should succeed"
log_info "File creation completed"

# Test 2: Verify generated files
instance_dir="$install_dir/file-test-instance"
manage_file="$instance_dir/file-test-instance.manage.sh"
assert_file_exists "$manage_file" "Management script should be created"
assert_command_success "[[ -x \"$manage_file\" ]]" "Management script should be executable"
log_info "Generated files verified"

# Test 3: Remove Instance Files
log_info "Test: Remove instance files"
file_remove_result=$(./modules/files.sh -i "$instance_id" --remove)
assert_equals "$?" "0" "File removal should succeed"
log_info "File removal completed"

# Test 4: Verify files are removed
assert_false "[[ -f \"$manage_file\" ]]" "Management script should be removed"
log_info "File removal verified"

# Clean up
log_info "Cleaning up test instance"
./modules/directories.sh -i "$instance_id" --remove > /dev/null
./modules/instances.sh --remove "$instance_id" > /dev/null

log_success "All files.sh tests completed"

exit 0
