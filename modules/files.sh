#!/usr/bin/env bash

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

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

function usage() {
  local UNDERLINE="\e[4m"
  local END="\e[0m"

  echo -e "${UNDERLINE}File Management for Krystal Game Server Manager${END}

Creates and manages all necessary files for game server operation.

${UNDERLINE}Usage:${END}
  $(basename "$0") [OPTIONS] [COMMAND]

${UNDERLINE}Options:${END}
  -h, --help                  Display this help information
  -i, --instance INSTANCE     Specify the target instance name (without .ini extension)
                              Must match the instance_name in the configuration

${UNDERLINE}Commands:${END}
  --create                    Generate all required files for the instance:
                                - instance.manage.sh
                                - systemd service/socket files (if applicable)
                                - UFW firewall rules (if applicable)
                                - symlink to the management file (if applicable)
                                - UPnP configuration files (if applicable)
  ${UNDERLINE}Subcommands:${END}
    --manage                   Create instance.manage.sh
    --config                   Copy instance configuration file to working directory
    --systemd                  Generate systemd service/socket files
    --ufw                      Generate and enable UFW firewall rule
    --symlink                  Create a symlink to the management file in the PATH
    --upnp                     Generate UPnP configuration files (if applicable)

  --remove                    Remove all files and integrations for instance uninstall
    --systemd                  Remove systemd service/socket files
    --ufw                      Remove UFW firewall rules
    --symlink                  Remove the symlink to the management file
    --upnp                     Remove UPnP configuration files
    --config                   Remove the instance configuration file from working directory
    --manage                   Remove the management file

${UNDERLINE}Examples:${END}
  $(basename "$0") --instance factorio-space-age --create
  $(basename "$0") -i factorio-space-age --remove
  $(basename "$0") -i 7dtd-32 --remove --ufw

${UNDERLINE}Notes:${END}
  • --remove: Removes integrations and updates instance configuration
  • All operations require a loaded instance configuration
  • Individual integration removal disables the integration completely
"
}

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

# Load the instance configuration to determine which manager to use
__source_instance "$instance"

function _create() {
  # Use the files.management.sh module
  "$(__find_module files.management.sh)" --instance "$instance" --create || return $?

  # Use the files.config.sh module to copy the instance config file
  "$(__find_module files.config.sh)" --instance "$instance" --install || return $?

  # When creating files, we read the $config_ variables from the KGSM config file.
  # This is necessary to determine if we need to create systemd service files,
  # the firewall rules, or command shortcuts.

  if [[ "$config_enable_systemd" == "true" ]]; then
    # Use the files.systemd.sh module
    "$(__find_module files.systemd.sh)" --instance "$instance" --install || return $?
  fi

  if [[ "$config_enable_firewall_management" == "true" ]]; then
    # Use the files.ufw.sh module
    "$(__find_module files.ufw.sh)" --instance "$instance" --install || return $?
  fi

  if [[ "$config_enable_command_shortcuts" == "true" ]]; then
    # Use the files.symlink.sh module
    "$(__find_module files.symlink.sh)" --instance "$instance" --install || return $?
  fi

  __emit_instance_files_created "${instance}"

  return 0
}

# Config-dependent operation: Remove files based on instance configuration (for uninstall)
function _remove_for_uninstall() {
  # Use the files.management.sh module to remove management file
  "$(__find_module files.management.sh)" --instance "$instance" --remove || return $?

  # When uninstalling files, we read the $instance_ variables from the instance config file.
  # This is necessary to determine if we need to remove systemd service files,
  # the firewall rules, or command shortcuts.

  if [[ "$instance_lifecycle_manager" == "systemd" ]]; then
    # Use the files.systemd.sh module
    "$(__find_module files.systemd.sh)" --instance "$instance" --disable || return $?
  fi

  if [[ "$instance_enable_firewall_management" == "true" ]]; then
    # Use the files.ufw.sh module
    "$(__find_module files.ufw.sh)" --instance "$instance" --disable || return $?
  fi

  if [[ "$instance_enable_command_shortcuts" == "true" ]]; then
    # Use the files.symlink.sh module
    "$(__find_module files.symlink.sh)" --instance "$instance" --disable || return $?
  fi

  # We don't remove the instance config file here, because it's still needed
  # for other modules to work.

  __emit_instance_files_removed "${instance}"

  return 0
}

# Read the argument values
while [ $# -gt 0 ]; do
  case "$1" in
  --create)
    shift
    if [[ -z "$1" ]]; then
      _create
      exit $?
    fi
    case "$1" in
    --manage)
      "$(__find_module files.management.sh)" --instance "$instance" --create
      exit $?
      ;;
    --config)
      "$(__find_module files.config.sh)" --instance "$instance" --install
      exit $?
      ;;
    --systemd)
      "$(__find_module files.systemd.sh)" --instance "$instance" --enable
      exit $?
      ;;
    --ufw)
      "$(__find_module files.ufw.sh)" --instance "$instance" --enable
      exit $?
      ;;
    --symlink)
      "$(__find_module files.symlink.sh)" --instance "$instance" --enable
      exit $?
      ;;
    --upnp)
      "$(__find_module files.upnp.sh)" --instance "$instance" --install
      exit $?
      ;;
    *)
      __print_error "Invalid argument $1"
      exit $EC_INVALID_ARG
      ;;
    esac
    ;;
  --remove)
    shift
    if [[ -z "$1" ]]; then
      _remove_for_uninstall
      exit $?
    fi
    case "$1" in
    --systemd)
      "$(__find_module files.systemd.sh)" --instance "$instance" --disable
      exit $?
      ;;
    --ufw)
      "$(__find_module files.ufw.sh)" --instance "$instance" --disable
      exit $?
      ;;
    --symlink)
      "$(__find_module files.symlink.sh)" --instance "$instance" --disable
      exit $?
      ;;
    --upnp)
      "$(__find_module files.upnp.sh)" --instance "$instance" --uninstall
      exit $?
      ;;
    --config)
      "$(__find_module files.config.sh)" --instance "$instance" --uninstall
      exit $?
      ;;
    --manage)
      "$(__find_module files.management.sh)" --instance "$instance" --remove
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
