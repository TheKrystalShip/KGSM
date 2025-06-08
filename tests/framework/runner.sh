#!/usr/bin/env bash
#
# Test runner for KGSM testing framework

# Initialize test run
report_init

# Source framework
source "$TEST_ROOT/framework/common.sh" || {
  echo "Failed to source common.sh"
  exit 1
}

# Run specific test or discover tests based on parameters
if [[ "$1" == "--integration" ]]; then
  # Run integration tests
  log_header "Running Integration Tests"

  # Find all integration test files
  integration_tests=$(find "$TEST_ROOT/integration" -type f -name "test-*.sh" | sort)

  for test_file in $integration_tests; do
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
        result=1  # Fail
      else
        result=0  # Pass
      fi

      # Tear down test environment
      teardown_test_environment

      # Report test result
      log_test_result "$test_name" "$result" "$duration"
      report_test_result "$test_name" "$result" "$duration" "Assertions: $assertion_count, Failed: $failed_assertions"

      # Return result without stopping test execution
      return $result
    )
    test_result=$?

    # Update global counters
    if [[ "$test_result" -eq 0 ]]; then
      passed_tests=$((passed_tests + 1))
    else
      failed_tests=$((failed_tests + 1))
    fi
    total_tests=$((total_tests + 1))
  done

elif [[ "$1" == "--e2e" ]]; then
  # Run end-to-end tests
  log_header "Running End-to-End Tests"

  # Find all e2e test files
  e2e_tests=$(find "$TEST_ROOT/e2e" -type f -name "test-*.sh" | sort)

  for test_file in $e2e_tests; do
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
      source "$test_file"
      test_exit_code=$?

      # Get test duration
      duration=$(end_test_timer)

      # Get assertion stats
      read -r assertion_count failed_assertions < <(get_assertion_stats)

      # Calculate overall test result
      if [[ "$test_exit_code" -ne 0 || "$failed_assertions" -gt 0 ]]; then
        result=1  # Fail
      else
        result=0  # Pass
      fi

      # Tear down test environment
      teardown_test_environment

      # Report test result
      log_test_result "$test_name" "$result" "$duration"
      report_test_result "$test_name" "$result" "$duration" "Assertions: $assertion_count, Failed: $failed_assertions"

      # Return result without stopping test execution
      return $result
    )
    test_result=$?

    # Update global counters
    if [[ "$test_result" -eq 0 ]]; then
      passed_tests=$((passed_tests + 1))
    else
      failed_tests=$((failed_tests + 1))
    fi
    total_tests=$((total_tests + 1))
  done

else
  # Run specific test
  test_file="$1"

  # Check if test file exists
  if [[ ! -f "$test_file" ]]; then
    # Try to find it in test directories
    potential_files=(
      "$TEST_ROOT/integration/$test_file"
      "$TEST_ROOT/e2e/$test_file"
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
      exit 1
    fi
  fi

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
    source "$test_file"
    test_exit_code=$?

    # Get test duration
    duration=$(end_test_timer)

    # Get assertion stats
    read -r assertion_count failed_assertions < <(get_assertion_stats)

    # Calculate overall test result
    if [[ "$test_exit_code" -ne 0 || "$failed_assertions" -gt 0 ]]; then
      result=1  # Fail
    else
      result=0  # Pass
    fi

    # Tear down test environment
    teardown_test_environment

    # Report test result
    log_test_result "$test_name" "$result" "$duration"
    report_test_result "$test_name" "$result" "$duration" "Assertions: $assertion_count, Failed: $failed_assertions"

    # Return result without stopping test execution
      return $result
  )
  test_result=$?

  # Update global counters
  if [[ "$test_result" -eq 0 ]]; then
    passed_tests=$((passed_tests + 1))
  else
    failed_tests=$((failed_tests + 1))
  fi
  total_tests=$((total_tests + 1))
fi

# Generate report summary
report_summary

# Return success if all tests passed
exit $([[ "$failed_tests" -eq 0 ]])
