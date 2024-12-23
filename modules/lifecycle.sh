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
  echo "Manages the lifecycle of instances

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

function __get_lifecycle_manager() {
  local instance=$1

  # shellcheck disable=SC1090
  source "$(__load_instance "$instance")" || return "$EC_FAILED_SOURCE"

  local lifecycle_manager
  lifecycle_manager="$(__load_module "lifecycle.${INSTANCE_LIFECYCLE_MANAGER}.sh")"

  if [[ -z "$lifecycle_manager" ]]; then
    __print_error "Failed to load lifecycle manager for ${instance}"
    return "$EC_FILE_NOT_FOUND"
  fi

  echo "$lifecycle_manager"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --logs | --is-active | --start | --stop | --restart)
    command=$1
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <instance>" && exit "$EC_MISSING_ARG"
    instance=$1
    lifecycle_manager="$(__get_lifecycle_manager "$instance")"
    case "$command" in
      --logs) "$lifecycle_manager" --logs "$instance" $debug ;;
      --is-active) "$lifecycle_manager" --is-active "$instance" $debug ;;
      --start) "$lifecycle_manager" --start "$instance" $debug ;;
      --stop) "$lifecycle_manager" --stop "$instance" $debug ;;
      --restart) "$lifecycle_manager" --restart "$instance" $debug ;;
    esac
    exit $?
    ;;
  *)
    __print_error "Invalid argument $1" && exit "$EC_INVALID_ARG"
    ;;
  esac
  shift
done
