#!/usr/bin/env bash
#
# Integration tests for directories.sh module

log_header "Testing directories.sh module"

# Test environment is already set up by the runner

# Create a test instance for directory testing
log_info "Setting up test instance for directory operations"
install_dir="$TEST_ENV_DIR/server_installs"
instance_id=$(./modules/instances.sh --create factorio.bp --install-dir "$install_dir" --id "dir-test-instance")
assert_true "[[ -n \"$instance_id\" ]]" "Should create an instance and return its ID"
log_info "Created test instance: $instance_id"

# Test 1: Create Instance Directories
log_info "Test: Create instance directories"
dir_create_result=$(./modules/directories.sh -i "$instance_id" --create)
assert_equals "$?" "0" "Directory creation should succeed"
log_info "Directory creation completed"

# Test 2: Verify directory structure
instance_dir="$install_dir/dir-test-instance"
assert_directory_exists "$instance_dir" "Instance working directory should exist"
assert_directory_exists "$instance_dir/temp" "Temp directory should exist"
assert_directory_exists "$instance_dir/backups" "Backups directory should exist"
assert_directory_exists "$instance_dir/logs" "Logs directory should exist"
log_info "Directory structure verified"

# Test 3: Remove Instance Directories
log_info "Test: Remove instance directories"
dir_remove_result=$(./modules/directories.sh -i "$instance_id" --remove)
assert_equals "$?" "0" "Directory removal should succeed"
log_info "Directory removal completed"

# Test 4: Verify directories are removed
assert_false "[[ -d \"$instance_dir\" ]]" "Instance working directory should be removed"
log_info "Directory removal verified"

# Clean up
log_info "Cleaning up test instance"
./modules/instances.sh --remove "$instance_id" > /dev/null

log_success "All directories.sh tests completed"

exit 0
