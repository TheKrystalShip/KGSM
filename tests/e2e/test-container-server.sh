#!/usr/bin/env bash
#
# End-to-end test for installing and managing a container server (V Rising)
#
# This test will:
# 1. Install a V Rising container server
# 2. Start the server
# 3. Check server status
# 4. Stop the server
# 5. Uninstall the server

# Source framework
source "$TEST_ROOT/framework/common.sh" || {
  echo "Failed to source common.sh"
  exit 1
}

log_header "E2E Test: Container Server (V Rising)"

# Check if Docker is available
if ! command -v docker &> /dev/null; then
  log_warning "Docker not found. This test requires Docker to be installed."
  log_warning "Skipping container server test."
  exit 0
fi

# Check if Docker Compose is available
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
  log_warning "Docker Compose not found. This test requires Docker Compose to be installed."
  log_warning "Skipping container server test."
  exit 0
fi

# Test environment is already set up by the runner
log_info "Testing V Rising server installation in container"

# Step 1: Install V Rising server
log_info "Step 1: Installing V Rising server"
install_dir="$TEST_ENV_DIR/server_installs"
install_cmd="./kgsm.sh --install vrising --install-dir $install_dir"

log_info "Running command: $install_cmd"
install_output=$(run_with_timeout 300 $install_cmd 2>&1)
install_exit_code=$?

# Check if installation was successful
if [[ $install_exit_code -ne 0 ]]; then
  log_error "Failed to install V Rising server"
  log_error "Command output: $install_output"
  exit 1
fi

log_success "V Rising server installed successfully"

# Verify instance was created
assert_true "./modules/instances.sh --list | grep -q 'vrising'" "V Rising instance should be listed"

# Get instance ID
instance_id=$(./modules/instances.sh --list | grep 'vrising')
log_info "V Rising instance ID: $instance_id"

# Step 2: Start the server
log_info "Step 2: Starting V Rising server"
start_cmd="./kgsm.sh --instance $instance_id --start"

log_info "Running command: $start_cmd"
start_output=$(run_with_timeout 60 $start_cmd 2>&1)
start_exit_code=$?

# Check if start was successful
if [[ $start_exit_code -ne 0 ]]; then
  log_error "Failed to start V Rising server"
  log_error "Command output: $start_output"
  exit 1
fi

log_success "V Rising server started successfully"

# Wait a moment for container to initialize
sleep 5

# Step 3: Check server status
log_info "Step 3: Checking V Rising server status"
status_cmd="./kgsm.sh --instance $instance_id --status"

log_info "Running command: $status_cmd"
status_output=$(run_with_timeout 30 $status_cmd 2>&1)
status_exit_code=$?

# Check if status check was successful
if [[ $status_exit_code -ne 0 ]]; then
  log_error "Failed to get V Rising server status"
  log_error "Command output: $status_output"
  exit 1
fi

# Verify server is running
assert_contains "$status_output" "active" "V Rising server should be active"
log_success "V Rising server status check successful"

# Step 4: Stop the server
log_info "Step 4: Stopping V Rising server"
stop_cmd="./kgsm.sh --instance $instance_id --stop"

log_info "Running command: $stop_cmd"
stop_output=$(run_with_timeout 60 $stop_cmd 2>&1)
stop_exit_code=$?

# Check if stop was successful
if [[ $stop_exit_code -ne 0 ]]; then
  log_error "Failed to stop V Rising server"
  log_error "Command output: $stop_output"
  exit 1
fi

log_success "V Rising server stopped successfully"

# Verify server is stopped
sleep 2
is_active_cmd="./modules/lifecycle.sh --is-active $instance_id"
if $is_active_cmd &> /dev/null; then
  log_error "Server is still running when it should be stopped"
  exit 1
fi

log_success "Verified server is stopped"

# Step 5: Uninstall the server
log_info "Step 5: Uninstalling V Rising server"
uninstall_cmd="./kgsm.sh --uninstall $instance_id"

log_info "Running command: $uninstall_cmd"
uninstall_output=$(run_with_timeout 60 $uninstall_cmd 2>&1)
uninstall_exit_code=$?

# Check if uninstall was successful
if [[ $uninstall_exit_code -ne 0 ]]; then
  log_error "Failed to uninstall V Rising server"
  log_error "Command output: $uninstall_output"
  exit 1
fi

log_success "V Rising server uninstalled successfully"

# Verify instance was removed
assert_false "./modules/instances.sh --list | grep -q 'vrising'" "V Rising instance should not be listed after uninstall"

log_success "All V Rising server tests completed successfully"

exit 0
