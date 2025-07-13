#!/usr/bin/env bash

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

# shellcheck disable=SC1091
source "$(dirname "$(readlink -f "$0")")/../lib/bootstrap.sh"

function usage() {
  local UNDERLINE="\e[4m"
  local END="\e[0m"

  echo -e "${UNDERLINE}Log Pattern Watcher for Krystal Game Server Manager${END}

Monitors game server log files to detect when instances become ready for players.
Uses configurable regex patterns to match server startup completion messages.

${UNDERLINE}Usage:${END}
  $(basename "$0") [OPTIONS] [COMMAND]

${UNDERLINE}Options:${END}
  -h, --help                  Display this help information

${UNDERLINE}Commands:${END}
  --watch <instance>          Start watching log file for readiness pattern
                              Runs until pattern matches or timeout occurs
  --test <instance>           Test log pattern matching configuration
                              Checks if pattern exists in current log file
  --status <instance>         Show log watcher configuration status
                              Displays pattern, log file path, and validation

${UNDERLINE}Configuration:${END}
  • startup_success_regex     Regex pattern to match in log file
  • logs_dir                  Directory containing instance log files
  • Log file expected: {logs_dir}/latest.log

${UNDERLINE}Examples:${END}
  $(basename "$0") --watch valheim-server-01
  $(basename "$0") --test factorio-space-age
  $(basename "$0") --status minecraft-survival

${UNDERLINE}Notes:${END}
  • Monitors latest.log file in the instance logs directory
  • Uses 'tail -f' to follow log file in real-time
  • Automatically stops when server process terminates
  • Exits with success when pattern is found
  • Supports regex patterns for flexible matching
  • Emits instance-ready event when pattern matches
"
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
  -h | --help)
    usage && exit 0
    ;;
  *)
    break
    ;;
  esac
  shift
done

if [[ "$#" -eq 0 ]]; then
  __print_error "Missing arguments"
  usage
  exit ${EC_MISSING_ARG:-1}
fi

# Get the events module for emitting readiness events
module_events="$(__find_module events.sh)"

# Core function: Execute log pattern watching
function _execute_log_watch() {
  local instance="$1"
  local server_pid="$2"
  local ready_pattern="$3"
  local log_file="$4"
  local timeout_seconds="${5:-600}"
  local watcher_log_file="$6"

  __print_info_file_only "$watcher_log_file" "Watching log file '$log_file' for pattern '$ready_pattern'"
  __print_info_file_only "$watcher_log_file" "Instance: '$instance', PID: $server_pid, Timeout: ${timeout_seconds}s"

  # Use timeout to enforce global timeout and tail to follow the log
  if timeout "${timeout_seconds}s" bash -c '
    tail -n 50 -f --pid="$1" "$2" | grep --line-buffered -q -m 1 -e "$3"
  ' -- "$server_pid" "$log_file" "$ready_pattern"; then
    __print_success_file_only "$watcher_log_file" "Instance '$instance' is ready. Log pattern matched: '$ready_pattern'"
    "$module_events" --emit --instance-ready "${instance%.ini}"
    return 0
  else
    local exit_code=$?
    if [[ $exit_code -eq 124 ]]; then
      __print_warning_file_only "$watcher_log_file" "Log watch for '$instance' timed out after ${timeout_seconds}s"
    elif [[ $exit_code -eq 1 ]]; then
      __print_info_file_only "$watcher_log_file" "Server process for '$instance' stopped. Aborting log watch."
    else
      __print_error_file_only "$watcher_log_file" "Log watch for '$instance' failed with exit code $exit_code"
    fi
    return $exit_code
  fi
}

# Watch for instance readiness using log pattern matching
function _watch_instance() {
  local instance="$1"
  local timeout_seconds="${config_watcher_global_timeout_seconds:-600}"

  if [[ -z "$instance" ]]; then
    __print_error "Instance name is required"
    return ${EC_MISSING_ARG:-1}
  fi

  # Source the instance configuration
  __source_instance "$instance"

  # Create watcher log file path
  local watcher_log_file="$LOGS_SOURCE_DIR/watcher-${instance%.ini}.log"

  # Validate log pattern is configured
  local ready_pattern="$instance_startup_success_regex"
  if [[ -z "$ready_pattern" ]]; then
    __print_error_file_only "$watcher_log_file" "No log pattern configured for '$instance'"
    __print_error_file_only "$watcher_log_file" "Set 'startup_success_regex' in the instance configuration"
    return 1
  fi

  # Validate log file exists
  if [[ ! -f "$instance_log_file" ]]; then
    __print_error_file_only "$watcher_log_file" "Log file not found: $instance_log_file"
    __print_error_file_only "$watcher_log_file" "Instance may not be running or logs directory not configured"
    return 1
  fi

  # Wait for PID file to be created (server startup)
  local server_pid
  local pid_file="$instance_pid_file"
  local pid_wait_timeout=10

  __print_info_file_only "$watcher_log_file" "Waiting for PID file: $pid_file"
  while [[ ! -f "$pid_file" && $pid_wait_timeout -gt 0 ]]; do
    sleep 1
    ((pid_wait_timeout--))
  done

  if [[ ! -f "$pid_file" ]]; then
    __print_error_file_only "$watcher_log_file" "PID file '$pid_file' was not created within timeout"
    return 1
  fi

  # Wait a couple of seconds to make sure the server stores the PID
  sleep 2

  if ! server_pid=$(cat "$pid_file" 2>/dev/null); then
    __print_error_file_only "$watcher_log_file" "Failed to read server PID from '$pid_file'"
    return 1
  fi

  if [[ -z "$server_pid" ]]; then
    __print_error_file_only "$watcher_log_file" "Server PID is empty"
    return 1
  fi

  __print_info_file_only "$watcher_log_file" "Server PID: $server_pid"

  # Execute the log watch
  _execute_log_watch "$instance" "$server_pid" "$ready_pattern" "$instance_log_file" "$timeout_seconds" "$watcher_log_file"
  return $?
}

