#!/usr/bin/env bash
#
# Common utilities for KGSM testing framework

# Disable shellcheck warnings for sourced files
# shellcheck disable=SC1091

# We don't use 'set -e' because we want tests to continue even if some fail
# Only use 'set -o pipefail' to catch errors in pipelines
set -o pipefail

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Load required framework components
export FRAMEWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Logger import

source "$FRAMEWORK_DIR/logger.sh" || {
  echo "${RED}ERROR: Failed to source logger.sh${NC}"
  exit 1
}

# Assertion import
source "$FRAMEWORK_DIR/assert.sh" || {
  log_error "Failed to source assert.sh"
  exit 1
}

# Environment setup import
source "$FRAMEWORK_DIR/env-setup.sh" || {
  log_error "Failed to source env-setup.sh"
  exit 1
}

# Report utilities import
source "$FRAMEWORK_DIR/report.sh" || {
  log_error "Failed to source report.sh"
  exit 1
}

# Global variables
export TEST_TIMEOUT=300  # 5 minutes default timeout for tests

# Check required dependencies
function check_dependencies() {
  local missing=0
  local required_deps=("grep" "jq" "wget" "unzip" "tar" "sed" "find")

  log_info "Checking required dependencies..."

  for dep in "${required_deps[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
      log_error "Required dependency not found: $dep"
      missing=1
    fi
  done

  if [[ "$missing" -eq 1 ]]; then
    log_error "Missing dependencies. Please install the required packages."
    exit 1
  else
    log_success "All required dependencies are available."
  fi
}

# Function to run a test with timeout
function run_with_timeout() {
  local timeout=$1
  local cmd="${@:2}"

  # Create a background process
  (
    # Start subshell with its own error handling
    set +e

    # Execute the command
    $cmd
    exit $?
  ) & pid=$!

  # Timer loop
  local start_time=$(date +%s)
  local end_time=$((start_time + timeout))

  while [[ $(date +%s) -lt $end_time ]]; do
    if ! kill -0 $pid 2> /dev/null; then
      # Process has finished
      wait $pid
      return $?
    fi
    sleep 1
  done

  # If we get here, the process timed out
  log_error "Command timed out after $timeout seconds"
  kill -9 $pid &> /dev/null || true
  wait $pid &> /dev/null || true
  return 124  # Standard timeout exit code
}

# Execute a command within the test environment
function in_test_environment() {
  if [[ ! -d "$TEST_ENV_DIR" ]]; then
    log_error "Test environment does not exist. Call create_test_environment first."
    return 1
  fi

  cd "$TEST_ENV_DIR" || {
    log_error "Failed to change to test environment directory: $TEST_ENV_DIR"
    return 1
  }

  "$@"
  return $?
}

# Export functions
export -f check_dependencies
export -f cleanup_test_environment
export -f run_with_timeout
export -f in_test_environment
