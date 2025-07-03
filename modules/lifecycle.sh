#!/usr/bin/env bash

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

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
  module_common="$(find "$KGSM_ROOT/lib" -type f -name common.sh -print -quit)"
  [[ -z "$module_common" ]] && echo "${0##*/} ERROR: Failed to load module common.sh" >&2 && exit 1
  # shellcheck disable=SC1090
  source "$module_common" || exit 1
fi

function _get_lifecycle_manager() {
  local instance=$1

  __source_instance "$instance"

  local lifecycle_manager
  lifecycle_manager="$(__find_module "lifecycle.${instance_lifecycle_manager}.sh")"

  echo "$lifecycle_manager"
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
      follow=""
      # shellcheck disable=SC2199
      if [[ "$@" =~ "--follow" ]]; then
        follow="--follow"
      fi
      "$lifecycle_manager" --logs "$instance" $follow $debug
      exit $?
      ;;
    --is-active)
      "$lifecycle_manager" --is-active "$instance" $debug
      exit $?
      ;;
    --start)
      "$lifecycle_manager" --start "$instance" $debug
      exit $?
      ;;
    --stop)
      "$lifecycle_manager" --stop "$instance" $debug
      exit $?
      ;;
    --restart)
      "$lifecycle_manager" --restart "$instance" $debug
      exit $?
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
