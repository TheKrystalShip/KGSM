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

[[ $# -eq 0 ]] && usage && exit 1

function usage() {
  echo "Manages native game server instance creation and management

Usage:
  $(basename "$0") OPTION

Options:
  -h, --help                      Prints this message

  --create-instance-config        Internal use: Creates additional configuration
    <config-file> <blueprint-file> for a native game server instance.
                                  <config-file> Path to the instance configuration file
                                  <blueprint-file> Path to the blueprint (.bp) file
                                  This function processes the blueprint file to
                                  configure the native game server instance with
                                  appropriate executables, arguments, and ports.

Command Interface:
  This module is designed to be used by the main instances.sh module and
  provides native-specific implementation for game servers that run directly
  on the host system (not in containers). It supports various game servers
  defined by blueprint (.bp) files.

Examples:
  $(basename "$0") --create-instance-config /path/to/instance.ini /path/to/blueprint.bp
"
}

# Define the main instance creation function first
function __create_native_instance_config() {
  local instance_config_file="$1"
  local blueprint_abs_path="$2"

  # Check if the blueprint file exists
  if [[ ! -f "$blueprint_abs_path" ]]; then
    __print_error "Blueprint file '$blueprint_abs_path' does not exist."
    return $EC_FILE_NOT_FOUND
  fi

  # Check if the instance config file already exists
  if [[ ! -f "$instance_config_file" ]]; then
    __print_error "Instance config file '$instance_config_file' not found."
    return $EC_FILE_NOT_FOUND
  fi

  # Load blueprint file to get variables
  __source_blueprint "$blueprint_abs_path"

  # Load instance config file to get variables
  __source_instance "$instance_config_file"

  # Set execution command variables if they exist in blueprint
  if [[ -n "${blueprint_executable_file:-}" ]]; then
    local blueprint_executable_file="${blueprint_executable_file}"

    # Servers launching with global binaries
    case "$blueprint_executable_file" in
    java | docker | wine)
      # Don't change since they are global
      ;;
    *)
      # Prepend "./" for anything that's not global
      blueprint_executable_file="./${blueprint_executable_file}"
      ;;
    esac
  fi

  # Extract args without evaluating if they exist
  if [[ -n "${blueprint_executable_arguments:-}" ]]; then
    blueprint_executable_arguments="$(grep "executable_arguments=" <"$blueprint_abs_path" | cut -d "=" -f2- | tr -d '"')"
  fi

  # Set required environment variables for the instance
  export blueprint_executable_file="${blueprint_executable_file:-}"
  export blueprint_executable_arguments="${blueprint_executable_arguments:-}"
  export blueprint_stop_command="${blueprint_stop_command:-}"
  export blueprint_save_command="${blueprint_save_command:-}"
  export blueprint_platform="${blueprint_platform:-linux}"
  export blueprint_level_name="${blueprint_level_name:-default}"
  export blueprint_steam_app_id="${blueprint_steam_app_id:-0}"
  export blueprint_is_steam_account_required="${blueprint_is_steam_account_required:-0}"
  export blueprint_ports="${blueprint_ports:-}"

  # Systemd files
  export instance_socket_file="${INSTANCE_WORKING_DIR}/.${INSTANCE_ID}.stdin"
  export instance_pid_file="${INSTANCE_WORKING_DIR}/.${INSTANCE_ID}.pid"
  export tail_pid_file="${INSTANCE_WORKING_DIR}/.${INSTANCE_ID}.tail.pid"

  # Default timeout values
  export instance_save_command_timeout_s="${config_save_command_timeout_seconds:-5}"
  export instance_stop_command_timeout_s="${config_stop_command_timeout_seconds:-30}"

  # Other configuration options
  export instance_use_upnp="${config_enable_port_forwarding:-0}"
  export instance_compress_backups="${config_enable_backup_compression:-0}"

  # UPnP port configuration if applicable
  local instance_upnp_ports=()
  if [[ -n "${blueprint_ports:-}" ]]; then
    if ! output=$(__parse_ufw_to_upnp_ports "$blueprint_ports") || ! read -ra instance_upnp_ports <<<"$output"; then
      __print_warning "Failed to generate INSTANCE_UPNP_PORTS. Disabling UPnP for instance $INSTANCE_ID"
      export USE_UPNP=0
    fi
  fi

  # Write native specific configuration
  {
    echo "INSTANCE_RUNTIME=\"native\""
    echo "INSTANCE_PORTS=\"${blueprint_ports:-}\""
    echo "INSTANCE_EXECUTABLE_FILE=\"${blueprint_executable_file:-}\""
    echo "INSTANCE_EXECUTABLE_ARGUMENTS=\"${blueprint_executable_arguments:-}\""
    echo "INSTANCE_SOCKET_FILE=\"${instance_socket_file:-}\""
    echo "INSTANCE_STOP_COMMAND=\"${blueprint_stop_command:-}\""
    echo "INSTANCE_SAVE_COMMAND=\"${blueprint_save_command:-}\""
    echo "INSTANCE_PID_FILE=\"${instance_pid_file:-}\""
    echo "INSTANCE_TAIL_PID_FILE=\"${tail_pid_file:-}\""
    echo "INSTANCE_PLATFORM=\"${blueprint_platform:-linux}\""
    echo "INSTANCE_LEVEL_NAME=\"${blueprint_level_name:-default}\""
    echo "INSTANCE_STEAM_APP_ID=\"${blueprint_steam_app_id:-0}\""
    echo "INSTANCE_IS_STEAM_ACCOUNT_REQUIRED=\"${blueprint_is_steam_account_required:-0}\""
    echo "INSTANCE_SAVE_COMMAND_TIMEOUT_S=\"${instance_save_command_timeout_s:-5}\""
    echo "INSTANCE_STOP_COMMAND_TIMEOUT_S=\"${instance_stop_command_timeout_s:-30}\""
    echo "INSTANCE_COMPRESS_BACKUPS=\"${instance_compress_backups:-0}\""
    echo "INSTANCE_USE_UPNP=\"${instance_use_upnp:-0}\""
    echo "INSTANCE_UPNP_PORTS=(${instance_upnp_ports[*]})"

  } >>"$instance_config_file"

  # Return success
  return 0
}

# Read the argument values
while [[ "$#" -gt 0 ]]; do
  case $1 in
  -h | --help)
    usage && exit 0
    ;;
  --create-instance-config)
    shift
    if [[ $# -lt 2 ]]; then
      __print_error "Missing arguments for --create-instance-config" && exit $EC_MISSING_ARG
    fi
    instance_config_file=$1
    blueprint_abs_path=$2
    __create_native_instance_config "$instance_config_file" "$blueprint_abs_path"
    exit $?
    ;;
  *)
    break
    ;;
  esac
done
