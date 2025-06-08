#!/usr/bin/env bash
#
# Test reporting utilities for KGSM testing framework

# Initialize test report variables
TEST_TOTAL=0
TEST_PASSED=0
TEST_FAILED=0
TEST_SKIPPED=0
TEST_START_TIME=0

export TEST_RESULTS_FILE="$TEST_ROOT/test-results.txt"

# Generate test report header
function report_init() {
  TEST_TOTAL=0
  TEST_PASSED=0
  TEST_FAILED=0
  TEST_SKIPPED=0

  {
    echo "====================================="
    echo "KGSM Test Report"
    echo "Generated: $(date)"
    echo "====================================="
    echo ""
  } >>"$TEST_RESULTS_FILE"
}

# Record test result
function report_test_result() {
  local test_name="$1"
  local result="$2" # 0=pass, 1=fail, 2=skip
  local duration="$3"
  local message="${4:-}"

  TEST_TOTAL=$((TEST_TOTAL + 1))

  case $result in
  0)
    TEST_PASSED=$((TEST_PASSED + 1))
    status="PASS"
    ;;
  1)
    TEST_FAILED=$((TEST_FAILED + 1))
    status="FAIL"
    ;;
  2)
    TEST_SKIPPED=$((TEST_SKIPPED + 1))
    status="SKIP"
    ;;
  esac

  # Add to report file
  {
    echo "Test: $test_name"
    echo "Status: $status"
    echo "Duration: ${duration}s"
    if [[ -n "$message" ]]; then
      echo "Message: $message"
    fi
    echo "-------------------------------------"
  } >>"$TEST_RESULTS_FILE"
}

# Generate summary report
function report_summary() {

  {
    echo ""
    echo "====================================="
    echo "Test Summary"
    echo "====================================="
    echo "Total Tests: $TEST_TOTAL"
    echo "Passed: $TEST_PASSED"
    echo "Failed: $TEST_FAILED"
    echo "Skipped: $TEST_SKIPPED"

    local success_rate=0
    if [[ $TEST_TOTAL -gt 0 ]]; then
      success_rate=$(((TEST_PASSED * 100) / TEST_TOTAL))
    fi

    echo "Success Rate: ${success_rate}%"
    echo "====================================="

  } >>"$TEST_RESULTS_FILE"

  # Copy report to log file
  cat "$TEST_RESULTS_FILE" >>"$LOG_FILE"

  # Print summary to console
  log_header "Test Report Summary"
  log_info "Total Tests: $TEST_TOTAL"
  log_success "Passed: $TEST_PASSED"
  log_error "Failed: $TEST_FAILED"
  log_warning "Skipped: $TEST_SKIPPED"
  log_info "Success Rate: ${success_rate}%"
}

# Start timing a test
function start_test_timer() {
  TEST_START_TIME=$(date +%s)
}

# End timing a test and return duration
function end_test_timer() {
  local end_time=$(date +%s)
  local duration=$((end_time - TEST_START_TIME))
  echo "$duration"
}

# Export functions
export -f report_init
export -f report_test_result
export -f report_summary
export -f start_test_timer
export -f end_test_timer
