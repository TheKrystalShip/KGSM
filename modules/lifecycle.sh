#!/usr/bin/env bash

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

# shellcheck disable=SC1091
source "$(dirname "$(readlink -f "$0")")/../lib/bootstrap.sh"

function usage() {
  local UNDERLINE="\e[4m"
  local END="\e[0m"
  local BOLD="\e[1m"

  echo -e "${UNDERLINE}Lifecycle Management for Krystal Game Server Manager${END}

Controls the operational state and monitoring of game server instances.

${UNDERLINE}Usage:${END}
  $(basename "$0") [OPTIONS] <instance>

${UNDERLINE}Options:${END}
  -h, --help                      Display this help information

${UNDERLINE}Server Control:${END}
  --start <instance>              Launch a game server instance
                                  Makes the server available to players
  --stop <instance>               Gracefully shut down a running server
                                  Ensures proper save and cleanup procedures
  --restart <instance>            Perform a complete stop and start sequence
                                  Useful after configuration changes

${UNDERLINE}Monitoring:${END}
  --logs <instance>               Display the most recent log entries
    [--follow]                    Continuously monitor log output in real-time
  --is-active <instance>          Check if the server is currently running
                                  Returns exit code 0 if active, 1 if inactive

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

# Get the watcher module
module_watcher="$(__find_module watcher.sh)"

function _get_lifecycle_manager() {
  local instance=$1

  __source_instance "$instance"

  if [[ -z "$instance_lifecycle_manager" ]]; then
    __print_error "No lifecycle manager configured for '$instance'."
    return 1
  fi

  local lifecycle_manager
  lifecycle_manager="$(__find_module "lifecycle.${instance_lifecycle_manager}.sh")"

  echo "$lifecycle_manager"
}

function _start_instance() {
  local instance=$1

  "$lifecycle_manager" --start "$instance"

  "$module_watcher" --start-watch "$instance"
}

function _stop_instance() {
  local instance=$1

  "$lifecycle_manager" --stop "$instance"
}

function _restart_instance() {
  local instance=$1

  "$lifecycle_manager" --restart "$instance"
}

function _is_instance_active() {
  local instance=$1

  "$lifecycle_manager" --is-active "$instance"
}

function _get_logs() {
  local instance=$1
  local follow=${2:-false}

  "$lifecycle_manager" --logs "$instance" $follow
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --logs | --is-active | --start | --stop | --restart)
    command=$1
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <instance>" && exit $EC_MISSING_ARG
    instance=$1
    lifecycle_manager="$(_get_lifecycle_manager "$instance")"
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
      __print_error "Invalid argument $1" && exit $EC_INVALID_ARG
      ;;
    esac
    exit $?
    ;;
  *)
    __print_error "Invalid argument $1" && exit $EC_INVALID_ARG
    ;;
  esac
  shift
done

exit $?
