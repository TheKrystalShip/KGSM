#!/usr/bin/env bash
#
# Environment setup/teardown for KGSM testing framework

export TEST_ENV_DIR=""

# Create a temporary directory for test execution
function create_test_environment() {
  local test_name="$1"
  TEST_ENV_DIR="$(mktemp -d)"

  # Store the original directory
  ORIGINAL_DIR="$(pwd)"

  # Return directory path
  echo "$TEST_ENV_DIR"
}

# Setup test environment for KGSM tests
# This will:
# - Create a temporary directory
# - Copy the entire KGSM project to the temp directory
# - Modify config.ini to use paths within the temp directory
function setup_test_environment() {
  local test_name="$1"

  # Create test environment directory
  TEST_ENV_DIR=$(create_test_environment "$test_name")

  log_info "Test environment created at: $TEST_ENV_DIR"

  log_info "Setting up KGSM test environment for: $test_name"

  # Copy the entire KGSM project to the test environment
  if [[ -z "$KGSM_ROOT" ]]; then
    log_error "KGSM_ROOT is not set. Cannot copy KGSM project."
    return 1
  fi

  log_info "Copying KGSM project from $KGSM_ROOT to $TEST_ENV_DIR"
  cp -r "$KGSM_ROOT"/. "$TEST_ENV_DIR/"

  # Set KGSM_ROOT to the test environment directory
  export KGSM_ROOT="$TEST_ENV_DIR"

  # Change to the test environment directory
  cd "$TEST_ENV_DIR" || {
    log_error "Failed to change to test environment directory"
    return 1
  }

  # Create a modified config.ini that points to directories within the test environment
  configure_test_environment

  # Return success
  return 0
}

# Configure the test environment's config.ini
function configure_test_environment() {

  if [[ ! -d "$TEST_ENV_DIR" ]]; then
    log_error "Test environment directory does not exist: $TEST_ENV_DIR"
    return 1
  fi

  log_info "Configuring test environment for KGSM at: $TEST_ENV_DIR"

  local config_file="$TEST_ENV_DIR/config.ini"

  # Make sure config.ini exists (copy from default if needed)
  if [[ ! -f "$config_file" ]]; then
    cp "$TEST_ENV_DIR/config.default.ini" "$config_file"
  fi

  # Modify paths in config.ini to point to test environment
  sed -i "s|KGSM_BRANCH=.*|KGSM_BRANCH=main|g" "$config_file"
  sed -i "s|KGSM_RUN_UPDATE_CHECK=.*|KGSM_RUN_UPDATE_CHECK=0|g" "$config_file"
  sed -i "s|USE_LOGGING=.*|USE_LOGGING=1|g" "$config_file"
  sed -i "s|USE_SYSTEMD=.*|USE_SYSTEMD=0|g" "$config_file"
  sed -i "s|USE_UFW=.*|USE_UFW=0|g" "$config_file"
  sed -i "s|USE_EVENTS=.*|USE_EVENTS=1|g" "$config_file"
  sed -i "s|KGSM_ROOT=.*|KGSM_ROOT=$TEST_ENV_DIR|g" "$config_file"
  sed -i "s|INSTANCE_DEFAULT_INSTALL_DIR=.*|INSTANCE_DEFAULT_INSTALL_DIR=$TEST_ENV_DIR/server_installs|g" "$config_file"
  sed -i "s|SYSTEMD_DIR=.*|SYSTEMD_DIR=$TEST_ENV_DIR/systemd|g" "$config_file"
  sed -i "s|UFW_RULES_DIR=.*|UFW_RULES_DIR=$TEST_ENV_DIR/ufw|g" "$config_file"
  sed -i "s|EVENTS_SOCKET_FILE=.*|EVENTS_SOCKET_FILE=$TEST_ENV_DIR/kgsm.sock|g" "$config_file"

  # Create required directories for testing
  mkdir -p "$TEST_ENV_DIR/logs"
  mkdir -p "$TEST_ENV_DIR/instances"
  mkdir -p "$TEST_ENV_DIR/server_installs"
  mkdir -p "$TEST_ENV_DIR/systemd"
  mkdir -p "$TEST_ENV_DIR/ufw"

  log_info "Test environment configured"
  return 0
}

# Remove the temporary test environment
function cleanup_test_environment() {
  if [[ -n "$TEST_ENV_DIR" && -d "$TEST_ENV_DIR" && "$NO_CLEANUP" -ne 1 ]]; then
    log_info "Cleaning up test environment: $TEST_ENV_DIR"
    rm -rf "$TEST_ENV_DIR"
  elif [[ "$NO_CLEANUP" -eq 1 ]]; then
    log_info "Skipping cleanup as requested. Test environment remains at: $TEST_ENV_DIR"
  fi

  # Return to original directory
  cd "$ORIGINAL_DIR" || {
    log_error "Failed to return to original directory: $ORIGINAL_DIR"
    exit 1
  }
}

# Tear down the test environment
function teardown_test_environment() {
  log_info "Tearing down test environment"
  cleanup_test_environment
  return 0
}

# Export functions
export -f setup_test_environment
export -f configure_test_environment
export -f teardown_test_environment
