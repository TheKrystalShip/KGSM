#!/usr/bin/env bash

set -eo pipefail

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

function usage() {
  local UNDERLINE="\e[4m"
  local END="\e[0m"

  echo -e "${UNDERLINE}Command Shortcut Management for Krystal Game Server Manager${END}

Creates and manages command shortcuts (symlinks) for easier access to game server instances.

${UNDERLINE}Usage:${END}
  $(basename "$0") [OPTIONS] [COMMAND]

${UNDERLINE}Options:${END}
  -h, --help                  Display this help information
  -i, --instance=INSTANCE     Specify the target instance name (without .ini extension)
                              Must match the instance_name in the configuration

${UNDERLINE}Commands:${END}
  --install                   Create a system-wide command shortcut for the instance
                              Makes a symlink in your PATH for direct management access
  --uninstall                 Remove the command shortcut for the instance
                              Removes the previously created symlink

${UNDERLINE}Examples:${END}
  $(basename "$0") --instance factorio-space-age --install
  $(basename "$0") -i 7dtd-32 --uninstall
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
  module_common="$(find "$KGSM_ROOT/modules" -type f -name common.sh -print -quit)"
  [[ -z "$module_common" ]] && echo "${0##*/} ERROR: Failed to load module common.sh" >&2 && exit 1
  # shellcheck disable=SC1090
  source "$module_common" || exit 1
fi

function _upnp_install() {
  local key="instance_enable_port_forwarding"
  __add_or_update_config "$instance_config_file" "$key" "true" || return $?

  if [[ -f "$instance_management_file" ]]; then
    __add_or_update_config "$instance_management_file" "$key" "true" || return $?
  fi

  return 0
}

function _upnp_uninstall() {
  local key="instance_enable_port_forwarding"
  __add_or_update_config "$instance_config_file" "$key" "false" || return $?

  if [[ -f "$instance_management_file" ]]; then
    __add_or_update_config "$instance_management_file" "$key" "false" || return $?
  fi

  return 0
}

# Load the instance configuration
instance_config_file=$(__find_instance_config "$instance")
# shellcheck disable=SC1090
source "$instance_config_file" || exit $EC_FAILED_SOURCE

[[ "$EUID" -ne 0 ]] && SUDO="sudo -E"

while [ $# -gt 0 ]; do
  case "$1" in
  --install)
    _upnp_install
    exit $?
    ;;
  --uninstall)
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
