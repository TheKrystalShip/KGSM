#!/usr/bin/env bash
#
# End-to-end test for installing and managing an external server (Factorio)
#
# This test will:
# 1. Install a Factorio server
# 2. Start the server
# 3. Check server status
# 4. Stop the server
# 5. Uninstall the server

# Source framework
source "$TEST_ROOT/framework/common.sh" || {
  echo "Failed to source common.sh"
  exit 1
}

log_header "E2E Test: External Server (Factorio)"

# Test environment is already set up by the runner
log_info "Testing Factorio server installation from external source"

# Step 1: Install Factorio server
log_info "Step 1: Installing Factorio server"
install_cmd="./kgsm.sh --create factorio --name factorio"

log_info "Running command: $install_cmd"
install_output=$(run_with_timeout 300 $install_cmd 2>&1)
install_exit_code=$?

# Check if installation was successful
if [[ $install_exit_code -ne 0 ]]; then
  log_error "Failed to install Factorio server"
  log_error "Command output: $install_output"
  exit 1
fi

log_success "Factorio server installed successfully"

# Verify instance was created
assert_true "./modules/instances.sh --list | grep -q 'factorio'" "Factorio instance should be listed"

# Get instance ID
instance_name=$(./modules/instances.sh --list | grep 'factorio')
log_info "Factorio instance ID: $instance_name"

# Step 2: Start the server
log_info "Step 2: Starting Factorio server"
start_cmd="./kgsm.sh --instance $instance_name --start"

log_info "Running command: $start_cmd"
start_output=$(run_with_timeout 60 $start_cmd 2>&1)
start_exit_code=$?

# Check if start was successful
if [[ $start_exit_code -ne 0 ]]; then
  log_error "Failed to start Factorio server"
  log_error "Command output: $start_output"
  exit 1
fi

log_success "Factorio server started successfully"

# Wait a moment for server to initialize
sleep 5

# Step 3: Check server status
log_info "Step 3: Checking Factorio server status"
status_cmd="./kgsm.sh --instance $instance_name --status"

log_info "Running command: $status_cmd"
status_output=$(run_with_timeout 30 $status_cmd 2>&1)
status_exit_code=$?

# Check if status check was successful
if [[ $status_exit_code -ne 0 ]]; then
  log_error "Failed to get Factorio server status"
  log_error "Command output: $status_output"
  exit 1
fi

# Verify server is running
assert_contains "$status_output" "active" "Factorio server should be active"
log_success "Factorio server status check successful"

# Step 4: Stop the server
log_info "Step 4: Stopping Factorio server"
stop_cmd="./kgsm.sh --instance $instance_name --stop"

log_info "Running command: $stop_cmd"
stop_output=$(run_with_timeout 60 $stop_cmd 2>&1)
stop_exit_code=$?

# Check if stop was successful
if [[ $stop_exit_code -ne 0 ]]; then
  log_error "Failed to stop Factorio server"
  log_error "Command output: $stop_output"
  exit 1
fi

log_success "Factorio server stopped successfully"

# Verify server is stopped
sleep 10
./modules/lifecycle.sh --is-active "$instance_name" >/dev/null 2>&1
assert_equals "$?" "1" "Factorio server should not be active after stop"
log_success "Verified server is stopped"

# Step 5: Uninstall the server
log_info "Step 5: Uninstalling Factorio server"
uninstall_cmd="./kgsm.sh --uninstall $instance_name"

log_info "Running command: $uninstall_cmd"
uninstall_output=$(run_with_timeout 60 $uninstall_cmd 2>&1)
uninstall_exit_code=$?

# Check if uninstall was successful
if [[ $uninstall_exit_code -ne 0 ]]; then
  log_error "Failed to uninstall Factorio server"
  log_error "Command output: $uninstall_output"
  exit 1
fi

log_success "Factorio server uninstalled successfully"

# Verify instance was removed
assert_false "./modules/instances.sh --list | grep -q 'factorio'" "Factorio instance should not be listed after uninstall"

log_success "All Factorio server tests completed successfully"

exit 0
