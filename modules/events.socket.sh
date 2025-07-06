#!/usr/bin/env bash

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

# shellcheck disable=SC1091
source "$(dirname "$(readlink -f "$0")")/../lib/bootstrap.sh"

function usage() {
  local UNDERLINE="\e[4m"
  local END="\e[0m"

  echo -e "${UNDERLINE}Unix Domain Socket Event Transport for Krystal Game Server Manager${END}

Manages Unix Domain Socket event broadcasting for local inter-process communication.

${UNDERLINE}Usage:${END}
  $(basename "$0") [OPTIONS] [COMMAND]

${UNDERLINE}Options:${END}
  -h, --help                  Display this help information

${UNDERLINE}Commands:${END}
  --enable                    Enable Unix Domain Socket event transport
                              Updates configuration and validates dependencies
  --disable                   Disable Unix Domain Socket event transport
                              Stops socket broadcasting and updates configuration
  --test                      Test socket functionality by sending a test event
                              Verifies socket creation and message transmission
  --status                    Show detailed socket transport status
                              Displays configuration, socket state, and dependencies

${UNDERLINE}Examples:${END}
  $(basename "$0") --enable
  $(basename "$0") --test
  $(basename "$0") --status
  $(basename "$0") --disable

${UNDERLINE}Notes:${END}
  • Socket transport requires 'socat' for message transmission
  • Socket file is created in \$KGSM_ROOT directory
  • Multiple processes can listen to the same socket
  • --enable: Activates transport and validates dependencies
  • --disable: Deactivates transport and cleans up resources
  • --test: Sends a test event to verify functionality
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
  exit ${EC_MISSING_ARG:-1}
fi

# Core function: Send event to socket (used by lib/events.sh)
function __socket_emit_event() {
  local payload="$1"
  local socket_file="$KGSM_ROOT/$config_event_socket_filename"

  if [[ -z "$payload" ]]; then
    __print_error "Event payload is required"
    return 1
  fi

  if [[ ! -e "$socket_file" ]]; then
    # Socket doesn't exist, but this is not an error for background emission
    return 0
  fi

  # Check if socat is available
  if ! command -v socat >/dev/null 2>&1; then
    __print_error "socat is required for socket events but is not installed"
    return 1
  fi

  # Send event to socket
  set +eo pipefail
  echo "$payload" | socat - UNIX-CONNECT:"$socket_file",reuseaddr
  local result=$?
  set -eo pipefail

  return $result
}

export -f __socket_emit_event

# Enable socket transport
function _socket_enable() {
  __print_info "Enabling Unix Domain Socket event transport..."

  # Check dependencies
  if ! command -v socat >/dev/null 2>&1; then
    __print_error "socat is required but not installed"
    __print_error "Install socat: sudo apt-get install socat (Ubuntu/Debian) or sudo yum install socat (RHEL/CentOS)"
    return $EC_MISSING_DEPENDENCY
  fi

  # Enable in configuration
  __set_config_value "enable_event_broadcasting" "true"
  local result=$?
  if [[ $result -eq 0 ]]; then
    __print_success "Unix Domain Socket event transport enabled"
    __print_info "Socket file will be created at: $KGSM_ROOT/${config_event_socket_filename:-kgsm.sock}"
    __print_info "Use --test to verify functionality"
  fi

  return $result
}

# Disable socket transport
function _socket_disable() {
  __print_info "Disabling Unix Domain Socket event transport..."

  # Disable in configuration
  __set_config_value "enable_event_broadcasting" "false"
  local result=$?
  if [[ $result -eq 0 ]]; then
    __print_success "Unix Domain Socket event transport disabled"

    # Clean up socket file if it exists
    local socket_file="$KGSM_ROOT/${config_event_socket_filename:-kgsm.sock}"
    if [[ -e "$socket_file" ]]; then
      __print_info "Removing existing socket file: $socket_file"
      rm -f "$socket_file" || __print_warning "Could not remove socket file"
    fi
  fi

  return $result
}

# Test socket functionality
function _socket_test() {
  __print_info "Testing Unix Domain Socket event transport..."

  # Check if enabled
  if [[ "$config_enable_event_broadcasting" != "true" ]]; then
    __print_error "Socket transport is not enabled"
    __print_error "Use --enable to activate socket transport first"
    return 1
  fi

  # Check dependencies
  if ! command -v socat >/dev/null 2>&1; then
    __print_error "socat is required but not installed"
    return $EC_MISSING_DEPENDENCY
  fi

  local socket_file="$KGSM_ROOT/$config_event_socket_filename"

  __print_info "Socket file: $socket_file"

  # Clean up any existing socket file
  if [[ -e "$socket_file" ]]; then
    rm -f "$socket_file"
  fi

  # Create a simple test by using the actual emit function
  local test_payload
  test_payload=$(
    jq -n \
      --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --arg hostname "$(hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || echo "${HOSTNAME:-localhost}")" \
      --arg kgsm_version "$(get_version 2>/dev/null || echo 'unknown')" \
      '{
        EventType: "socket_test",
        Data: {
          InstanceName: "test-instance",
          Message: "This is a test socket event from KGSM"
        },
        Timestamp: $timestamp,
        Hostname: $hostname,
        KGSMVersion: $kgsm_version
      }'
  )

  # Start a listener in the background to capture one message
  local test_output="/tmp/kgsm-socket-test-$$"

  # Start listener that will capture one message and exit
  timeout 5 socat UNIX-LISTEN:"$socket_file",fork - >"$test_output" &
  local listener_pid=$!

  # Give listener time to start
  sleep 1

  # Send test event
  if echo "$test_payload" | socat - UNIX-CONNECT:"$socket_file" 2>/dev/null; then
    # Give time for message to be received
    sleep 1

    # Stop listener
    kill $listener_pid 2>/dev/null || true
    wait $listener_pid 2>/dev/null || true

    # Check if we received the test message
    if [[ -f "$test_output" ]] && [[ -s "$test_output" ]]; then
      local received_event
      received_event=$(cat "$test_output")

      if echo "$received_event" | jq -e '.EventType == "socket_test"' >/dev/null 2>&1; then
        __print_success "Socket test completed successfully!"
        __print_info "Test event received and validated"
        rm -f "$test_output"
        rm -f "$socket_file"
        return 0
      else
        __print_error "Socket test failed: Invalid event format received"
        __print_error "Received: $received_event"
      fi
    else
      __print_error "Socket test failed: No event received"
    fi
  else
    __print_error "Socket test failed: Could not send test event"
  fi

  # Clean up
  kill $listener_pid 2>/dev/null || true
  wait $listener_pid 2>/dev/null || true
  rm -f "$test_output"
  rm -f "$socket_file"

  return 1
}

