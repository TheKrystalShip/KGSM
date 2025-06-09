#!/usr/bin/env bash
#
# Integration tests for lifecycle.sh module

log_header "Testing lifecycle.sh module"

# Test environment is already set up by the runner

# Create a simple mock instance for lifecycle testing
# This doesn't need a real game server as we'll just check the script execution
function setup_mock_instance() {
  # Create instance
  install_dir="$TEST_ENV_DIR/server_installs"
  instance_name=$(./modules/instances.sh --create factorio --name "lifecycle-test")
  assert_true "[[ -n \"$instance_name\" ]]" "Should create an instance and return its ID"

  # Create directories
  ./modules/directories.sh -i "$instance_name" --create > /dev/null
  assert_equals "$?" "0" "Directory creation should succeed"

  # Create files
  ./modules/files.sh -i "$instance_name" --create > /dev/null
  assert_equals "$?" "0" "File creation should succeed"

  # Create a mock management script for our test instance
  # Just to ensure lifecycle tests can execute without a real server
  instance_dir="$install_dir/lifecycle-test"
  manage_file="$instance_dir/lifecycle-test.manage.sh"

  # Modify the management script to echo commands instead of running a real server
  sed -i 's/exec "$instance_executable_file" $instance_executable_arguments/echo "Server would start with: $instance_executable_file $instance_executable_arguments"/' "$manage_file"

  # Create mock version file
  echo "1.0.0" > "$instance_dir/.lifecycle-test.version"

  echo "$instance_name"
}

# Clean up mock instance
function cleanup_mock_instance() {
  local instance_name="$1"

  log_info "Cleaning up mock instance"

  # Remove directories
  ./modules/directories.sh -i "$instance_name" --remove > /dev/null

  # Remove instance config
  ./modules/instances.sh --remove "$instance_name" > /dev/null

  log_info "Mock instance cleanup completed"
}

# Create mock instance
log_info "Setting up mock instance for lifecycle tests"
instance_name=$(setup_mock_instance)
log_info "Mock instance setup completed"

# Test 1: Check if instance is active (should be inactive at first)
log_info "Test: Check if instance is active"
# We don't use assert_command_fails here because we want to check the specific return code
./modules/lifecycle.sh --is-active "$instance_name" > /dev/null 2>&1
assert_equals "$?" "1" "Instance should not be active"
log_info "Instance activity check completed"

# Test 2: Start instance
log_info "Test: Start instance"
start_output=$(./modules/lifecycle.sh --start "$instance_name" 2>&1)
assert_equals "$?" "0" "Start command should succeed"
log_info "Instance start completed"

# Test 3: Check lifecycle manager type
log_info "Test: Check lifecycle manager type"
# Get the instance config to see which lifecycle manager is used
instance_config=$(./modules/instances.sh --info "$instance_name")
assert_contains "$instance_config" "standalone" "Lifecycle manager should be standalone in test environment"
log_info "Lifecycle manager check completed"

# Test 4: Get logs (will be empty but command should succeed)
log_info "Test: Get logs"
logs_command="./modules/lifecycle.sh --logs $instance_name"
assert_command_success "$logs_command" "Logs command should succeed"
log_info "Logs command completed"

# Clean up
cleanup_mock_instance "$instance_name"

log_success "All lifecycle.sh tests completed"

exit 0
