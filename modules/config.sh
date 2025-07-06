#!/usr/bin/env bash

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

# shellcheck disable=SC1091
source "$(dirname "$(readlink -f "$0")")/../lib/bootstrap.sh"

self="$(basename "$0")"

function usage() {
  local UNDERLINE="\e[4m"
  local END="\e[0m"

  echo -e "${UNDERLINE}Configuration Management for Krystal Game Server Manager${END}

Manages KGSM configuration settings through command-line interface.

${UNDERLINE}Usage:${END}
  $self [OPTIONS] [COMMAND]

${UNDERLINE}Options:${END}
  -h, --help                  Display this help information

${UNDERLINE}Commands:${END}
  --set KEY=VALUE             Set a configuration value
                              Example: --set enable_logging=true
  --get KEY                   Get a configuration value
                              Example: --get enable_logging
  --list                      List all configuration values
  --list --json               Output configuration in JSON format
  --reset                     Reset configuration to defaults
  --validate                  Validate current configuration
  [no command]                Open configuration in editor (default behavior)

${UNDERLINE}Examples:${END}
  $self --set enable_logging=true
  $self --set instance_suffix_length=3
  $self --get enable_systemd
  $self --list
  $self --list --json
  $self --reset
  $self --validate

${UNDERLINE}Notes:${END}
  • All configuration changes are validated before being applied
  • Boolean values must be 'true' or 'false'
  • Integer values must be positive numbers
  • Use --list to see all available configuration keys
  • Configuration is automatically backed up before changes
"
}

# shellcheck disable=SC2199
if [[ $@ =~ "--json" ]]; then
  json_format=1
  for a; do
    shift
    case $a in
    --json) continue ;;
    *) set -- "$@" "$a" ;;
    esac
  done
fi

# Filter out --config arguments (passed from kgsm.sh)
filtered_args=()
for arg in "$@"; do
  case "$arg" in
  --config)
    # do nothing
    ;;
  -h | --help)
    usage && exit 0
    ;;
  *)
    filtered_args+=("$arg")
    ;;
  esac
done

set -- "${filtered_args[@]}"

function _set_config() {
  local key_value="$1"

  if [[ -z "$key_value" ]]; then
    __print_error "Missing argument: KEY=VALUE"
    __print_error "Example: --set enable_logging=true"
    return $EC_MISSING_ARG
  fi

  # Parse key=value
  if [[ ! "$key_value" =~ ^([^=]+)=(.*)$ ]]; then
    __print_error "Invalid format: '$key_value'"
    __print_error "Expected format: KEY=VALUE"
    __print_error "Example: --set enable_logging=true"
    return $EC_INVALID_ARG
  fi

  local key="${BASH_REMATCH[1]}"
  local value="${BASH_REMATCH[2]}"

  # Set the config value using the lib module function
  __set_config_value "$key" "$value"
}

function _get_config() {
  local key="$1"

  if [[ -z "$key" ]]; then
    __print_error "Missing argument: KEY"
    __print_error "Example: --get enable_logging"
    return $EC_MISSING_ARG
  fi

  # Get the config value using the lib module function
  local value
  value=$(__get_config_value_safe "$key")
  local exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    echo "$value"
  fi

  return $exit_code
}

function _list_config() {
  # List config values using the lib module function
  __list_config_values "$json_format"
  return $?
}

function _reset_config() {
  # Reset config using the lib module function
  __reset_config
  return $?
}

function _validate_config() {
  # Validate config using the lib module function
  __validate_current_config
  return $?
}

function _open_editor() {
  # Open config file in editor (default behavior)
  ${EDITOR:-vim} "$CONFIG_FILE" || {
    __print_error "Failed to open $CONFIG_FILE with ${EDITOR:-vim}"
    return $EC_GENERAL
  }
  return 0
}

# Main argument processing
while [[ $# -gt 0 ]]; do
  case "$1" in
  --set)
    shift
    if [[ -z "$1" ]]; then
      __print_error "Missing argument for --set"
      __print_error "Example: --set enable_logging=true"
      exit $EC_MISSING_ARG
    fi
    _set_config "$1"
    exit $?
    ;;
  --get)
    shift
    if [[ -z "$1" ]]; then
      __print_error "Missing argument for --get"
      __print_error "Example: --get enable_logging"
      exit $EC_MISSING_ARG
    fi
    _get_config "$1"
    exit $?
    ;;
  --list)
    _list_config
    exit $?
    ;;
  --reset)
    _reset_config
    exit $?
    ;;
  --validate)
    _validate_config
    exit $?
    ;;
  *)
    __print_error "Invalid argument $1"
    exit $EC_INVALID_ARG
    ;;
  esac
  shift
done

# If no command specified, open in editor (default behavior)
_open_editor
exit $?
