#!/usr/bin/env bash

# shellcheck disable=SC1091
source "$(dirname "$(readlink -f "$0")")/../lib/bootstrap.sh"

function usage() {
  local UNDERLINE="\e[4m"
  local END="\e[0m"

  echo -e "${UNDERLINE}Standalone Process Lifecycle Management for KGSM${END}

Controls game server instances that run as standalone processes without systemd integration.

${UNDERLINE}Usage:${END}
  $(basename "$0") [OPTIONS] <instance>

${UNDERLINE}Options:${END}
  -h, --help                      Display this help information

${UNDERLINE}Server Control:${END}
  --start <instance>              Launch a standalone game server process
                                  Creates a PID file for tracking
  --stop <instance>               Gracefully shut down a running server process
                                  Sends termination signal and cleans up PID file
  --restart <instance>            Perform a complete stop and start sequence
                                  Ensures clean process restart

${UNDERLINE}Monitoring:${END}
  --logs <instance>               Display the most recent log entries
    [--follow]                    Continuously monitor new log entries in real-time
  --is-active <instance>          Check if the process is currently running
                                  Verifies PID file and process existence

${UNDERLINE}Examples:${END}
  $(basename "$0") --start valheim-03
  $(basename "$0") --logs factorio-space-age-01 --follow
  $(basename "$0") --restart minecraft-survival
"
}

[[ $# -eq 0 ]] && usage && exit 1

# Read the argument values
while [[ "$#" -gt 0 ]]; do
  case $1 in
  -h | --help)
    usage && exit 0
    ;;
  *)
    break
    ;;
  esac
done

module_events=$(__find_module events.sh)

function _start_instance() {
  local instance=$1

  __source_instance "$instance"
  "$instance_management_file" --start --background

  "$module_events" --emit --instance-started "${instance%.ini}" "$instance_lifecycle_manager"
}

function _stop_instance() {
  local instance=$1

  __source_instance "$instance"
  "$instance_management_file" --stop

  "$module_events" --emit --instance-stopped "${instance%.ini}" "$instance_lifecycle_manager"
}

function _restart_instance() {
  local instance=$1

  _stop_instance "$instance"
  _start_instance "$instance"
}

function _is_instance_active() {
  local instance=$1

  __source_instance "$instance"
  "$instance_management_file" --is-active
}

function _get_logs() {
  local instance=$1
  local follow=${2:-false}

  __source_instance "$instance"

  if [[ "$follow" == "true" ]]; then
    "$instance_management_file" --logs --follow
  else
    "$instance_management_file" --logs
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --logs | --is-active | --start | --stop | --restart)
    command=$1
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <instance>" && exit $EC_MISSING_ARG
    instance=$1
    case "$command" in
    --logs)
      shift
      follow="false"
      if [[ "$1" == "--follow" || "$1" == "-f" ]]; then
        follow="true"
        shift
      fi
      _get_logs "$instance" "$follow"
      exit $?
      ;;
    --is-active)
      _is_instance_active "$instance"
      exit $?
      ;;
    --start)
      _start_instance "$instance"
      exit $?
      ;;
    --stop)
      _stop_instance "$instance"
      exit $?
      ;;
    --restart)
      _restart_instance "$instance"
      exit $?
      ;;
    *)
      __print_error "Invalid argument $1"
      exit $EC_INVALID_ARG
      ;;
    esac
    ;;
  *)
    __print_error "Invalid argument $1"
    exit $EC_INVALID_ARG
    ;;
  esac
  shift
done

exit $?
