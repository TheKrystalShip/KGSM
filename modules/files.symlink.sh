#!/usr/bin/env bash

set -eo pipefail

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

function usage() {
  echo "Usage: $(basename "$0") [OPTION]... [COMMAND] [FLAGS]

Manage command symlinks for game server instances.

Options:
  -h, --help                  Display this help and exit
  -i, --instance=INSTANCE     Specify the instance name (without .ini extension)
                              Equivalent to instance_name in the config

Commands:
  --install                   Create a symlink to the management file in the PATH
  --uninstall                 Remove the symlink to the management file

Examples:
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

function _symlink_uninstall() {

  # Remove the symlink from the $config_command_shortcuts_directory
  # if it exists.

  # Check if the symlink directory is set
  if [[ -z "$config_command_shortcuts_directory" ]]; then
    __print_error "config_command_shortcuts_directory is expected but it's not set"
    return $EC_MISSING_ARG
  fi

  local symlink_path="${config_command_shortcuts_directory}/${instance_name}"

  # Check if the symlink exists
  if [[ -L "$symlink_path" ]]; then
    __print_info "Removing symlink '$symlink_path'"
    if ! $SUDO rm "$symlink_path"; then
      __print_error "Failed to remove symlink '$symlink_path'"
      return $EC_FAILED_RM
    fi
  else
    __print_info "Symlink '$symlink_path' does not exist, nothing to remove"
  fi

  # Remove the symlink entry from the instance config file
  __remove_config "$instance_config_file" "instance_enable_command_shortcuts"
  __remove_config "$instance_config_file" "instance_command_shortcuts_directory"

  __print_success "Symlink for instance '$instance_name' removed from $config_command_shortcuts_directory"

  return 0
}

function _symlink_install() {

  # Create a symlink from the $instance_management_file into one of the directories
  # on the PATH, iso that the instance can be managed from anywhere.

  __print_info "Creating symlink for instance '$instance_name'..."

  # Check if the symlink directory is set
  if [[ -z "$config_command_shortcuts_directory" ]]; then
    __print_error "'command_shortcuts_directory' is expected but it's not set"
    return $EC_MISSING_ARG
  fi

  # Check if the symlink directory exists
  if [[ ! -d "$config_command_shortcuts_directory" ]]; then
    __print_error "'command_shortcuts_directory' '$config_command_shortcuts_directory' does not exist"
    return $EC_FILE_NOT_FOUND
  fi

  local symlink_path="${config_command_shortcuts_directory}/${instance_name}"

  # Check if the symlink already exists
  if [[ -L "$symlink_path" ]]; then
    __print_warning "Symlink '$symlink_path' already exists, removing it"
    if ! $SUDO rm "$symlink_path"; then
      __print_error "Failed to remove existing symlink '$symlink_path'"
      return $EC_FAILED_RM
    fi
  fi

  # Create the symlink
  if ! $SUDO ln -s "$instance_management_file" "$symlink_path"; then
    __print_error "Failed to create symlink '$symlink_path' for $instance_management_file"
    return $EC_FAILED_LN
  fi

  # Enable command shortcuts for the instance
  __add_or_update_config "$instance_config_file" "instance_enable_command_shortcuts" "true" || {
    __print_error "Failed to update instance config with 'instance_enable_command_shortcuts' set to 'true'"
    return $EC_FAILED_UPDATE_CONFIG
  }

  # Save the symlink directory into the instance config file
  __add_or_update_config "$instance_config_file" "instance_command_shortcut_file" "${symlink_path}" || {
    return $EC_FAILED_UPDATE_CONFIG
  }

  __print_success "Instance \"${instance_name}\" symlink created in $config_command_shortcuts_directory"

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
      _symlink_install
      exit $?
      ;;
    --uninstall)
      _symlink_uninstall
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
