#!/usr/bin/env bash

set -eo pipefail

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

function usage() {
  echo "Usage: $(basename "$0") [OPTION]... [COMMAND] [FLAGS]

Manage systemd integration for game server instances.

Options:
  -h, --help                  Display this help and exit
  -i, --instance=INSTANCE     Specify the instance name (without .ini extension)
                              Equivalent to instance_name in the config

Commands:
  --install                   Generate systemd service/socket files and enable them
  --uninstall                 Remove and disable systemd service/socket files

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

function _systemd_uninstall() {

  __print_info "Removing systemd integration..."

  if [[ -z "$instance_systemd_service_file" ]] && [[ -z "$instance_systemd_socket_file" ]]; then
    # Nothing to uninstall
    return 0
  fi

  if systemctl is-active "$instance_name" &> /dev/null; then
    if ! $SUDO systemctl stop "$instance_name" &> /dev/null; then
      __print_error "Failed to stop $instance_name before uninstalling systemd files"
      return $EC_SYSTEMD
    fi
  fi

  if systemctl is-enabled "$instance_name" &> /dev/null; then
    if ! $SUDO systemctl disable "$instance_name"; then
      __print_warning "Failed to disable $instance_name"
      return $EC_SYSTEMD
    fi
  fi

  # Remove service file
  # shellcheck disable=SC2153
  if [ -f "$instance_systemd_service_file" ]; then
    if ! $SUDO rm "$instance_systemd_service_file"; then
      __print_error "Failed to remove $instance_systemd_service_file"
      return $EC_FAILED_RM
    fi
  fi

  # Remove socket file
  # shellcheck disable=SC2153
  if [ -f "$instance_systemd_socket_file" ]; then
    if ! $SUDO rm "$instance_systemd_socket_file"; then
      __print_error "Failed to remove $instance_systemd_socket_file"
      return $EC_FAILED_RM
    fi
  fi

  # Reload systemd

  __print_info "Reloading systemd..."
  if ! $SUDO systemctl daemon-reload; then
    __print_error "Failed to reload systemd" && return "$EC_SYSTEMD"
  fi

  # Remove entries from instance config file and management file
  __remove_config "$instance_config_file" "instance_systemd_service_file"
  __remove_config "$instance_config_file" "instance_systemd_socket_file"
  __remove_config "$instance_management_file" "instance_systemd_service_file"
  __remove_config "$instance_management_file" "instance_systemd_socket_file"

  # Change the instance_lifecycle_manager to standalone
  __add_or_update_config "$instance_config_file" "instance_lifecycle_manager" "standalone" || {
    return $EC_FAILED_UPDATE_CONFIG
  }

  __print_success "Systemd integration removed"

  return 0
}

function _systemd_install() {

  __print_info "Adding systemd integration..."

  [[ -z "$config_systemd_files_dir" ]] && __print_error "config_systemd_files_dir is expected but it's not set" && return $EC_MISSING_ARG

  local service_template_file
  local socket_template_file
  service_template_file="$(__find_template service.tp)"
  socket_template_file="$(__find_template socket.tp)"

  local instance_systemd_service_file=${config_systemd_files_dir}/${instance_name}.service
  local instance_systemd_socket_file=${config_systemd_files_dir}/${instance_name}.socket

  local temp_systemd_service_file=/tmp/${instance_name}.service
  local temp_systemd_socket_file=/tmp/${instance_name}.socket

  local instance_bin_absolute_path
  instance_bin_absolute_path="$instance_launch_dir/$instance_executable_file"

  # Required by template
  export instance_bin_absolute_path
  export instance_socket_file=${instance_working_dir}/.${instance_name}.stdin

  # If service file already exists, check that it belongs to the instance
  if [[ -f "$instance_systemd_service_file" ]]; then
    if [[ -z "$instance_systemd_service_file" ]]; then
      __print_error "File '$instance_systemd_service_file' already exists but it doesn't belong to $instance_name"
      return $EC_GENERAL
    else
      if ! _systemd_uninstall; then
        return "$EC_GENERAL"
      fi
    fi
  fi

  # If socket file already exists, check that it belongs to the instance
  if [[ -f "$instance_systemd_socket_file" ]]; then
    if [[ -z "$instance_systemd_socket_file" ]]; then
      __print_error "File '$instance_systemd_socket_file' already exists but it doesn't belong to $instance_name"
      return $EC_GENERAL
    else
      if ! _systemd_uninstall; then
        return $EC_GENERAL
      fi
    fi
  fi

  instance_user=$USER
  if [ "$EUID" -eq 0 ]; then
    instance_user=$SUDO_USER
  fi

  # Create the service file
  if ! eval "cat <<EOF
$(< "$service_template_file")
EOF
" > "$temp_systemd_service_file" 2> /dev/null; then
    __print_error "Could not generate $service_template_file to $temp_systemd_service_file"
    return $EC_FAILED_TEMPLATE
  fi

  if ! $SUDO mv "$temp_systemd_service_file" "$instance_systemd_service_file"; then
    __print_error "Failed to move $temp_systemd_socket_file into $instance_systemd_service_file"
    return $EC_FAILED_MV
  fi

  if ! $SUDO chown root:root "$instance_systemd_service_file"; then
    __print_error "Failed to assign root user ownership to $instance_systemd_service_file"
    return $EC_PERMISSION
  fi

  # Create the socket file
  if ! eval "cat <<EOF
$(< "$socket_template_file")
EOF
" > "$temp_systemd_socket_file" 2> /dev/null; then
    __print_error "Could not generate $socket_template_file to $temp_systemd_socket_file"
    return $EC_FAILED_TEMPLATE
  fi

  if ! $SUDO mv "$temp_systemd_socket_file" "$instance_systemd_socket_file"; then
    __print_error "Failed to move $instance_systemd_socket_file into $instance_systemd_socket_file"
    return $EC_FAILED_MV
  fi

  if ! $SUDO chown root:root "$instance_systemd_socket_file"; then
    __print_error "Failed to assign root user ownership to $instance_systemd_socket_file"
    return $EC_PERMISSION
  fi

  # Reload systemd

  __print_info "Reloading systemd..."
  if ! $SUDO systemctl daemon-reload; then
    __print_error "Failed to reload systemd"
    return $EC_SYSTEMD
  fi

  # Save new files into instance config file

  # Add the service file to the instance config file
  __add_or_update_config "$instance_config_file" "instance_systemd_service_file" "$instance_systemd_service_file" || {
    return $EC_FAILED_UPDATE_CONFIG
  }

  # Add the socket file to the instance config file
  __add_or_update_config "$instance_config_file" "instance_systemd_socket_file" "$instance_systemd_socket_file" || {
    return $EC_FAILED_UPDATE_CONFIG
  }

  # Save it into the instance's management file also. Prepend just before the bottom marker
  local marker="# === END INJECT CONFIG ==="

  # Add the service file to the management file
  __add_or_update_config "$instance_management_file" "instance_systemd_service_file" "$instance_systemd_service_file" "$marker" || {
    return $EC_FAILED_UPDATE_CONFIG
  }

  # Add the socket file to the management file
  __add_or_update_config "$instance_management_file" "instance_systemd_socket_file" "$instance_systemd_socket_file" "$marker" || {
    return $EC_FAILED_UPDATE_CONFIG
  }

  # Change the instance_lifecycle_manager to systemd
  __add_or_update_config "$instance_config_file" "instance_lifecycle_manager" "systemd" || {
    return $EC_FAILED_UPDATE_CONFIG
  }

  # Also change the instance_lifecycle_manager in the management file
  __add_or_update_config "$instance_management_file" "instance_lifecycle_manager" "systemd" || {
    return $EC_FAILED_UPDATE_CONFIG
  }

  __print_success "Systemd integration complete"

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
      _systemd_install
      exit $?
      ;;
    --uninstall)
      _systemd_uninstall
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
