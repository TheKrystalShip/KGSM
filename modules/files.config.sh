#!/usr/bin/env bash

set -eo pipefail

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

function usage() {
  local UNDERLINE="\e[4m"
  local END="\e[0m"

  echo -e "${UNDERLINE}Instance Configuration Management for Krystal Game Server Manager${END}

Manages instance configuration files for game server instances.

${UNDERLINE}Usage:${END}
  $(basename "$0") [OPTIONS] [COMMAND]

${UNDERLINE}Options:${END}
  -h, --help                  Display this help information
  -i, --instance=INSTANCE     Specify the target instance name (without .ini extension)
                              Must match the instance_name in the configuration

${UNDERLINE}Commands:${END}
  --install                   Copy the instance configuration file to the working directory
  --uninstall                 Remove the instance configuration file from the working directory

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

function _config_install() {
  # Copy instance configuration file to instance working directory and create symlink from KGSM
  local instance_name
  instance_name=$(basename "$instance_config_file" .ini)
  local instance_config_standalone="${instance_working_dir}/${instance_name}.config.ini"

  __print_info "Installing standalone instance configuration..."

  # Copy the config file to the instance working directory (this becomes the source of truth)
  if ! cp -f "$instance_config_file" "$instance_config_standalone"; then
    __print_error "Failed to copy instance configuration file to $instance_config_standalone"
    return $EC_FAILED_CP
  fi

  # Make sure the copied config file has the same ownership
  instance_user=$USER
  if [ "$EUID" -eq 0 ]; then
    instance_user=$SUDO_USER
  fi

  if ! chown "$instance_user":"$instance_user" "$instance_config_standalone"; then
    __print_error "Failed to assign $instance_config_standalone to user $instance_user"
    return $EC_PERMISSION
  fi

  # Remove existing KGSM symlink if it exists
  if [[ -e "$instance_config_file" || -L "$instance_config_file" ]]; then
    if ! rm -f "$instance_config_file"; then
      __print_error "Failed to remove existing KGSM config file/symlink at $instance_config_file"
      return $EC_FAILED_RM
    fi
  fi

  # Create symlink from KGSM pointing to the standalone config
  if ! ln -s "$instance_config_standalone" "$instance_config_file"; then
    __print_error "Failed to create KGSM symlink to standalone configuration file"
    return $EC_FAILED_LN
  fi

  __print_success "Standalone instance configuration installed at $instance_config_standalone"
  __print_success "KGSM symlink created pointing to standalone configuration"

  return 0
}

function _config_uninstall() {
  # Remove the KGSM symlink and optionally the standalone config file
  local instance_name
  instance_name=$(basename "$instance_config_file" .ini)
  local instance_config_standalone="${instance_working_dir}/${instance_name}.config.ini"

  # Remove KGSM symlink
  if [[ -L "$instance_config_file" ]]; then
    __print_info "Removing KGSM symlink to instance configuration..."

    if ! rm -f "$instance_config_file"; then
      __print_error "Failed to remove KGSM symlink: $instance_config_file"
      return $EC_FAILED_RM
    fi

    __print_success "KGSM symlink removed"
  elif [[ -e "$instance_config_file" ]]; then
    __print_warning "Found regular file instead of symlink at $instance_config_file - this may indicate an incomplete installation"
  fi

  # Remove the standalone config file from instance directory
  if [[ -f "$instance_config_standalone" ]]; then
    __print_info "Removing standalone configuration file from instance directory..."

    if ! rm -f "$instance_config_standalone"; then
      __print_error "Failed to remove standalone configuration file: $instance_config_standalone"
      return $EC_FAILED_RM
    fi

    __print_success "Standalone configuration file removed from instance directory"
  fi

  return 0
}

# Load the instance configuration
instance_config_file=$(__find_instance_config "$instance")
# Use __source_instance to load the config with proper prefixing
__source_instance "$instance"

[[ "$EUID" -ne 0 ]] && SUDO="sudo -E"

while [ $# -gt 0 ]; do
  case "$1" in
  --install)
    _config_install
    exit $?
    ;;
  --uninstall)
    _config_uninstall
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
