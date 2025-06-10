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
  echo "Usage: $(basename "$0") [OPTION]... [COMMAND] [FLAGS]

Manage necessary files for running a game server.

Options:
  -h, --help                  Display this help and exit
  -i, --instance=INSTANCE     Specify the instance name (without .ini extension)
                              Equivalent to instance_name in the config

Commands:
  --create                    Generate all required files:
                                - instance.manage.sh
                                - instance.override.sh (if applicable)
                                - systemd service/socket files
                                - UFW firewall rules (if applicable)
    --manage                   Create instance.manage.sh
    --systemd                  Generate systemd service/socket files
    --ufw                      Generate and enable UFW firewall rule
    --symlink                  Create a symlink to the management file in the
                               PATH

  --remove                    Remove and disable:
                                - systemd service/socket files
                                - UFW firewall rules
                                - symlink to the management file
    --systemd                  Remove systemd service/socket files
    --ufw                      Remove UFW firewall rules
    --symlink                  Remove the symlink to the management file

Examples:
  $(basename "$0") --instance factorio-space-age --create
  $(basename "$0") -i 7dtd-32 --remove --ufw
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
  module_common="$(find "$KGSM_ROOT/modules" -type f -name common.sh -print -quit)"
  [[ -z "$module_common" ]] && echo "${0##*/} ERROR: Failed to load module common.sh" >&2 && exit 1
  # shellcheck disable=SC1090
  source "$module_common" || exit 1
fi

# Load the instance configuration to determine which manager to use
instance_config_file=$(__find_instance_config "$instance")
# shellcheck disable=SC1090
source "$instance_config_file" || exit $EC_FAILED_SOURCE

function _create() {
  # Use the files.management.sh module
  "$(__find_module files.management.sh)" --instance "$instance" --create || return $?

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

  __emit_instance_files_created "${instance%.ini}"
  return 0
}

function _remove() {

  # When uninstalling files, we read the $instance_ variables from the instance config file.
  # This is necessary to determine if we need to remove systemd service files,
  # the firewall rules, or command shortcuts.

  if [[ "$instance_lifecycle_manager" == "systemd" ]]; then
    # Use the files.systemd.sh module
    "$(__find_module files.systemd.sh)" --instance "$instance" --uninstall || return $?
  fi

  if [[ "$instance_enable_firewall_management" == "true" ]]; then
    # Use the files.ufw.sh module
    "$(__find_module files.ufw.sh)" --instance "$instance" --uninstall || return $?
  fi

  if [[ "$instance_enable_command_shortcuts" == "true" ]]; then
    # Use the files.symlink.sh module
    "$(__find_module files.symlink.sh)" --instance "$instance" --uninstall || return $?
  fi

  __emit_instance_files_removed "${instance%.ini}"
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
        --systemd)
          "$(__find_module files.systemd.sh)" --instance "$instance" --install
          exit $?
          ;;
        --ufw)
          "$(__find_module files.ufw.sh)" --instance "$instance" --install
          exit $?
          ;;
        --symlink)
          "$(__find_module files.symlink.sh)" --instance "$instance" --install
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
        _remove
        exit $?
      fi
      case "$1" in
        --systemd)
          "$(__find_module files.systemd.sh)" --instance "$instance" --uninstall
          exit $?
          ;;
        --ufw)
          "$(__find_module files.ufw.sh)" --instance "$instance" --uninstall
          exit $?
          ;;
        --symlink)
          "$(__find_module files.symlink.sh)" --instance "$instance" --uninstall
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
