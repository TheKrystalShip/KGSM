#!/usr/bin/env bash

# KGSM Configuration Unit Tests
# Tests the configuration file handling and validation

# =============================================================================
# TEST SETUP
# =============================================================================

# Source the test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../framework/common.sh"

readonly TEST_NAME="configuration"

# =============================================================================
# TEST FUNCTIONS
# =============================================================================

function setup_test() {
  log_step "Setting up configuration unit tests"

  # Verify test environment is properly initialized
  assert_not_null "$KGSM_ROOT" "KGSM_ROOT should be set"
  assert_dir_exists "$KGSM_ROOT" "KGSM root directory should exist"

  log_test "Test environment validated"
}

function test_configuration_files_existence() {
  log_step "Testing configuration file existence"

  assert_file_exists "$KGSM_ROOT/config.default.ini" "config.default.ini should exist"
  assert_file_exists "$KGSM_ROOT/config.ini" "config.ini should exist"
}

function test_configuration_files_readability() {
  log_step "Testing configuration file readability"

  # Test default config readability
  if [[ -r "$KGSM_ROOT/config.default.ini" ]]; then
    assert_true "true" "config.default.ini should be readable"
  else
    assert_true "false" "config.default.ini should be readable"
  fi

  # Test main config readability
  if [[ -r "$KGSM_ROOT/config.ini" ]]; then
    assert_true "true" "config.ini should be readable"
  else
    assert_true "false" "config.ini should be readable"
  fi
}

function test_configuration_structure() {
  log_step "Testing configuration file structure"

  # Test for expected configuration options
  assert_file_contains "$KGSM_ROOT/config.ini" "enable_logging" "config.ini should contain enable_logging option"
  assert_file_contains "$KGSM_ROOT/config.ini" "default_install_directory" "config.ini should contain default_install_directory option"
}

function test_environment_overrides() {
  log_step "Testing test environment overrides"

  assert_file_contains "$KGSM_ROOT/config.ini" "TEST ENVIRONMENT OVERRIDES" "config.ini should contain test environment overrides section"
}

function test_systemd_disabled() {
  log_step "Testing systemd disabled in test environment"

  assert_file_contains "$KGSM_ROOT/config.ini" "enable_systemd=false" "systemd should be disabled in test environment"
}

function test_firewall_management_disabled() {
  log_step "Testing firewall management disabled in test environment"

  assert_file_contains "$KGSM_ROOT/config.ini" "enable_firewall_management=false" "firewall management should be disabled in test environment"
}

function test_configuration_syntax() {
  log_step "Testing configuration syntax"

  # Check for basic ini file syntax - configuration key-value pairs
  local syntax_check
  if syntax_check=$(grep -E "^[a-zA-Z_][a-zA-Z0-9_]*=" "$KGSM_ROOT/config.ini"); then
    assert_not_null "$syntax_check" "Configuration should contain valid key=value pairs"
    log_test "Found valid configuration syntax"
  else
    assert_true "false" "Configuration syntax should be valid"
  fi
}

function test_test_specific_settings() {
  log_step "Testing test-specific configuration settings"

  # Test for test-specific settings that should be present
  assert_file_contains "$KGSM_ROOT/config.ini" "enable_logging=true" "logging should be enabled for tests"

  # Check for port forwarding disabled (safer for tests)
  if grep -q "enable_port_forwarding=false" "$KGSM_ROOT/config.ini"; then
    log_test "Port forwarding is disabled in test environment"
  else
    log_test "Port forwarding setting not found (may use default)"
  fi
}

function test_directory_settings() {
  log_step "Testing directory configuration settings"

  # The default install directory should be set to the sandbox
  local install_dir_setting
  if install_dir_setting=$(grep "default_install_directory=" "$KGSM_ROOT/config.ini"); then
    assert_contains "$install_dir_setting" "$KGSM_ROOT" "Install directory should be within sandbox"
    log_test "Install directory setting: $install_dir_setting"
  else
    assert_true "false" "default_install_directory should be configured"
  fi
}

# =============================================================================
# MAIN TEST EXECUTION
# =============================================================================

function main() {
  log_test "Starting configuration unit tests"

  # Initialize test environment
  setup_test

  # Execute all test functions
  test_configuration_files_existence
  test_configuration_files_readability
  test_configuration_structure
  test_environment_overrides
  test_systemd_disabled
  test_firewall_management_disabled
  test_configuration_syntax
  test_test_specific_settings
  test_directory_settings

  # Print summary and determine exit code
  if print_assert_summary "$TEST_NAME"; then
    pass_test "All configuration unit tests completed successfully"
  else
    fail_test "Some configuration unit tests failed"
  fi
}

# Execute main function
main "$@"
