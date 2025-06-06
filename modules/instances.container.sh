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
  module_common="$(find "$KGSM_ROOT" -type f -name common.sh -print -quit)"
  [[ -z "$module_common" ]] && echo "${0##*/} ERROR: Failed to load module common.sh" >&2 && exit 1
  # shellcheck disable=SC1090
  source "$module_common" || exit 1
fi

function usage() {
  echo "Manages containerized game server instance creation and management

Usage:
  $(basename "$0") OPTION

Options:
  -h, --help                      Prints this message

  --create-instance-config        Internal use: Creates additional configuration
    <config-file> <compose-file>  for a container instance.
                                  <config-file> Path to the instance configuration file
                                  <compose-file> Path to the docker-compose.yml file
                                  This function extracts port configurations from the
                                  docker-compose file and adds them to the instance
                                  configuration.

Command Interface:
  This module is designed to be used by the main instances.sh module and
  provides container-specific implementation for Docker-based game servers.
  It supports Docker containers deployed via docker-compose files.

Examples:
  $(basename "$0") --create-instance-config /path/to/instance.ini /path/to/blueprint.docker-compose.yml
"
}

[[ $# -eq 0 ]] && usage && exit 1

# This function is meant to complement already existing instance configurations
# for container instances. It will append necessary configuration to the
# instance config file to ensure it can be managed correctly by KGSM.
#
# It expects the following variables to be set in the instance config file:
# INSTANCE_ID
# INSTANCE_WORKING_DIR
# INSTANCE_VERSION_FILE
# INSTANCE_RUNTIME
# INSTANCE_LIFECYCLE_MANAGER
# INSTANCE_INSTALL_DATETIME
# INSTANCE_MANAGE_FILE
#
# It also expects the blueprint file path to be passed as the second argument.
# The blueprint file should be a docker-compose.yml or docker-compose.yaml file.
function __create_container_instance_config() {
  local instance_config_file="$1"
  local blueprint_abs_path="$2"

  # Extract the blueprint name from the path (remove extension and directory)
  local blueprint_name
  blueprint_name=$(basename "$blueprint_abs_path" .docker-compose.yml)
  # Handle .yaml extension as well
  if [[ "$blueprint_name" == "$blueprint_abs_path" ]]; then
    blueprint_name=$(basename "$blueprint_abs_path" .yaml)
  fi

  set -x

  # Grab ports from the docker-compose file and format them in the UFW format
  local instance_ports
  instance_ports=$(__parse_docker_compose_to_ufw_ports "$blueprint_abs_path")

  if [[ $? -ne 0 ]]; then
    __print_error "Failed to parse ports from the docker-compose file: $blueprint_abs_path"
    return $EC_INVALID_ARG
  fi

  # Append the necessary variables to the instance config file
  {
    echo "INSTANCE_RUNTIME=\"container\""
    [[ -n "${instance_ports[*]:-}" ]] && echo "INSTANCE_PORTS=\"${instance_ports:-}\""

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
    __create_container_instance_config "$instance_config_file" "$blueprint_abs_path"
    exit $?
    ;;
  *)
    break
    ;;
  esac
done