# Test log pattern matching configuration
function _test_log_watch() {
  local instance="$1"

  if [[ -z "$instance" ]]; then
    __print_error "Instance name is required"
    return ${EC_MISSING_ARG:-1}
  fi

  __source_instance "$instance"

  local ready_pattern="$instance_startup_success_regex"
  if [[ -z "$ready_pattern" ]]; then
    __print_error "No log pattern configured for '$instance'"
    __print_error "Set 'startup_success_regex' in the instance configuration"
    return 1
  fi

  if [[ ! -f "$instance_log_file" ]]; then
    __print_error "Log file not found: $instance_log_file"
    return 1
  fi

  __print_info "Testing log pattern matching for '$instance'"
  __print_info "Pattern: '$ready_pattern'"
  __print_info "Log file: '$instance_log_file'"

  # Check if pattern exists in current log
  if grep -q "$ready_pattern" "$instance_log_file"; then
    __print_success "Pattern found in log file!"
    return 0
  else
    __print_warning "Pattern not found in current log file"
    __print_info "This may be normal if the server hasn't started yet"
    return 1
  fi
}

# Show log watcher configuration status
function _show_status() {
  local instance="$1"

  if [[ -z "$instance" ]]; then
    __print_error "Instance name is required"
    return ${EC_MISSING_ARG:-1}
  fi

  __source_instance "$instance"

  local BOLD="\e[1m"
  local END="\e[0m"
  local GREEN="\e[32m"
  local RED="\e[31m"
  local YELLOW="\e[33m"

  echo -e "${BOLD}Log Pattern Watcher Status for '$instance'${END}"
  echo "========================================"
  echo ""

  # Configuration status
  echo -e "${BOLD}Configuration:${END}"
  local ready_pattern="$instance_startup_success_regex"
  if [[ -n "$ready_pattern" ]]; then
    echo -e "  Pattern: ${GREEN}$ready_pattern${END}"
  else
    echo -e "  Pattern: ${RED}Not configured${END}"
    echo "    Configure 'startup_success_regex' in instance configuration"
  fi

  echo "  Log file: $instance_log_file"
  if [[ -f "$instance_log_file" ]]; then
    echo -e "  Log file status: ${GREEN}Exists${END}"
    echo "  Log file size: $(du -h "$instance_log_file" | cut -f1)"
  else
    echo -e "  Log file status: ${RED}Missing${END}"
  fi

  echo "  Timeout: ${config_watcher_global_timeout_seconds:-600} seconds"
  echo ""

  # Test current state
  if [[ -n "$ready_pattern" && -f "$instance_log_file" ]]; then
    echo -e "${BOLD}Current State:${END}"
    if grep -q "$ready_pattern" "$instance_log_file"; then
      echo -e "  Pattern in log: ${GREEN}Found${END}"
    else
      echo -e "  Pattern in log: ${YELLOW}Not found${END}"
    fi
  fi
}

# Main argument processing
while [[ $# -gt 0 ]]; do
  case "$1" in
  --watch)
    shift
    if [[ -z "$1" ]]; then
      __print_error "Missing argument <instance>"
      exit ${EC_MISSING_ARG:-1}
    fi
    instance="$1"
    _watch_instance "$instance"
    exit $?
    ;;
  --test)
    shift
    if [[ -z "$1" ]]; then
      __print_error "Missing argument <instance>"
      exit ${EC_MISSING_ARG:-1}
    fi
    instance="$1"
    _test_log_watch "$instance"
    exit $?
    ;;
  --status)
    shift
    if [[ -z "$1" ]]; then
      __print_error "Missing argument <instance>"
      exit ${EC_MISSING_ARG:-1}
    fi
    instance="$1"
    _show_status "$instance"
    exit $?
    ;;
  *)
    __print_error "Invalid argument: $1"
    usage
    exit ${EC_INVALID_ARG:-1}
    ;;
  esac
  shift
done

exit $?
