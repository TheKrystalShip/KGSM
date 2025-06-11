#!/usr/bin/env bash
#
# Test runner for KGSM testing framework

function usage() {
  echo "KGSM Test Runner

Usage:
  $(basename "$0") [OPTIONS]

Options:
  -h, --help              Display this help message
  --unit                  Run unit tests
  --integration           Run integration tests
  --e2e                   Run end-to-end tests
  --test <file>           Run a specific test file
  --verbose               Enable verbose output

Examples:
  $(basename "$0") --unit
  $(basename "$0") --integration
  $(basename "$0") --e2e
  $(basename "$0") --test unit/test-parser.sh
"
}

# Source framework if being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # This script is being run directly, not sourced
  # Initialize variables that would normally be set by the parent
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  TEST_ROOT="$(dirname "$SCRIPT_DIR")"
  KGSM_ROOT="$(dirname "$TEST_ROOT")"

  # Import common testing utilities
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/common.sh" || {
    echo "ERROR: Failed to source common.sh"
    exit 1
  }

  # Initialize counters
  total_tests=0
  passed_tests=0
  failed_tests=0
else
  # This script is being sourced, assume environment is set up
  [[ -z "$TEST_ROOT" ]] && echo "ERROR: TEST_ROOT not set" && exit 1

  # Ensure common.sh is loaded
  if [[ -z "$FRAMEWORK_DIR" ]]; then
    # shellcheck disable=SC1091
    source "$TEST_ROOT/framework/common.sh" || {
      echo "ERROR: Failed to source common.sh"
      exit 1
    }
  fi
fi

# Variables to hold options
RUN_INTEGRATION=0
RUN_E2E=0
SPECIFIC_TEST=""
VERBOSE=0

# Function to run a single test
function _run_test() {
  local test_file="$1"
  local test_name

  test_name=$(basename "$test_file" .sh)
  log_test_start "$test_name"

  # Run test in a subshell to isolate it
  (
    # Reset assertion counters
    reset_assertions

    # Setup test environment
    setup_test_environment "$test_name"

    # Start timer
    start_test_timer

    # Run the test file
    # shellcheck disable=SC1090
    source "$test_file"
    test_exit_code=$?

    # Get test duration
    duration=$(end_test_timer)

    # Get assertion stats
    read -r assertion_count failed_assertions < <(get_assertion_stats)

    # Calculate overall test result
    if [[ "$test_exit_code" -ne 0 || "$failed_assertions" -gt 0 ]]; then
      result=1 # Fail
    else
      result=0 # Pass
    fi

    # Tear down test environment
    teardown_test_environment

    # Report test result
    log_test_result "$test_name" "$result" "$duration"
    report_test_result "$test_name" "$result" "$duration" "Assertions: $assertion_count, Failed: $failed_assertions"

    # Return result without stopping test execution
    return $result
  )

  local test_result=$?

  # Update global counters
  if [[ "$test_result" -eq 0 ]]; then
    passed_tests=$((passed_tests + 1))
  else
    failed_tests=$((failed_tests + 1))
  fi
  total_tests=$((total_tests + 1))

  return $test_result
}

# Function to run integration tests
function _run_integration_tests() {
  log_header "Running Integration Tests"

  # Find all integration test files
  local integration_tests
  integration_tests=$(find "$TEST_ROOT/integration" -type f -name "test-*.sh" | sort)

  for test_file in $integration_tests; do
    _run_test "$test_file"
  done

  return 0
}

# Function to run end-to-end tests
function _run_e2e_tests() {
  log_header "Running End-to-End Tests"

  # Find all e2e test files
  local e2e_tests
  e2e_tests=$(find "$TEST_ROOT/e2e" -type f -name "test-*.sh" | sort)

  for test_file in $e2e_tests; do
    _run_test "$test_file"
  done

  return 0
}

# Function to run unit tests
function _run_unit_tests() {
  log_header "Running Unit Tests"

  # Find all unit test files
  local unit_tests
  unit_tests=$(find "$TEST_ROOT/unit" -type f -name "test-*.sh" | sort)

  for test_file in $unit_tests; do
    _run_test "$test_file"
  done

  return 0
}

# Function to run a specific test
function _run_specific_test() {
  local test_file="$1"

  # Check if test file exists
  if [[ ! -f "$test_file" ]]; then
    # Try to find it in test directories
    local potential_files=(
      "$TEST_ROOT/unit/$test_file"
      "$TEST_ROOT/integration/$test_file"
      "$TEST_ROOT/e2e/$test_file"
      "$TEST_ROOT/unit/test-$test_file.sh"
      "$TEST_ROOT/integration/test-$test_file.sh"
      "$TEST_ROOT/e2e/test-$test_file.sh"
      "$TEST_ROOT/unit/test-$test_file"
      "$TEST_ROOT/integration/test-$test_file"
      "$TEST_ROOT/e2e/test-$test_file"
    )

    for potential_file in "${potential_files[@]}"; do
      if [[ -f "$potential_file" ]]; then
        test_file="$potential_file"
        break
      fi
    done

    # If still not found
    if [[ ! -f "$test_file" ]]; then
      log_error "Test file not found: $1"
      return 1
    fi
  fi

  _run_test "$test_file"
  return $?
}

# Main execution function
function execute_tests() {
  # Initialize test run
  report_init

  if [[ "$RUN_UNIT" -eq 1 ]]; then
    _run_unit_tests
  fi

  if [[ "$RUN_INTEGRATION" -eq 1 ]]; then
    _run_integration_tests
  fi

  if [[ "$RUN_E2E" -eq 1 ]]; then
    _run_e2e_tests
  fi

  if [[ -n "$SPECIFIC_TEST" ]]; then
    _run_specific_test "$SPECIFIC_TEST"
  fi

  # Generate report summary
  report_summary

  # Return success if all tests passed
  [[ "$failed_tests" -eq 0 ]] && return 0 || return 1
}

# If no arguments, show usage
if [ "$#" -eq 0 ] && [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  usage
  exit 1
fi

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
  -h | --help)
    usage
    exit 0
    ;;
  --unit)
    RUN_UNIT=1
    ;;
  --integration)
    RUN_INTEGRATION=1
    ;;
  --e2e)
    RUN_E2E=1
    ;;
  --test)
    shift
    [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument for --test" >&2 && exit 1
    SPECIFIC_TEST="$1"
    ;;
  --verbose)
    VERBOSE=1
    export VERBOSE
    ;;
  *)
    echo "${0##*/} ERROR: Unknown option $1" >&2
    usage
    exit 1
    ;;
  esac
  shift
done

# Execute tests if script is being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  execute_tests
  exit $?
fi
