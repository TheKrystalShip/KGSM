#!/usr/bin/env bash

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

# shellcheck disable=SC1091
source "$(dirname "$(readlink -f "$0")")/../lib/bootstrap.sh"

function usage() {
  local UNDERLINE="\e[4m"
  local END="\e[0m"

  echo -e "${UNDERLINE}Port Monitor Watcher for Krystal Game Server Manager${END}

Monitors network ports to detect when game server instances become ready for players.
Checks for port availability using netstat/ss to determine server readiness.

${UNDERLINE}Usage:${END}
  $(basename "$0") [OPTIONS] [COMMAND]

${UNDERLINE}Options:${END}
  -h, --help                  Display this help information

${UNDERLINE}Commands:${END}
  --watch <instance>          Start watching ports for readiness
                              Runs until port becomes active or timeout occurs
  --test <instance>           Test port monitoring configuration
                              Checks if configured ports are currently active
  --status <instance>         Show port watcher configuration status
                              Displays port list, monitoring strategy, and validation

${UNDERLINE}Configuration:${END}
  • ports                     UFW-style port definitions (pipe-separated)
  • Supports ranges (27015:27020/udp) and single ports (7777/tcp)
  • Monitors first port in the list for readiness detection
  • Checks every 5 seconds for port availability

${UNDERLINE}Examples:${END}
  $(basename "$0") --watch valheim-server-01
  $(basename "$0") --test factorio-space-age
  $(basename "$0") --status minecraft-survival

${UNDERLINE}Notes:${END}
  • Uses 'ss' command for efficient port monitoring
  • Monitors TCP and UDP ports simultaneously
  • Automatically stops when server process terminates
  • Exits with success when port becomes active
  • Supports multiple ports but monitors first one for readiness
  • Emits instance-ready event when port becomes available
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

# Helper function to extract the first port from UFW format
function _extract_first_port() {
  local ufw_ports="$1"

  # Split by | and get the first port definition
  local first_def
  first_def=$(echo "$ufw_ports" | cut -d'|' -f1)

  # Handle different formats:
  # Port range with protocol: 26900:26903/tcp -> 26900
  # Single port with protocol: 7777/udp -> 7777
  # Port range without protocol: 26900:26903 -> 26900
  # Single port without protocol: 22420 -> 22420

  if [[ "$first_def" =~ ^([0-9]+):([0-9]+)(/[a-z]+)?$ ]]; then
    # Port range - return start port
    echo "${BASH_REMATCH[1]}"
  elif [[ "$first_def" =~ ^([0-9]+)(/[a-z]+)?$ ]]; then
    # Single port - return the port
    echo "${BASH_REMATCH[1]}"
  else
    __print_error "Invalid port format: $first_def"
    return 1
  fi
}

# Core function: Execute port monitoring
function _execute_port_watch() {
  local instance="$1"
  local server_pid="$2"
  local port_to_check="$3"
  local timeout_seconds="${4:-600}"

  __print_info "Watching for port '$port_to_check' to become active"
  __print_info "Instance: '$instance', PID: $server_pid, Timeout: ${timeout_seconds}s"

  # Use timeout to enforce global timeout with port checking loop
  if timeout "${timeout_seconds}s" bash -c '
    local instance="$1"
    local server_pid="$2"
    local port_to_check="$3"

    while true; do
      # Check if server process is still running
      if ! kill -0 "$server_pid" 2>/dev/null; then
        echo "Server process stopped"
        exit 1
      fi

      # Check if port is active
      if ss -lntu | grep -q ":${port_to_check}\b"; then
        echo "Port is active"
        exit 0
      fi

      sleep 5
    done
  ' -- "$instance" "$server_pid" "$port_to_check"; then
    __print_success "Instance '$instance' is ready. Port '$port_to_check' is active."
    "$module_events" --emit --instance-ready "${instance%.ini}"
    return 0
  else
    local exit_code=$?
    if [[ $exit_code -eq 124 ]]; then
      __print_warning "Port watch for '$instance' timed out after ${timeout_seconds}s"
    elif [[ $exit_code -eq 1 ]]; then
      __print_info "Server process for '$instance' stopped. Aborting port watch."
    else
      __print_error "Port watch for '$instance' failed with exit code $exit_code"
    fi
    return $exit_code
  fi
}

# Watch for instance readiness using port monitoring
function _watch_instance() {
  local instance="$1"
  local timeout_seconds="${config_watcher_timeout_seconds:-600}"

  if [[ -z "$instance" ]]; then
    __print_error "Instance name is required"
    return ${EC_MISSING_ARG:-1}
  fi

  # Source the instance configuration
  __source_instance "$instance"

  # Validate ports are configured
  local all_ports="$instance_ports"
  if [[ -z "$all_ports" ]]; then
    __print_error "No ports configured for '$instance'"
    __print_error "Set 'ports' in the instance configuration"
    return 1
  fi

    # Get the first port for monitoring
  local first_port
  first_port=$(_extract_first_port "$all_ports")
  local extract_result=$?

  if [[ $extract_result -ne 0 || -z "$first_port" ]]; then
    __print_error "Failed to extract first port from configuration: '$all_ports'"
    return 1
  fi

  # Wait for PID file to be created (server startup)
  local server_pid
  local pid_file="$instance_pid_file"
  local pid_wait_timeout=10

  __print_info "Waiting for PID file: $pid_file"
  while [[ ! -f "$pid_file" && $pid_wait_timeout -gt 0 ]]; do
    sleep 1
    ((pid_wait_timeout--))
  done

  if [[ ! -f "$pid_file" ]]; then
    __print_error "PID file '$pid_file' was not created within timeout"
    return 1
  fi

  if ! server_pid=$(<"$pid_file" 2>/dev/null); then
    __print_error "Failed to read server PID from '$pid_file'"
    return 1
  fi

  __print_info "Server PID: $server_pid"
  __print_info "Monitoring port: $first_port"

  # Execute the port watch
  _execute_port_watch "$instance" "$server_pid" "$first_port" "$timeout_seconds"
  return $?
}

# Test port monitoring configuration
function _test_port_watch() {
  local instance="$1"

  if [[ -z "$instance" ]]; then
    __print_error "Instance name is required"
    return ${EC_MISSING_ARG:-1}
  fi

  __source_instance "$instance"

  local all_ports="$instance_ports"
  if [[ -z "$all_ports" ]]; then
    __print_error "No ports configured for '$instance'"
    __print_error "Set 'ports' in the instance configuration"
    return 1
  fi

    __print_info "Testing port monitoring for '$instance'"
  __print_info "Configured ports: $all_ports"

  # Check each port definition status
  local port_count=0
  local active_count=0

  # Split by | and process each port definition
  IFS='|' read -ra port_defs <<< "$all_ports"
  for port_def in "${port_defs[@]}"; do
    # Extract port number from this definition
    local port_num
    if [[ "$port_def" =~ ^([0-9]+):([0-9]+)(/[a-z]+)?$ ]]; then
      # Port range - check start port for simplicity
      port_num="${BASH_REMATCH[1]}"
      ((port_count++))
    elif [[ "$port_def" =~ ^([0-9]+)(/[a-z]+)?$ ]]; then
      # Single port
      port_num="${BASH_REMATCH[1]}"
      ((port_count++))
    else
      __print_warning "Invalid port definition: $port_def"
      continue
    fi

    if ss -lntu | grep -q ":${port_num}\b"; then
      __print_success "Port $port_num ($port_def): Active"
      ((active_count++))
    else
      __print_warning "Port $port_num ($port_def): Inactive"
    fi
  done

  echo ""
  if [[ $active_count -eq $port_count ]]; then
    __print_success "All $port_count ports are active!"
    return 0
  elif [[ $active_count -gt 0 ]]; then
    __print_warning "$active_count of $port_count ports are active"
    return 1
  else
    __print_warning "No ports are currently active"
    __print_info "This may be normal if the server isn't running"
    return 1
  fi
}

# Show port watcher configuration status
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

  echo -e "${BOLD}Port Monitor Watcher Status for '$instance'${END}"
  echo "============================================"
  echo ""

  # Configuration status
  echo -e "${BOLD}Configuration:${END}"
  local all_ports="$instance_ports"
  if [[ -n "$all_ports" ]]; then
    echo -e "  Ports: ${GREEN}$all_ports${END}"
    local first_port
    first_port=$(_extract_first_port "$all_ports")
    if [[ $? -eq 0 && -n "$first_port" ]]; then
      echo "  Primary port (monitored): $first_port"
    else
      echo "  Primary port (monitored): Invalid format"
    fi
  else
    echo -e "  Ports: ${RED}Not configured${END}"
    echo "    Configure 'ports' in instance configuration"
  fi

  echo "  Check interval: 5 seconds"
  echo "  Timeout: ${config_watcher_timeout_seconds:-600} seconds"
  echo ""

  # Dependencies
  echo -e "${BOLD}Dependencies:${END}"
  if command -v ss >/dev/null 2>&1; then
    echo -e "  ss command: ${GREEN}Available${END}"
  else
    echo -e "  ss command: ${RED}Missing${END}"
    echo "    Install with: sudo apt-get install iproute2"
  fi
  echo ""

  # Test current state
  if [[ -n "$all_ports" ]]; then
    echo -e "${BOLD}Current Port Status:${END}"
    # Split by | and process each port definition
    IFS='|' read -ra port_defs <<< "$all_ports"
    for port_def in "${port_defs[@]}"; do
      # Extract port number from this definition
      local port_num
      if [[ "$port_def" =~ ^([0-9]+):([0-9]+)(/[a-z]+)?$ ]]; then
        # Port range - check start port for simplicity
        port_num="${BASH_REMATCH[1]}"
      elif [[ "$port_def" =~ ^([0-9]+)(/[a-z]+)?$ ]]; then
        # Single port
        port_num="${BASH_REMATCH[1]}"
      else
        echo -e "  $port_def: ${RED}Invalid format${END}"
        continue
      fi

      if ss -lntu | grep -q ":${port_num}\b"; then
        echo -e "  Port $port_num ($port_def): ${GREEN}Active${END}"
      else
        echo -e "  Port $port_num ($port_def): ${YELLOW}Inactive${END}"
      fi
    done
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
