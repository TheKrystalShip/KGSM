#!/usr/bin/env bash

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

# shellcheck disable=SC1091
source "$(dirname "$(readlink -f "$0")")/../lib/bootstrap.sh"

function usage() {
  local UNDERLINE="\e[4m"
  local END="\e[0m"

  echo -e "${UNDERLINE}Systemd Integration for Krystal Game Server Manager${END}

Create and manage systemd services for game server instances, allowing for automatic startup and process management.

${UNDERLINE}Usage:${END}
  $(basename "$0") [OPTIONS] [COMMAND]

${UNDERLINE}Options:${END}
  -h, --help                  Display this help information
  -i, --instance=INSTANCE     Specify the target instance name (without .ini extension)
                              Must match the instance_name in the configuration

${UNDERLINE}Commands:${END}
  --enable                    Enable systemd integration for the instance
                              Creates systemd service/socket files and updates instance configuration
  --disable                   Disable systemd integration for the instance
                              Removes systemd service/socket files and updates instance configuration

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

# Core function: Remove systemd integration from external systems
function __systemd_remove_external() {
  local instance_name="$1"

  [[ -z "$config_systemd_files_dir" ]] && __print_error "config_systemd_files_dir is expected but it's not set" && return $EC_MISSING_ARG
  [[ -z "$instance_name" ]] && __print_error "instance_name is required" && return $EC_MISSING_ARG

  local instance_systemd_service_file="${config_systemd_files_dir}/${instance_name}.service"
  local instance_systemd_socket_file="${config_systemd_files_dir}/${instance_name}.socket"

  # Stop and disable service if it exists and is running
  if systemctl is-active "$instance_name" &>/dev/null; then
    if ! $SUDO systemctl stop "$instance_name" &>/dev/null; then
      __print_warning "Failed to stop $instance_name before removing systemd files"
    fi
  fi

  if systemctl is-enabled "$instance_name" &>/dev/null; then
    if ! $SUDO systemctl disable "$instance_name" &>/dev/null; then
      __print_warning "Failed to disable $instance_name"
    fi
  fi

  # Remove service file
  if [[ -f "$instance_systemd_service_file" ]]; then
    if ! $SUDO rm "$instance_systemd_service_file"; then
      __print_error "Failed to remove $instance_systemd_service_file"
      return $EC_FAILED_RM
    fi
  fi

  # Remove socket file
  if [[ -f "$instance_systemd_socket_file" ]]; then
    if ! $SUDO rm "$instance_systemd_socket_file"; then
      __print_error "Failed to remove $instance_systemd_socket_file"
      return $EC_FAILED_RM
    fi
  fi

  # Reload systemd
  __print_info "Reloading systemd..."
  if ! $SUDO systemctl daemon-reload; then
    __print_error "Failed to reload systemd"
    return $EC_SYSTEMD
  fi

  return 0
}

# Config-dependent operation: Disable systemd and update instance config
function _systemd_disable() {

  __print_info "Disabling systemd integration..."

  if [[ -z "$instance_systemd_service_file" ]] && [[ -z "$instance_systemd_socket_file" ]]; then
    # Nothing to disable
    return 0
  fi

  if ! __systemd_remove_external "$instance_name"; then
    return $?
  fi

  # Remove entries from instance config file
  __add_or_update_config "$instance_config_file" "enable_systemd" "false"
  __add_or_update_config "$instance_config_file" "lifecycle_manager" "standalone"
  __add_or_update_config "$instance_config_file" "systemd_service_file" ""
  __add_or_update_config "$instance_config_file" "systemd_socket_file" ""

  __print_success "Systemd integration disabled"

  return 0
}

# Core function: Create systemd integration in external systems (requires loaded instance config)
function __systemd_create_external() {

  [[ -z "$config_systemd_files_dir" ]] && __print_error "config_systemd_files_dir is expected but it's not set" && return $EC_MISSING_ARG
  [[ -z "$instance_name" ]] && __print_error "instance_name is required" && return $EC_MISSING_ARG
  [[ -z "$instance_launch_dir" ]] && __print_error "instance_launch_dir is required" && return $EC_MISSING_ARG
  [[ -z "$instance_executable_file" ]] && __print_error "instance_executable_file is required" && return $EC_MISSING_ARG
  [[ -z "$instance_working_dir" ]] && __print_error "instance_working_dir is required" && return $EC_MISSING_ARG

  local service_template_file
  local socket_template_file
  service_template_file="$(__find_template service.tp)"
  socket_template_file="$(__find_template socket.tp)"

  local instance_systemd_service_file="${config_systemd_files_dir}/${instance_name}.service"
  local instance_systemd_socket_file="${config_systemd_files_dir}/${instance_name}.socket"

  local temp_systemd_service_file="/tmp/${instance_name}.service"
  local temp_systemd_socket_file="/tmp/${instance_name}.socket"

  local instance_bin_absolute_path="$instance_launch_dir/$instance_executable_file"

  # Required by template
  export instance_bin_absolute_path
  export instance_socket_file="${instance_working_dir}/.${instance_name}.stdin"

  # If service file already exists, remove existing installation
  if [[ -f "$instance_systemd_service_file" ]] || [[ -f "$instance_systemd_socket_file" ]]; then
    if ! __systemd_remove_external "$instance_name"; then
      return $EC_GENERAL
    fi
  fi

  instance_user=$USER
  if [[ "$EUID" -eq 0 ]]; then
    instance_user=$SUDO_USER
  fi

  # Create the service file
  if ! eval "cat <<EOF
$(<"$service_template_file")
EOF
" >"$temp_systemd_service_file" 2>/dev/null; then
    __print_error "Could not generate $service_template_file to $temp_systemd_service_file"
    return $EC_FAILED_TEMPLATE
  fi

  if ! $SUDO mv "$temp_systemd_service_file" "$instance_systemd_service_file"; then
    __print_error "Failed to move $temp_systemd_service_file into $instance_systemd_service_file"
    return $EC_FAILED_MV
  fi

  if ! $SUDO chown root:root "$instance_systemd_service_file"; then
    __print_error "Failed to assign root user ownership to $instance_systemd_service_file"
    return $EC_PERMISSION
  fi

  # Create the socket file
  if ! eval "cat <<EOF
$(<"$socket_template_file")
EOF
" >"$temp_systemd_socket_file" 2>/dev/null; then
    __print_error "Could not generate $socket_template_file to $temp_systemd_socket_file"
    return $EC_FAILED_TEMPLATE
  fi

  if ! $SUDO mv "$temp_systemd_socket_file" "$instance_systemd_socket_file"; then
    __print_error "Failed to move $temp_systemd_socket_file into $instance_systemd_socket_file"
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

  return 0
}

# Config-dependent operation: Enable systemd and update instance config
function _systemd_enable() {

  __print_info "Enabling systemd integration..."

  [[ -z "$config_systemd_files_dir" ]] && __print_error "config_systemd_files_dir is expected but it's not set" && return "$EC_MISSING_ARG"

  # If systemd files are already defined, nothing to do
  if [[ -n "$instance_systemd_service_file" ]] && [[ -f "$instance_systemd_service_file" ]] &&
    [[ -n "$instance_systemd_socket_file" ]] && [[ -f "$instance_systemd_socket_file" ]]; then
    __print_success "Systemd integration already enabled"
    return 0
  fi

  local instance_systemd_service_file="${config_systemd_files_dir}/${instance_name}.service"
  local instance_systemd_socket_file="${config_systemd_files_dir}/${instance_name}.socket"

  if ! __systemd_create_external; then
    return $?
  fi

  # Save new files into instance config file
  __add_or_update_config "$instance_config_file" "enable_systemd" "true"
  __add_or_update_config "$instance_config_file" "lifecycle_manager" "systemd"
  __add_or_update_config "$instance_config_file" "systemd_service_file" "$instance_systemd_service_file"
  __add_or_update_config "$instance_config_file" "systemd_socket_file" "$instance_systemd_socket_file"

  __print_success "Systemd integration enabled"

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
    _systemd_enable
    exit $?
    ;;
  --disable | --uninstall)
    _systemd_disable
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
