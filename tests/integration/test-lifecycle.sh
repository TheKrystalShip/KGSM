#!/usr/bin/env bash
#
# Integration tests for lifecycle.sh module

log_header "Testing lifecycle.sh module"

# Test environment is already set up by the runner

test_instance_name="lifecycle-test-instance"

# Create a simple mock instance for lifecycle testing
# This doesn't need a real game server as we'll just check the script execution
function setup_test_instance() {
  ./kgsm.sh --create factorio --name "$test_instance_name" >/dev/null
  assert_equals "$?" "0" "Instance creation should succeed"
}

# Clean up mock instance
function cleanup_mock_instance() {
  ./kgsm.sh --uninstall "$test_instance_name" >/dev/null
  assert_equals "$?" "0" "Instance uninstallation should succeed"
}

# Create mock instance
log_info "Setting up mock instance for lifecycle tests"
setup_test_instance
log_info "Mock instance setup completed"

# Test 1: Check if instance is active (should be inactive at first)
log_info "Test: Check if instance is active"
# We don't use assert_command_fails here because we want to check the specific return code
./modules/lifecycle.sh --is-active "$test_instance_name" >/dev/null 2>&1
assert_equals "$?" "1" "Instance should not be active"
log_info "Instance activity check completed"

# Test 2: Start instance
log_info "Test: Start instance"
./modules/lifecycle.sh --start "$test_instance_name" >/dev/null 2>&1
assert_equals "$?" "0" "Start command should succeed"
log_info "Instance start completed"

# Test 3: Check lifecycle manager type
log_info "Test: Check lifecycle manager type"
# Get the instance config to see which lifecycle manager is used
instance_config=$(./modules/instances.sh --info "$test_instance_name")
assert_contains "$instance_config" "standalone" "Lifecycle manager should be standalone in test environment"
log_info "Lifecycle manager check completed"

# Test 4: Get logs (will be empty but command should succeed)
log_info "Test: Get logs"
logs_command="./modules/lifecycle.sh --logs $test_instance_name"
assert_command_success "$logs_command" "Logs command should succeed"
log_info "Logs command completed"

# Clean up
cleanup_mock_instance

log_success "All lifecycle.sh tests completed"

exit 0
