#!/usr/bin/env bash
#
# End-to-end test for installing and managing a Steam server (Necesse)
#
# This test will:
# 1. Install a Necesse server
# 2. Start the server
# 3. Check server status
# 4. Stop the server
# 5. Uninstall the server

# Source framework
source "$TEST_ROOT/framework/common.sh" || {
  echo "Failed to source common.sh"
  exit 1
}

log_header "E2E Test: Steam-based Server (Necesse)"

# Check if SteamCMD is available
if ! command -v steamcmd &> /dev/null; then
  log_warning "SteamCMD not found. This test requires SteamCMD to be installed."
  log_warning "Skipping Steam server test."
  exit 0
fi

# Test environment is already set up by the runner
log_info "Testing Necesse server installation from Steam"

# Step 1: Install Necesse server
log_info "Step 1: Installing Necesse server"
install_cmd="./kgsm.sh --create necesse --name necesse"

log_info "Running command: $install_cmd"
install_output=$(run_with_timeout 300 $install_cmd 2>&1)
install_exit_code=$?

# Check if installation was successful
if [[ $install_exit_code -ne 0 ]]; then
  log_error "Failed to install Necesse server"
  log_error "Command output: $install_output"
  exit 1
fi

log_success "Necesse server installed successfully"

# Verify instance was created
assert_true "./modules/instances.sh --list | grep -q 'necesse'" "Necesse instance should be listed"

# Get instance ID
instance_name=$(./modules/instances.sh --list | grep 'necesse')
log_info "Necesse instance ID: $instance_name"

# Step 2: Start the server
log_info "Step 2: Starting Necesse server"
start_cmd="./kgsm.sh --instance $instance_name --start"

log_info "Running command: $start_cmd"
start_output=$(run_with_timeout 60 $start_cmd 2>&1)
start_exit_code=$?

# Check if start was successful
if [[ $start_exit_code -ne 0 ]]; then
  log_error "Failed to start Necesse server"
  log_error "Command output: $start_output"
  exit 1
fi

log_success "Necesse server started successfully"

# Wait a moment for server to initialize
sleep 5

# Step 3: Check server status
log_info "Step 3: Checking Necesse server status"
status_cmd="./kgsm.sh --instance $instance_name --status"

log_info "Running command: $status_cmd"
status_output=$(run_with_timeout 30 $status_cmd 2>&1)
status_exit_code=$?

# Check if status check was successful
if [[ $status_exit_code -ne 0 ]]; then
  log_error "Failed to get Necesse server status"
  log_error "Command output: $status_output"
  exit 1
fi

# Verify server is running
assert_contains "$status_output" "active" "Necesse server should be active"
log_success "Necesse server status check successful"

# Step 4: Stop the server
log_info "Step 4: Stopping Necesse server"
stop_cmd="./kgsm.sh --instance $instance_name --stop"

log_info "Running command: $stop_cmd"
stop_output=$(run_with_timeout 60 $stop_cmd 2>&1)
stop_exit_code=$?

# Check if stop was successful
if [[ $stop_exit_code -ne 0 ]]; then
  log_error "Failed to stop Necesse server"
  log_error "Command output: $stop_output"
  exit 1
fi

log_success "Necesse server stopped successfully"

# Verify server is stopped
sleep 5
is_active_cmd="./modules/lifecycle.sh --is-active $instance_name"
status_check_output=$($is_active_cmd 2>&1)
if ! echo "$status_check_output" | grep -q "inactive"; then
  log_error "Server is still running when it should be stopped"
  exit 1
fi

log_success "Verified server is stopped"

# Step 5: Uninstall the server
log_info "Step 5: Uninstalling Necesse server"
uninstall_cmd="./kgsm.sh --uninstall $instance_name"

log_info "Running command: $uninstall_cmd"
uninstall_output=$(run_with_timeout 60 $uninstall_cmd 2>&1)
uninstall_exit_code=$?

# Check if uninstall was successful
if [[ $uninstall_exit_code -ne 0 ]]; then
  log_error "Failed to uninstall Necesse server"
  log_error "Command output: $uninstall_output"
  exit 1
fi

log_success "Necesse server uninstalled successfully"

# Verify instance was removed
assert_false "./modules/instances.sh --list | grep -q 'necesse'" "Necesse instance should not be listed after uninstall"

log_success "All Necesse server tests completed successfully"

exit 0
