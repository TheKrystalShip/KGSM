#!/usr/bin/env bash
#
# Assertion library for KGSM testing framework

# Track assertion counts
export ASSERTION_COUNT=0
export FAILED_ASSERTIONS=0

# Functions for assertions

# Assert that a condition is true
function assert_true() {
  local condition="$1"
  local message="${2:-Expected condition to be true: $condition}"

  ASSERTION_COUNT=$((ASSERTION_COUNT + 1))

  if eval "$condition"; then
    [[ "$VERBOSE" -eq 1 ]] && log_info "Assertion passed: $message (evaluated to true)"
    return 0
  else
    log_error "Assertion failed: $message (evaluated to false)"
    FAILED_ASSERTIONS=$((FAILED_ASSERTIONS + 1))
    return 1
  fi
}

# Assert that a condition is false
function assert_false() {
  local condition="$1"
  local message="${2:-Expected condition to be false: $condition}"

  ASSERTION_COUNT=$((ASSERTION_COUNT + 1))

  if ! eval "$condition"; then
    [[ "$VERBOSE" -eq 1 ]] && log_info "Assertion passed: $message (evaluated to false)"
    return 0
  else
    log_error "Assertion failed: $message (evaluated to true)"
    FAILED_ASSERTIONS=$((FAILED_ASSERTIONS + 1))
    return 1
  fi
}

# Assert that two values are equal
function assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="${3:-Expected '$expected' but got '$actual'}"

  ASSERTION_COUNT=$((ASSERTION_COUNT + 1))

  if [[ "$expected" == "$actual" ]]; then
    [[ "$VERBOSE" -eq 1 ]] && log_info "Assertion passed: Values are equal (expected: '$expected', actual: '$actual')"
    return 0
  else
    log_error "Assertion failed: $message (expected: '$expected', actual: '$actual')"
    FAILED_ASSERTIONS=$((FAILED_ASSERTIONS + 1))
    return 1
  fi
}

# Assert that two values are not equal
function assert_not_equals() {
  local expected="$1"
  local actual="$2"
  local message="${3:-Expected value to differ from '$expected'}"

  ASSERTION_COUNT=$((ASSERTION_COUNT + 1))

  if [[ "$expected" != "$actual" ]]; then
    [[ "$VERBOSE" -eq 1 ]] && log_info "Assertion passed: Values are not equal (unexpected: '$expected', actual: '$actual')"
    return 0
  else
    log_error "Assertion failed: $message (unexpected: '$expected', actual: '$actual' - values are identical)"
    FAILED_ASSERTIONS=$((FAILED_ASSERTIONS + 1))
    return 1
  fi
}

# Assert that a file exists
function assert_file_exists() {
  local file="$1"
  local message="${2:-Expected file to exist: $file}"

  ASSERTION_COUNT=$((ASSERTION_COUNT + 1))

  if [[ -f "$file" ]]; then
    [[ "$VERBOSE" -eq 1 ]] && log_info "Assertion passed: File exists: $file"
    return 0
  else
    log_error "Assertion failed: $message (file '$file' does not exist)"
    FAILED_ASSERTIONS=$((FAILED_ASSERTIONS + 1))
    return 1
  fi
}

# Assert that a directory exists
function assert_directory_exists() {
  local directory="$1"
  local message="${2:-Expected directory to exist: $directory}"

  ASSERTION_COUNT=$((ASSERTION_COUNT + 1))

  if [[ -d "$directory" ]]; then
    [[ "$VERBOSE" -eq 1 ]] && log_info "Assertion passed: Directory exists: $directory"
    return 0
  else
    log_error "Assertion failed: $message (directory '$directory' does not exist)"
    FAILED_ASSERTIONS=$((FAILED_ASSERTIONS + 1))
    return 1
  fi
}

# Assert that a command succeeds (returns 0)
function assert_command_success() {
  local command="$1"
  local message="${2:-Expected command to succeed: $command}"

  ASSERTION_COUNT=$((ASSERTION_COUNT + 1))

  # Store command output for error reporting
  local output
  output=$(eval "$command" 2>&1)
  local status=$?

  if [[ $status -eq 0 ]]; then
    [[ "$VERBOSE" -eq 1 ]] && log_info "Assertion passed: Command succeeded: $command (exit code: $status)"
    return 0
  else
    log_error "Assertion failed: $message (expected exit code: 0, actual: $status)"
    log_error "Command output: $output"
    FAILED_ASSERTIONS=$((FAILED_ASSERTIONS + 1))
    return 1
  fi
}

# Assert that a command fails (returns non-zero)
function assert_command_fails() {
  local command="$1"
  local message="${2:-Expected command to fail: $command}"

  ASSERTION_COUNT=$((ASSERTION_COUNT + 1))

  # Store command output for error reporting
  local output
  output=$(eval "$command" 2>&1) || true
  local status=$?

  if [[ $status -ne 0 ]]; then
    [[ "$VERBOSE" -eq 1 ]] && log_info "Assertion passed: Command failed as expected: $command (exit code: $status)"
    return 0
  else
    log_error "Assertion failed: $message (expected non-zero exit code, actual: 0)"
    log_error "Command output: $output"
    FAILED_ASSERTIONS=$((FAILED_ASSERTIONS + 1))
    return 1
  fi
}

# Assert that a string contains a substring
function assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-Expected '$haystack' to contain '$needle'}"

  ASSERTION_COUNT=$((ASSERTION_COUNT + 1))

  if [[ "$haystack" == *"$needle"* ]]; then
    [[ "$VERBOSE" -eq 1 ]] && log_info "Assertion passed: String contains expected substring (searching for: '$needle', in: '$haystack')"
    return 0
  else
    log_error "Assertion failed: $message (substring '$needle' not found in '$haystack')"
    FAILED_ASSERTIONS=$((FAILED_ASSERTIONS + 1))
    return 1
  fi
}

# Assert that a process is running
function assert_process_running() {
  local process_name="$1"
  local message="${2:-Expected process to be running: $process_name}"

  ASSERTION_COUNT=$((ASSERTION_COUNT + 1))

  local processes
  processes=$(pgrep -f "$process_name" 2>/dev/null | wc -l)

  if [[ $processes -gt 0 ]]; then
    [[ "$VERBOSE" -eq 1 ]] && log_info "Assertion passed: Process is running: $process_name (found $processes instances)"
    return 0
  else
    log_error "Assertion failed: $message (process '$process_name' not found in process list)"
    FAILED_ASSERTIONS=$((FAILED_ASSERTIONS + 1))
    return 1
  fi
}

# Reset assertion counters
function reset_assertions() {
  ASSERTION_COUNT=0
  FAILED_ASSERTIONS=0
}

# Get assertion statistics
function get_assertion_stats() {
  echo "$ASSERTION_COUNT $FAILED_ASSERTIONS"
}

# Export functions
export -f assert_true
export -f assert_false
export -f assert_equals
export -f assert_not_equals
export -f assert_file_exists
export -f assert_directory_exists
export -f assert_command_success
export -f assert_command_fails
export -f assert_contains
export -f assert_process_running
export -f reset_assertions
export -f get_assertion_stats
