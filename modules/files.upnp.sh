#!/usr/bin/env bash

set -eo pipefail

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

function usage() {
  local UNDERLINE="\e[4m"
  local END="\e[0m"

  echo -e "${UNDERLINE}UPnP Port Forwarding Management for Krystal Game Server Manager${END}

Manages UPnP (Universal Plug and Play) port forwarding configuration for game server instances.

${UNDERLINE}Usage:${END}
  $(basename "$0") [OPTIONS] [COMMAND]

${UNDERLINE}Options:${END}
  -h, --help                  Display this help information
  -i, --instance=INSTANCE     Specify the target instance name (without .ini extension)
                              Must match the instance_name in the configuration

${UNDERLINE}Commands:${END}
  --enable                    Enable UPnP port forwarding for the instance
                              Updates instance configuration to enable automatic port forwarding
  --install                   Alias for --enable (maintained for compatibility)
  --disable                   Disable UPnP port forwarding for the instance
                              Updates instance configuration to disable automatic port forwarding
  --uninstall                 Alias for --disable (maintained for compatibility)

${UNDERLINE}Examples:${END}
  $(basename "$0") --instance factorio-space-age --enable
  $(basename "$0") -i 7dtd-32 --disable

${UNDERLINE}Notes:${END}
  • UPnP management only updates configuration flags
  • No external files are created or removed
  • Actual port forwarding is handled by the game server management process
  • --enable/--install: Creates integration and marks it as enabled
  • --disable/--uninstall: Removes integration and marks it as disabled
  • All operations require a loaded instance configuration
"
}

# shellcheck disable=SC2199
if [[ $@ =~ "--debug" ]]; then
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

if [ "$#" -eq 0 ]; then usage && return 1; fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
  -h | --help)
    usage && exit 0
    ;;
  -i | --instance)
    shift
    [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument <instance>" >&2 && exit 1
    instance=$1
    ;;
  *)
    break
    ;;
  esac
  shift
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

function _upnp_install() {
  __add_or_update_config "$instance_config_file" "enable_port_forwarding" "true"
  return $?
}

function _upnp_uninstall() {
  __add_or_update_config "$instance_config_file" "enable_port_forwarding" "false"
  return $?
}

# Load the instance configuration
instance_config_file=$(__find_instance_config "$instance")
# Use __source_instance to load the config with proper prefixing
__source_instance "$instance"

[[ "$EUID" -ne 0 ]] && SUDO="sudo -E"

while [ $# -gt 0 ]; do
  case "$1" in
  --enable | --install)
    _upnp_install
    exit $?
    ;;
  --disable | --uninstall)
    _upnp_uninstall
    exit $?
    ;;
  *)
    __print_error "Invalid argument $1"
    exit $EC_INVALID_ARG
    ;;
  esac
  shift
done

exit $?
