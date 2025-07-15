#!/usr/bin/env bash

# shellcheck disable=SC1091
source "$(dirname "$(readlink -f "$0")")/../lib/bootstrap.sh"

function usage() {
  local UNDERLINE="\e[4m"
  local END="\e[0m"

  echo -e "${UNDERLINE}Directory Management for Krystal Game Server Manager${END}

Creates and manages the directory structure needed for game server instances.

${UNDERLINE}Usage:${END}
  $(basename "$0") <command> [options]

${UNDERLINE}Commands:${END}
  create                      Create directory structure for an instance
                              Creates installation, data, logs, and backup directories
  remove                      Remove directory structure for an instance
                              Warning: This will delete all instance data
  help [command]              Display help information

${UNDERLINE}Options:${END}
  -i, --instance <name>       Target instance name (required)
                              The .ini extension is not required
  --help                      Display help for specific command

${UNDERLINE}Examples:${END}
  $(basename "$0") create --instance valheim-h1up6V
  $(basename "$0") remove -i valheim-h1up6V
  $(basename "$0") help create
  $(basename "$0") create --help
"
}

function usage_create() {
  local UNDERLINE="\e[4m"
  local END="\e[0m"

  echo -e "${UNDERLINE}Create Directory Structure${END}

Creates the complete directory structure for a game server instance.

${UNDERLINE}Usage:${END}
  $(basename "$0") create [-i, --instance] <name>

${UNDERLINE}Options:${END}
  -i, --instance <name>       Target instance name (required)
  --help                      Display this help information

${UNDERLINE}Description:${END}
This command creates the following directory structure:
  • working_dir/              Main instance directory
  • working_dir/backups/      Instance backup files
  • working_dir/install/      Game server installation files
  • working_dir/saves/        Game save files and world data
  • working_dir/temp/         Temporary files during operations
  • working_dir/logs/         Instance-specific log files

The directory paths are automatically added to the instance configuration file.

${UNDERLINE}Examples:${END}
  $(basename "$0") create --instance valheim-h1up6V
  $(basename "$0") create -i minecraft-server
"
}

function usage_remove() {
  local UNDERLINE="\e[4m"
  local END="\e[0m"

  echo -e "${UNDERLINE}Remove Directory Structure${END}

Removes the complete directory structure for a game server instance.

${UNDERLINE}Usage:${END}
  $(basename "$0") remove [-i, --instance] <name>

${UNDERLINE}Options:${END}
  -i, --instance <name>       Target instance name (required)
  --help                      Display this help information

${UNDERLINE}Warning:${END}
This command will permanently delete ALL instance data including:
  • Game server files
  • Save files and world data
  • Backup files
  • Log files
  • Configuration data

This action cannot be undone!

${UNDERLINE}Examples:${END}
  $(basename "$0") remove --instance valheim-h1up6V
  $(basename "$0") remove -i minecraft-server
"
}

# Load required libraries
logic_directories=$(__find_logic_library directories.sh)
# shellcheck disable=SC1090
source "$logic_directories" || {
  __print_error "Failed to load directories logic library"
  exit $EC_FAILED_SOURCE
}

events_library=$(__find_library events.sh)
# shellcheck disable=SC1090
source "$events_library" || {
  __print_error "Failed to load events library"
  exit $EC_FAILED_SOURCE
}

