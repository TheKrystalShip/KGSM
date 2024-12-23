#!/bin/bash

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

  --logs <instance>               Prints a constant output of an instance's logs
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
  module_common="$(find "$KGSM_ROOT" -type f -name common.sh -print -quit)"
  [[ -z "$module_common" ]] && echo "${0##*/} ERROR: Failed to load module common.sh" >&2 && exit 1
  # shellcheck disable=SC1090
  source "$module_common" || exit 1
fi

function _start_instance() {
  local instance=$1

  # shellcheck disable=SC1090
  source "$(__load_instance "$instance")" || return "$EC_FAILED_SOURCE"
  "$INSTANCE_MANAGE_FILE" --start --background $debug

  __emit_instance_started "${instance%.ini}" "$INSTANCE_LIFECYCLE_MANAGER"
}

function _stop_instance() {
  local instance=$1

  # shellcheck disable=SC1090
  source "$(__load_instance "$instance")" || return "$EC_FAILED_SOURCE"
  "$INSTANCE_MANAGE_FILE" --stop $debug

  __emit_instance_stopped "${instance%.ini}" "$INSTANCE_LIFECYCLE_MANAGER"
}

function _restart_instance() {
  local instance=$1

  __stop_instance "$instance"
  __start_instance "$instance"
}

function _is_instance_active() {
  local instance=$1

  # shellcheck disable=SC1090
  source "$(__load_instance "$instance")" || return "$EC_FAILED_SOURCE"
  "$INSTANCE_MANAGE_FILE" --is-active
}

function _get_logs() {
  local instance=$1

  # shellcheck disable=SC1090
  source "$(__load_instance "$instance")" || return "$EC_FAILED_SOURCE"

  while true; do
    local latest_log_file
    latest_log_file="$(ls "$INSTANCE_LOGS_DIR" -t | head -1)"

    if [[ -z "$latest_log_file" ]]; then
      sleep 2
      continue
    fi

    __print_info "Following logs from $latest_log_file"

    tail -F "$INSTANCE_LOGS_DIR/$latest_log_file" &
    tail_pid=$!

    # Wait for tail process to finish or the log file to be replaced
    inotifywait -e create -e moved_to "$INSTANCE_LOGS_DIR" >/dev/null 2>&1

    # New log file detected; kill current tail and loop back to follow the new file
    kill "$tail_pid"
    __print_info "Detected new log file. Switching to the latest log..."
    sleep 1
  done
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --logs)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <instance>" && exit "$EC_MISSING_ARG"
    _get_logs "$1"; exit $?
    ;;
  --is-active)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <instance>" && exit "$EC_MISSING_ARG"
    _is_instance_active "$1"; exit $?
    ;;
  --start)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <instance>" && exit "$EC_MISSING_ARG"
    _start_instance "$1"; exit $?
    ;;
  --stop)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <instance>" && exit "$EC_MISSING_ARG"
    _stop_instance "$1"; exit $?
    ;;
  --restart)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <instance>" && exit "$EC_MISSING_ARG"
    _restart_instance "$1"; exit $?
    ;;
  *)
    __print_error "Invalid argument $1" && exit "$EC_INVALID_ARG"
    ;;
  esac
  shift
done