# Show socket status
function _socket_status() {
  local BOLD="\e[1m"
  local END="\e[0m"
  local GREEN="\e[32m"
  local RED="\e[31m"
  local YELLOW="\e[33m"

  echo -e "${BOLD}Unix Domain Socket Transport Status${END}"
  echo "===================================="
  echo ""

  # Configuration status
  echo -e "${BOLD}Configuration:${END}"
  if [[ "$config_enable_event_broadcasting" == "true" ]]; then
    echo -e "  Status: ${GREEN}Enabled${END}"
  else
    echo -e "  Status: ${RED}Disabled${END}"
  fi
  echo "  Socket file: $KGSM_ROOT/${config_event_socket_filename:-kgsm.sock}"
  echo ""

  # Dependencies
  echo -e "${BOLD}Dependencies:${END}"
  if command -v socat >/dev/null 2>&1; then
    echo -e "  socat: ${GREEN}Available${END} ($(socat -V 2>/dev/null | head -1 || echo 'version unknown'))"
  else
    echo -e "  socat: ${RED}Missing${END}"
    echo "    Install with: sudo apt-get install socat (Ubuntu/Debian)"
    echo "                 sudo yum install socat (RHEL/CentOS)"
  fi
  echo ""

  # Runtime status
  echo -e "${BOLD}Runtime Status:${END}"
  local socket_file="$KGSM_ROOT/${config_event_socket_filename:-kgsm.sock}"
  if [[ -e "$socket_file" ]]; then
    echo -e "  Socket file: ${GREEN}Exists${END}"
    echo "  Socket type: $(file "$socket_file" 2>/dev/null || echo 'Unknown')"
  else
    echo -e "  Socket file: ${YELLOW}Not present${END}"
    echo "    Socket will be created when first event is emitted"
  fi
}

# Handle --emit command (called by lib/events.sh)
function _socket_emit() {
  local payload="$1"
  __socket_emit_event "$payload"
  return $?
}

# Main argument processing
action=""
payload=""

while [[ $# -gt 0 ]]; do
  current_arg="$1"
  case "$current_arg" in
  --enable | --disable | --test | --status)
    if [[ -n "$action" ]]; then
      __print_error "Conflicting commands. Only one action command is allowed at a time."
      exit $EC_INVALID_ARG
    fi
    action="$current_arg"
    ;;
  --emit)
    if [[ -n "$action" ]]; then
      __print_error "Conflicting commands. Only one action command is allowed at a time."
      exit $EC_INVALID_ARG
    fi
    action="$current_arg"
    shift
    if [[ -z "$1" ]]; then
      __print_error "Missing event payload for --emit"
      exit $EC_MISSING_ARG
    fi
    payload="$1"
    ;;
  *)
    __print_error "Invalid argument: $current_arg"
    exit $EC_INVALID_ARG
    ;;
  esac
  shift
done

case "$action" in
--enable)
  _socket_enable
  exit $?
  ;;
--disable)
  _socket_disable
  exit $?
  ;;
--test)
  _socket_test
  exit $?
  ;;
--status)
  _socket_status
  exit $?
  ;;
--emit)
  _socket_emit "$payload"
  exit $?
  ;;
*)
  # This case is covered by the `if [[ "$#" -eq 0 ]]` check at the top of the script,
  # but this safeguard prevents unexpected behavior if that check were removed.
  __print_error "No command specified."
  exit $EC_MISSING_ARG
  ;;
esac

exit $?