# Command wrapper for create
function _cmd_create() {
  local instance_name=""

  # Parse create command options
  while [[ "$#" -gt 0 ]]; do
    case $1 in
      -i | --instance)
        shift
        [[ -z "$1" ]] && __print_error "Missing argument for -i, --instance" && exit $EC_MISSING_ARG
        instance_name="$1"
        ;;
      --help)
        usage_create && exit 0
        ;;
      *)
        __print_error "Invalid option for create command: $1"
        __print_error "Use '$(basename "$0") create --help' for usage information"
        exit $EC_INVALID_ARG
        ;;
    esac
    shift
  done

  # Validate required parameters
  if [[ -z "$instance_name" ]]; then
    __print_error "Missing required option: -i, --instance"
    __print_error "Use '$(basename "$0") create --help' for usage information"
    exit $EC_MISSING_ARG
  fi

  # Validate instance name and get config file
  local instance_config_file
  if ! instance_config_file=$(validate_instance_name "$instance_name"); then
    exit $?
  fi

  # Validate working directory configuration
  local instance_working_dir
  if ! instance_working_dir=$(validate_working_directory "$instance_config_file"); then
    exit $?
  fi

  # Call pure logic function
  __print_info "Creating directories for instance $instance_name"
  local exit_code
  __logic_create_directories "$instance_name" "$instance_config_file" "$instance_working_dir"
  exit_code=$?

  # Handle result based on exit code
  case $exit_code in
    $EC_SUCCESS_DIRECTORIES_CREATED)
      __print_success "Directories created successfully for instance $instance_name"
      # Dispatch event
      __dispatch_event_from_exit_code "$exit_code" "$instance_name"
      exit 0
      ;;
    *)
      __print_error "Failed to create directories for instance $instance_name"
      exit $exit_code
      ;;
  esac
}

# Command wrapper for remove
function _cmd_remove() {
  local instance_name=""

  # Parse remove command options
  while [[ "$#" -gt 0 ]]; do
    case $1 in
      -i | --instance)
        shift
        [[ -z "$1" ]] && __print_error "Missing argument for -i, --instance" && exit $EC_MISSING_ARG
        instance_name="$1"
        ;;
      --help)
        usage_remove && exit 0
        ;;
      *)
        __print_error "Invalid option for remove command: $1"
        __print_error "Use '$(basename "$0") remove --help' for usage information"
        exit $EC_INVALID_ARG
        ;;
    esac
    shift
  done

  # Validate required parameters
  if [[ -z "$instance_name" ]]; then
    __print_error "Missing required option: -i, --instance"
    __print_error "Use '$(basename "$0") remove --help' for usage information"
    exit $EC_MISSING_ARG
  fi

  # Validate instance name and get config file
  local instance_config_file
  if ! instance_config_file=$(validate_instance_name "$instance_name"); then
    exit $?
  fi

  # Validate working directory configuration
  local instance_working_dir
  if ! instance_working_dir=$(validate_working_directory "$instance_config_file"); then
    exit $?
  fi

  # Call pure logic function
  __print_info "Removing directories for instance $instance_name"
  local exit_code
  __logic_remove_directories "$instance_name" "$instance_working_dir"
  exit_code=$?

  # Handle result based on exit code
  case $exit_code in
    $EC_SUCCESS_DIRECTORIES_REMOVED)
      __print_success "Directories removed successfully for instance $instance_name"
      # Dispatch event
      __dispatch_event_from_exit_code "$exit_code" "$instance_name"
      exit 0
      ;;
    *)
      __print_error "Failed to remove directories for instance $instance_name"
      exit $exit_code
      ;;
  esac
}

# Handle debug flag
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

# Check for help flag first
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
  usage && exit 0
fi

# Require at least one argument
if [[ "$#" -eq 0 ]]; then
  __print_error "Missing command"
  __print_error "Use '$(basename "$0") --help' for usage information"
  exit $EC_MISSING_ARG
fi

# Parse main command
case "$1" in
  create)
    shift
    _cmd_create "$@"
    ;;
  remove)
    shift
    _cmd_remove "$@"
    ;;
  help)
    shift
    case "$1" in
      create)
        usage_create && exit 0
        ;;
      remove)
        usage_remove && exit 0
        ;;
      "")
        usage && exit 0
        ;;
      *)
        __print_error "Unknown command for help: $1"
        __print_error "Available commands: create, remove"
        exit $EC_INVALID_ARG
        ;;
    esac
    ;;
  *)
    __print_error "Unknown command: $1"
    __print_error "Use '$(basename "$0") --help' for usage information"
    exit $EC_INVALID_ARG
    ;;
esac
