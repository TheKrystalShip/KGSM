#!/usr/bin/env bash
#
# Main entry point for running KGSM tests

# We intentionally don't use 'set -e' because we want the script to continue
# even if individual tests fail

# Absolute path to this script
# shellcheck disable=SC2155
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
    if [[ -z "$1" ]]; then
      echo "ERROR: --test requires a file argument"
      exit 1
    fi
    SPECIFIC_TEST="$1"
    RUN_INTEGRATION=0
    RUN_E2E=0
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

# Prepare arguments for the runner
runner_args=()

# Add integration tests if enabled
if [[ "$RUN_INTEGRATION" -eq 1 ]]; then
  runner_args+=("--integration")
fi

# Add e2e tests if enabled
if [[ "$RUN_E2E" -eq 1 ]]; then
  runner_args+=("--e2e")
fi

# Add specific test if provided
if [[ -n "$SPECIFIC_TEST" ]]; then
  log_header "Running specific test: $SPECIFIC_TEST"
  runner_args+=("--test" "$SPECIFIC_TEST")
fi

# Add verbose flag if enabled
if [[ "$VERBOSE" -eq 1 ]]; then
  runner_args+=("--verbose")
fi

# Run the test runner with appropriate arguments
export total_tests passed_tests failed_tests
"$TEST_ROOT/framework/runner.sh" "${runner_args[@]}"

# Print test summary
log_header "Test Summary"
log_info "Total tests: $total_tests"
log_success "Passed tests: $passed_tests"
log_error "Failed tests: $failed_tests"
log_info "Detailed logs available at: $LOG_FILE"

# Exit code depends on whether all tests passed
# shellcheck disable=SC2046
exit $([[ "$failed_tests" -eq 0 ]] && echo 0 || echo 1)
