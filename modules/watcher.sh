#!/usr/bin/env bash

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

# shellcheck disable=SC1091
source "$(dirname "$(readlink -f "$0")")/../lib/bootstrap.sh"

function usage() {
  local UNDERLINE="\e[4m"
  local END="\e[0m"

  echo -e "${UNDERLINE}Instance Readiness Watcher for Krystal Game Server Manager${END}

Monitors game server instances to detect when they become ready for players.
Supports multiple detection strategies including log pattern matching and port monitoring.

${UNDERLINE}Usage:${END}
  $(basename "$0") [OPTIONS] [COMMAND]

${UNDERLINE}Options:${END}
  -h, --help                  Display this help information

${UNDERLINE}Commands:${END}
  --start-watch <instance>    Launch a detached background process to watch for instance readiness
                              Automatically selects the appropriate strategy based on instance configuration
  --test-log-watch <instance> Test log pattern matching strategy for the specified instance
                              Useful for debugging startup detection patterns
  --test-port-watch <instance> Test port monitoring strategy for the specified instance
                              Useful for debugging port availability detection
  --status <instance>         Show watcher configuration status for the specified instance
                              Displays available strategies and current configuration

${UNDERLINE}Detection Strategies:${END}
  ${UNDERLINE}Log Pattern Matching (Primary):${END}
    • Monitors the instance log file for a specific success pattern
    • Uses startup_success_regex configuration value
    • Provides immediate feedback when the server reports readiness
    • Recommended for most game servers that log startup completion

  ${UNDERLINE}Port Monitoring (Fallback):${END}
    • Monitors network ports for availability
    • Uses UFW-style port definitions (e.g., 7777/udp|27015:27020/tcp)
    • Monitors first port from ports configuration
    • Checks port binding every 5 seconds
    • Used when no log pattern is configured

${UNDERLINE}Timeout and Monitoring:${END}
  • Global timeout: ${config_watcher_timeout_seconds:-600} seconds (configurable)
  • Runs as detached background process
  • Automatically cleans up if server process terminates
  • Emits instance-ready event when detection succeeds

${UNDERLINE}Examples:${END}
  $(basename "$0") --start-watch valheim-server-01
  $(basename "$0") --test-log-watch factorio-space-age
  $(basename "$0") --test-port-watch minecraft-survival
  $(basename "$0") --status minecraft-survival

${UNDERLINE}Notes:${END}
  • Watcher processes run independently of the calling process
  • Only one strategy is used per instance (log pattern takes precedence)
  • Timeout values are configurable via KGSM configuration
  • Failed detection attempts are logged with appropriate warnings
  • Events are emitted to the KGSM event system upon successful detection
  • Use specific test commands to debug individual strategies
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

# Get watcher sub-modules
module_watcher_logs="$(__find_module watcher.logs.sh)"
module_watcher_ports="$(__find_module watcher.ports.sh)"

# Determine the appropriate watcher strategy for an instance
function _determine_strategy() {
  local instance="$1"

  if [[ -z "$instance" ]]; then
    __print_error "Instance name is required"
    return ${EC_MISSING_ARG:-1}
  fi

  # Source the instance configuration
  __source_instance "$instance"

  local ready_pattern="$instance_startup_success_regex"
  local all_ports="$instance_ports"

  # Strategy 1: Log Pattern Matching (preferred)
  if [[ -n "$ready_pattern" ]]; then
    echo "logs"
    return 0
  fi

  # Strategy 2: Port Monitoring (fallback)
  if [[ -n "$all_ports" ]]; then
    echo "ports"
    return 0
  fi

  # No strategy available
  __print_error "No readiness detection strategy configured for '$instance'"
  __print_error "Configure either 'startup_success_regex' or 'ports'"
  return 1
}

# Main watcher function that launches the appropriate strategy
function _start_watch() {
  local instance="$1"

  if [[ -z "$instance" ]]; then
    __print_error "Instance name is required"
    return ${EC_MISSING_ARG:-1}
  fi

  # Determine which strategy to use
  local strategy
  strategy=$(_determine_strategy "$instance")
  local result=$?

  if [[ $result -ne 0 ]]; then
    return $result
  fi

  __print_info "Starting readiness watcher for '$instance' using $strategy strategy"

  # Launch the watcher in a detached background process
  case "$strategy" in
  logs)
    (
      "$module_watcher_logs" --watch "$instance"
    ) &
    disown
    ;;
  ports)
    (
      "$module_watcher_ports" --watch "$instance"
    ) &
    disown
    ;;
  *)
    __print_error "Unknown strategy: $strategy"
    return 1
    ;;
  esac

  __print_success "Detached readiness watcher for '$instance' has been launched"
  return 0
}

