#!/usr/bin/env bash
#
# Main entry point for running KGSM tests

# We intentionally don't use 'set -e' because we want the script to continue
# even if individual tests fail

# Absolute path to this script
export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TEST_ROOT="$SCRIPT_DIR"
export KGSM_ROOT="$(dirname "$TEST_ROOT")"
export LOG_FILE="$TEST_ROOT/logs/test-$(date +%Y%m%d-%H%M%S).log"

# Import common testing utilities
# shellcheck disable=SC1091
source "$TEST_ROOT/framework/common.sh" || {
  echo "ERROR: Failed to source common.sh"
  exit 1
}

# Initialize log file
{
  echo "KGSM Testing Framework"
  echo "======================"
  echo "Started: $(date)"
  echo "KGSM Root: $KGSM_ROOT"
  echo "Test Root: $TEST_ROOT"
  echo
} >"$LOG_FILE"

function usage() {
  echo "KGSM Testing Framework"
  echo
  echo "Usage:"
  echo "  $(basename "$0") [OPTIONS]"
  echo
  echo "Options:"
  echo "  --help           Display this help message"
  echo "  --integration    Run only integration tests"
  echo "  --e2e            Run only end-to-end tests"
  echo "  --test FILE      Run a specific test file"
  echo "  --verbose        Show verbose output"
  echo "  --no-cleanup     Don't clean up test environment after tests"
  echo
}

# Parse arguments
export RUN_INTEGRATION=1
export RUN_E2E=1
export SPECIFIC_TEST=""
export VERBOSE=0
export NO_CLEANUP=0

while [[ "$#" -gt 0 ]]; do
  case "$1" in
  --help)
    usage
    exit 0
    ;;
  --integration)
    RUN_INTEGRATION=1
    RUN_E2E=0
    ;;
  --e2e)
    RUN_INTEGRATION=0
    RUN_E2E=1
    ;;
  --test)
    shift
    SPECIFIC_TEST="$1"
    ;;
  --verbose)
    VERBOSE=1
    ;;
  --no-cleanup)
    NO_CLEANUP=1
    ;;
  *)
    echo "Unknown option: $1"
    usage
    exit 1
    ;;
  esac
  shift
done

# Print intro header
log_header "KGSM Test Runner"
log_info "Starting test run at $(date)"
log_info "KGSM Root: $KGSM_ROOT"
log_info "Test Root: $TEST_ROOT"
log_info "Log File: $LOG_FILE"

# Record dependency versions
log_header "Environment Information"
bash_version=$(bash --version | head -n 1)
log_info "Bash: $bash_version"

# Dependency check
check_dependencies

# Initialize test stats
export total_tests=0
export passed_tests=0
export failed_tests=0

# Run the test runner with appropriate arguments
if [[ -n "$SPECIFIC_TEST" ]]; then
  log_header "Running specific test: $SPECIFIC_TEST"
  source "$TEST_ROOT/framework/runner.sh" "$SPECIFIC_TEST"
else
  # Create an array to track which types of tests to run
  test_types=()

  # Add integration tests if enabled
  if [[ "$RUN_INTEGRATION" -eq 1 ]]; then
    test_types+=("--integration")
  fi

  # Add e2e tests if enabled
  if [[ "$RUN_E2E" -eq 1 ]]; then
    test_types+=("--e2e")
  fi

  # Run each test type
  for test_type in "${test_types[@]}"; do
    source "$TEST_ROOT/framework/runner.sh" "$test_type"

    # If this isn't the last test type, preserve the counters
    # to avoid them being reset by the next runner.sh invocation
    if [[ "$test_type" != "${test_types[-1]}" ]]; then
      export total_tests
      export passed_tests
      export failed_tests
    fi
  done
fi

# Print test summary
log_header "Test Summary"
log_info "Total tests: $total_tests"
log_success "Passed tests: $passed_tests"
log_error "Failed tests: $failed_tests"
log_info "Detailed logs available at: $LOG_FILE"

# Exit code depends on whether all tests passed
[[ "$failed_tests" -eq 0 ]]
