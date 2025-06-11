#!/usr/bin/env bash

debug=
# shellcheck disable=SC2199
if [[ $@ =~ "--debug" ]]; then
  debug="--debug"
  export PS4='+(\033[0;33m${BASH_SOURCE}:${LINENO}\033[0m): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
  set -x
  for a; do
    shift
    case $a in
    --debug) continue ;;
    *) set -- "$@" "$a" ;;
    esac
  done
fi

function usage() {
  echo "Manages the lifecycle actions of standalone instances

Usage:
  $(basename "$0") OPTION

Options:
  -h, --help                      Prints this message

  --logs <instance>               Prints the last few lines of an instance's logs
    [--follow]                   Continuously follow the log output
  --is-active <instance>          Check if the instance is active.
  --start <instance>              Start the instance.
  --stop <instance>               Stop the instance.
  --restart <instance>            Restart the instance.

Examples:
  $(basename "$0") --start valheim-03
  $(basename "$0") --status 7dtd
  $(basename "$0") --logs factorio-space-age-01
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

SELF_PATH="$(dirname "$(readlink -f "$0")")"

# Check for KGSM_ROOT
if [ -z "$KGSM_ROOT" ]; then
  while [[ "$SELF_PATH" != "/" ]]; do
    [[ -f "$SELF_PATH/kgsm.sh" ]] && KGSM_ROOT="$SELF_PATH" && break
    SELF_PATH="$(dirname "$SELF_PATH")"
  done
  [[ -z "$KGSM_ROOT" ]] && echo "Error: Could not locate kgsm.sh. Ensure the directory structure is intact." && exit 1
  export KGSM_ROOT
fi

if [[ ! "$KGSM_COMMON_LOADED" ]]; then
  module_common="$(find "$KGSM_ROOT/modules" -type f -name common.sh -print -quit)"
  [[ -z "$module_common" ]] && echo "${0##*/} ERROR: Failed to load module common.sh" >&2 && exit 1
  # shellcheck disable=SC1090
  source "$module_common" || exit 1
fi

function _start_instance() {
  local instance=$1

  # shellcheck disable=SC1090
  source "$(__find_instance_config "$instance")" || return "$EC_FAILED_SOURCE"
  "$instance_management_file" --start --background $debug

  __emit_instance_started "${instance%.ini}" "$instance_lifecycle_manager"
}

function _stop_instance() {
  local instance=$1

  # shellcheck disable=SC1090
  source "$(__find_instance_config "$instance")" || return "$EC_FAILED_SOURCE"
  "$instance_management_file" --stop $debug

  __emit_instance_stopped "${instance%.ini}" "$instance_lifecycle_manager"
}

function _restart_instance() {
  local instance=$1

  _stop_instance "$instance"
  _start_instance "$instance"
}

function _is_instance_active() {
  local instance=$1

  # shellcheck disable=SC1090
  source "$(__find_instance_config "$instance")" || return "$EC_FAILED_SOURCE"
  "$instance_management_file" --is-active
}

function _get_logs() {
  local instance=$1
  local follow=$2

  # shellcheck disable=SC1090
  source "$(__find_instance_config "$instance")" || return "$EC_FAILED_SOURCE"
  "$instance_management_file" --logs $follow $debug
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
      follow=""
      # shellcheck disable=SC2199
      if [[ "$@" =~ "--follow" ]]; then
        follow="--follow"
      fi
      _get_logs "$instance" "$follow"
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
    ;;
  *)
    __print_error "Invalid argument $1" && exit $EC_INVALID_ARG
    ;;
  esac
  shift
done

exit $?