# Test log pattern matching strategy
function _test_log_watch() {
  local instance="$1"

  if [[ -z "$instance" ]]; then
    __print_error "Instance name is required"
    return ${EC_MISSING_ARG:-1}
  fi

  # Delegate to log watcher module
  "$module_watcher_logs" --test "$instance"
  return $?
}

# Test port monitoring strategy
function _test_port_watch() {
  local instance="$1"

  if [[ -z "$instance" ]]; then
    __print_error "Instance name is required"
    return ${EC_MISSING_ARG:-1}
  fi

  # Delegate to port watcher module
  "$module_watcher_ports" --test "$instance"
  return $?
}

# Show watcher configuration status
function _show_status() {
  local instance="$1"

  if [[ -z "$instance" ]]; then
    __print_error "Instance name is required"
    return ${EC_MISSING_ARG:-1}
  fi

  # Source the instance configuration
  __source_instance "$instance"

  local BOLD="\e[1m"
  local END="\e[0m"
  local GREEN="\e[32m"
  local RED="\e[31m"
  local YELLOW="\e[33m"

  echo -e "${BOLD}Instance Readiness Watcher Status for '$instance'${END}"
  echo "=================================================="
  echo ""

  # Show which strategy would be used
  echo -e "${BOLD}Strategy Selection:${END}"
  local strategy
  strategy=$(_determine_strategy "$instance" 2>/dev/null)
  local result=$?

  if [[ $result -eq 0 ]]; then
    echo -e "  Selected strategy: ${GREEN}$strategy${END}"
  else
    echo -e "  Selected strategy: ${RED}None configured${END}"
  fi

  echo ""

  # Show configuration for both strategies
  echo -e "${BOLD}Log Pattern Strategy:${END}"
  local ready_pattern="$instance_startup_success_regex"
  if [[ -n "$ready_pattern" ]]; then
    echo -e "  Status: ${GREEN}Configured${END}"
    echo "  Pattern: $ready_pattern"
  else
    echo -e "  Status: ${RED}Not configured${END}"
  fi

  echo ""

  echo -e "${BOLD}Port Monitoring Strategy:${END}"
  local all_ports="$instance_ports"
  if [[ -n "$all_ports" ]]; then
    echo -e "  Status: ${GREEN}Configured${END}"
    echo "  Ports: $all_ports"
  else
    echo -e "  Status: ${RED}Not configured${END}"
  fi

  echo ""

  # Global configuration
  echo -e "${BOLD}Global Configuration:${END}"
  echo "  Timeout: ${config_watcher_timeout_seconds:-600} seconds"

  echo ""

  # Show detailed status for the selected strategy
  if [[ $result -eq 0 ]]; then
    echo -e "${BOLD}Selected Strategy Details:${END}"
    case "$strategy" in
    logs)
      "$module_watcher_logs" --status "$instance"
      ;;
    ports)
      "$module_watcher_ports" --status "$instance"
      ;;
    esac
  else
    echo -e "${BOLD}Configuration Required:${END}"
    echo "  Configure either 'startup_success_regex' or 'ports' in the instance configuration"
  fi
}

# Main argument processing
while [[ $# -gt 0 ]]; do
  case "$1" in
  --start-watch)
    shift
    if [[ -z "$1" ]]; then
      __print_error "Missing argument <instance>"
      exit ${EC_MISSING_ARG:-1}
    fi
    instance="$1"
    _start_watch "$instance"
    exit $?
    ;;
  --test-log-watch)
    shift
    if [[ -z "$1" ]]; then
      __print_error "Missing argument <instance>"
      exit ${EC_MISSING_ARG:-1}
    fi
    instance="$1"
    _test_log_watch "$instance"
    exit $?
    ;;
  --test-port-watch)
    shift
    if [[ -z "$1" ]]; then
      __print_error "Missing argument <instance>"
      exit ${EC_MISSING_ARG:-1}
    fi
    instance="$1"
    _test_port_watch "$instance"
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
