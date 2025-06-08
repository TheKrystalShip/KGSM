#!/usr/bin/env bash
#
# Logger utilities for KGSM testing framework

# Logging functions
function log_header() {
  local message="$1"

  echo -e "\n${BOLD}${BLUE}=== $message ===${NC}"

  # Also log to file
  echo -e "\n=== $message ===" >> "$LOG_FILE"
}

function log_info() {
  local message="$1"

  echo -e "${BLUE}INFO:${NC} $message"

  # Also log to file
  echo "[INFO] $message" >> "$LOG_FILE"
}

function log_success() {
  local message="$1"

  echo -e "${GREEN}SUCCESS:${NC} $message"

  # Also log to file
  echo "[SUCCESS] $message" >> "$LOG_FILE"
}

function log_warning() {
  local message="$1"

  echo -e "${YELLOW}WARNING:${NC} $message"

  # Also log to file
  echo "[WARNING] $message" >> "$LOG_FILE"
}

function log_error() {
  local message="$1"

  echo -e "${RED}ERROR:${NC} $message" >&2

  # Also log to file
  echo "[ERROR] $message" >> "$LOG_FILE"
}

function log_test_start() {
  local test_name="$1"

  echo -e "\n${BOLD}Running test:${NC} ${BLUE}$test_name${NC}"

  # Also log to file
  echo -e "\n[TEST START] $test_name" >> "$LOG_FILE"
}

function log_test_result() {
  local test_name="$1"
  local result="$2"
  local duration="$3"

  if [[ "$result" -eq 0 ]]; then
    echo -e "${GREEN}✓ PASS:${NC} $test_name ${BLUE}(${duration}s)${NC}"
    echo "[TEST PASS] $test_name (${duration}s)" >> "$LOG_FILE"
  else
    echo -e "${RED}✗ FAIL:${NC} $test_name ${BLUE}(${duration}s)${NC}"
    echo "[TEST FAIL] $test_name (${duration}s)" >> "$LOG_FILE"
  fi
}

function log_test_output() {
  local output="$1"

  if [[ "$VERBOSE" -eq 1 ]]; then
    # Display output in terminal
    echo -e "$output"
  fi

  # Always log output to file
  echo -e "$output" >> "$LOG_FILE"
}

# Export functions
export -f log_header
export -f log_info
export -f log_success
export -f log_warning
export -f log_error
export -f log_test_start
export -f log_test_result
export -f log_test_output
