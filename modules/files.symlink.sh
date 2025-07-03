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
  --enable                    Enable symlink integration for the instance
                              Creates symlink and updates instance configuration
  --disable                   Disable symlink integration for the instance
                              Removes symlink and updates instance configuration

${UNDERLINE}Legacy Commands (deprecated):${END}
  --install                   Alias for --enable (maintained for compatibility)
  --uninstall                 Alias for --disable (maintained for compatibility)

${UNDERLINE}Examples:${END}
  $(basename "$0") --instance factorio-space-age --enable
  $(basename "$0") -i 7dtd-32 --disable
  $(basename "$0") -i factorio-space-age --uninstall

${UNDERLINE}Notes:${END}
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

# Core function: Remove symlink from external systems
function __symlink_remove_external() {
  local instance_name="$1"

  [[ -z "$config_command_shortcuts_directory" ]] && __print_error "config_command_shortcuts_directory is expected but it's not set" && return $EC_MISSING_ARG
  [[ -z "$instance_name" ]] && __print_error "instance_name is required" && return $EC_MISSING_ARG

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

  return 0
}

# Core function: Create symlink in external systems (requires loaded instance config)
function __symlink_create_external() {

  [[ -z "$config_command_shortcuts_directory" ]] && __print_error "config_command_shortcuts_directory is expected but it's not set" && return $EC_MISSING_ARG
  [[ -z "$instance_name" ]] && __print_error "instance_name is required" && return $EC_MISSING_ARG
  [[ -z "$instance_management_file" ]] && __print_error "instance_management_file is required" && return $EC_MISSING_ARG

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

  return 0
}

# Config-dependent operation: Disable symlink and update instance config
function _symlink_disable() {

  __print_info "Disabling symlink integration..."

  [[ -z "$instance_command_shortcut_file" ]] && return 0
  [[ ! -L "$instance_command_shortcut_file" ]] && return 0

  if ! __symlink_remove_external "$instance_name"; then
    return $?
  fi

  # Disable command shortcuts in the instance config file
  __add_or_update_config "$instance_config_file" "enable_command_shortcuts" "false"
  __add_or_update_config "$instance_config_file" "command_shortcut_file" ""

  __print_success "Symlink integration disabled"
  return 0
}

# Config-dependent operation: Enable symlink and update instance config
function _symlink_enable() {

  __print_info "Enabling symlink integration..."

  [[ -z "$config_command_shortcuts_directory" ]] && __print_error "config_command_shortcuts_directory is expected but it's not set" && return "$EC_MISSING_ARG"

  # If instance_command_shortcut_file is already defined, nothing to do
  if [[ -n "$instance_command_shortcut_file" ]] && [[ -L "$instance_command_shortcut_file" ]]; then
    __print_success "Symlink integration already enabled"
    return 0
  fi

  local symlink_path="${config_command_shortcuts_directory}/${instance_name}"

  if ! __symlink_create_external; then
    return $?
  fi

  # Add the config in the instance config file
  __add_or_update_config "$instance_config_file" "enable_command_shortcuts" "true"
  __add_or_update_config "$instance_config_file" "command_shortcut_file" "$symlink_path"

  __print_success "Symlink integration enabled"

  return 0
}

[[ "$EUID" -ne 0 ]] && SUDO="sudo -E"

# Load instance configuration
instance_config_file=$(__find_instance_config "$instance")
# Use __source_instance to load the config with proper prefixing
__source_instance "$instance"

while [ $# -gt 0 ]; do
  case "$1" in
  --enable | --install)
    _symlink_enable
    exit $?
    ;;
  --disable | --uninstall)
    _symlink_disable
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
