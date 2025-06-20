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
  local UNDERLINE="\e[4m"
  local END="\e[0m"

  echo -e "${UNDERLINE}Native Instance Management for KGSM${END}

Handles configuration and management of game servers that run directly on the host system.

${UNDERLINE}Usage:${END}
  $(basename "$0") [OPTIONS]

${UNDERLINE}Options:${END}
  -h, --help                      Display this help information

${UNDERLINE}Configuration:${END}
  --create-instance-config        Create specific configuration for native game server instances
    <config-file> <blueprint-file> Parameters:
                                  <config-file> - Path to the instance configuration file
                                  <blueprint-file> - Path to the blueprint (.bp) file

                                  Processes blueprint specifications to configure executables,
                                  command-line arguments, port settings, and other parameters
                                  needed for native game servers

${UNDERLINE}Module Information:${END}
  This module provides the implementation for game servers that run directly on the host
  system rather than in containers. It's designed to work with the main instances.sh module
  and supports various game engines through blueprint (.bp) file definitions.

${UNDERLINE}Examples:${END}
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
    java | docker | wine | wine64)
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

  # UPnP port configuration if applicable
  export instance_enable_port_forwarding="${config_enable_port_forwarding:-false}"
  local instance_upnp_ports=()
  if [[ -n "${blueprint_ports:-}" ]]; then
    if ! output=$(__parse_ufw_to_upnp_ports "$blueprint_ports") || ! read -ra instance_upnp_ports <<<"$output"; then
      __print_warning "Failed to generate 'instance_upnp_ports'. Disabling UPnP for instance $instance_name"
      export instance_enable_port_forwarding="false"
    fi
  fi

  # Write native specific configuration
  {
    echo "# --- Native Instance Specific Configuration ---"
    echo ""

    echo "# Specifies that this is a native (non-containerized) game server"
    echo "runtime=\"native\""
    echo ""

    echo "# Network ports used by the game server in UFW format"
    echo "ports=\"${blueprint_ports:-}\""
    echo ""

    echo "# Command to gracefully stop the server"
    echo "stop_command=\"${blueprint_stop_command:-}\""
    echo ""

    echo "# Command to save the game state"
    echo "save_command=\"${blueprint_save_command:-}\""
    echo ""

    echo "# Target platform for the game server (usually linux)"
    echo "platform=\"${blueprint_platform:-linux}\""
    echo ""

    echo "# Default level/world name for the game server"
    echo "level_name=\"${blueprint_level_name:-default}\""
    echo ""

    echo "# Steam App ID for SteamCMD downloads"
    echo "steam_app_id=\"${blueprint_steam_app_id:-0}\""
    echo ""

    echo "# Whether a Steam account is required for downloading (0=no, 1=yes)"
    echo "is_steam_account_required=\"${blueprint_is_steam_account_required:-0}\""
    echo ""

    echo "# Timeout in seconds to wait after sending save command"
    echo "save_command_timeout_seconds=\"${config_instance_save_command_timeout_seconds:-5}\""
    echo ""

    echo "# Timeout in seconds to wait after sending stop command"
    echo "stop_command_timeout_seconds=\"${config_instance_stop_command_timeout_seconds:-30}\""
    echo ""

    echo "# Whether to compress backups to save space"
    echo "compress_backups=\"${config_enable_backup_compression:-0}\""
    echo ""

    echo "# Whether to enable UPnP port forwarding"
    echo "enable_port_forwarding=\"${instance_enable_port_forwarding:-false}\""
    echo ""

    echo "# List of ports to forward via UPnP"
    echo "upnp_ports=(${instance_upnp_ports[*]})"
    echo ""

    echo "# Path to the game server executable"
    echo "executable_file=\"${blueprint_executable_file:-}\""
    echo ""

    echo "# Command line arguments for the game server executable"
    echo "executable_arguments=\"${blueprint_executable_arguments:-}\""
    echo ""

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
