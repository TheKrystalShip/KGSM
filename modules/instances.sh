#!/usr/bin/env bash

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

function usage() {
  local UNDERLINE="\e[4m"
  local END="\e[0m"

  echo -e "${UNDERLINE}Instance Management for Krystal Game Server Manager${END}

Manages instance creation and provides comprehensive information about game server instances.

${UNDERLINE}Usage:${END}
  $(basename "$0") [OPTIONS]

${UNDERLINE}Options:${END}
  -h, --help                      Display this help information

${UNDERLINE}Instance Creation & Identification:${END}
  --generate-id <blueprint>       Create a unique instance identifier for a new server

${UNDERLINE}Listing & Information:${END}
  --list [blueprint]              Display all instances with basic information
                                  Optionally filter by blueprint name
  --list --detailed [blueprint]   Show detailed information about instances
                                  Includes configuration and status details
  --list --json [blueprint]       Output instance list in JSON format
  --list --json --detailed        Output detailed instance information in JSON format
      [blueprint]                 Suitable for programmatic consumption
  --status <instance>             Display comprehensive status information for a specific instance
                                  Includes running state, resource usage, and configuration details

${UNDERLINE}Instance Control:${END}
  --save <instance>               Issue a save command to the specified instance
  --input <command>               Send a command to the instance's interactive console
                                  Shows the last 10 log lines after execution
  --create <blueprint>
    --install-dir <install_dir>   Creates a new instance for the given blueprint
                                  and returns the name of the instance config
                                  file.
                                  <blueprint> The blueprint file to create an
                                  instance from.
                                  <install_dir> Directory where the instance
                                  will be created.
    --name <name>                 Optional: Specify an instance identifier
                                  instead of using an auto-generated one.
  --remove <instance>             Remove an instance's configuration
  --find <instance>               Find the absolute path to an instance config file
  --info <instance>               Print a detailed description of an instance
  --info <instance> --json        Print a detailed description of an instance in
                                  JSON format.

Examples:
  $(basename "$0") --create factorio.bp --id factorio-01 --install-dir /opt
  $(basename "$0") --status factorio-01
  $(basename "$0") --list --detailed factorio.bp
  $(basename "$0") --find factorio-01
"
}

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

[[ $# -eq 0 ]] && usage && exit 1

# Read the argument values
while [[ "$#" -gt 0 ]]; do
  case $1 in
  -h | --help)
    usage && exit 0
    ;;
  *)
    break
    ;;
  esac
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

function _generate_unique_instance_name() {
  local blueprint_name
  blueprint_name="$(__extract_blueprint_name $1)"
  local instance_name

  # If no instance with the same name as the blueprint exists, then don't
  # create a name with a numbered id, just use the same name as the blueprint
  if [[ ! -f "$INSTANCES_SOURCE_DIR/$blueprint_name/${blueprint_name}.ini" ]]; then
    echo "$blueprint_name" && return
  fi

  while :; do
    instance_name=$(tr -dc 0-9 </dev/urandom | head -c "${config_instance_suffix_length:-2}")
    instance_name="${blueprint_name}-${instance_name}"

    if [[ ! -f "$INSTANCES_SOURCE_DIR/$blueprint_name/${instance_name}.ini" ]]; then
      echo "$instance_name" && return
    fi
  done
}

# Function to check if an instance config file exists
function __instance_config_file_exists() {
  local instance_name="$1"
  local blueprint="$2"

  if [[ -z "$instance_name" ]]; then
    __print_error "Instance ID is not set"
    return $EC_INVALID_ARG
  fi

  if [[ -z "$blueprint" ]]; then
    __print_error "Blueprint is not set"
    return $EC_INVALID_ARG
  fi

  # If $instance_name doesn't end in .ini, append it
  if [[ ! "$instance_name" =~ \.ini$ ]]; then
    instance_name="${instance_name}.ini"
  fi

  # Path to the instance config file
  local instance_config_file="${INSTANCES_SOURCE_DIR}/${blueprint}/${instance_name}.ini"

  # Check if the instance config file exists
  # If it does, return 0 (success), otherwise return 1 (failure)
  if [[ -f "$instance_config_file" ]]; then
    return 0
  else
    return 1
  fi
}

# Create an instance config file for the given instance id and blueprint
# Returns the path to the instance config file.
function _create_instance_config_file() {
  local instance_name="$1"
  local blueprint="$2"

  if [[ -z "$instance_name" ]]; then
    __print_error "Instance ID name is not set"
    return $EC_INVALID_ARG
  fi

  if [[ -z "$blueprint" ]]; then
    __print_error "Blueprint is not set"
    return $EC_INVALID_ARG
  fi

  local blueprint_name
  blueprint_name="$(__extract_blueprint_name "$blueprint")"

  # Create the instance directory if it doesn't exist
  local instance_dir_path="${INSTANCES_SOURCE_DIR}/${blueprint_name}"
  __create_dir "$instance_dir_path"

  # Create the instance config file
  local instance_config_file="${instance_dir_path}/${instance_name}.ini"
  __create_file "$instance_config_file"

  # Return the instance config file path
  echo "$instance_config_file"
}

# Create a base instance configuration file with common variables
function __create_base_instance() {
  local instance_config_file="$1"
  local instance_name="$2"
  local blueprint_abs_path="$3"
  local install_dir="$4"

  export instance_working_dir="${install_dir}/${instance_name}"
  export instance_version_file="${instance_working_dir}/.${instance_name}.version"

  export instance_config_file="${instance_working_dir}/${instance_name}.config.ini"

  export instance_lifecycle_manager="standalone"

  export instance_install_datetime="$(date +"%Y-%m-%dT%H:%M:%S")"

  export instance_manage_file="${instance_working_dir}/${instance_name}.manage.sh"

  export instance_pid_file="${instance_working_dir}/.${instance_name}.pid"
  export tail_pid_file="${instance_working_dir}/.${instance_name}.tail.pid"

  export instance_socket_file="${instance_working_dir}/.${instance_name}.stdin"

  # Get the executable subdirectory from the blueprint file
  export instance_install_subdir=$(grep "executable_subdirectory=" <"$blueprint_abs_path" | cut -d "=" -f2 | tr -d '"')

  # Calculate the launch directory
  export instance_launch_dir="$install_dir"
  if [[ -n "$instance_install_subdir" ]]; then
    export instance_launch_dir="$install_dir/$instance_install_subdir"
  fi

  export instance_logs_redirect="\$instance_logs_dir/\$instance_name-\$(date +\"%Y-%m-%dT%H:%M:%S\").log"

  # Write configuration to file with a single redirect
  # This avoids multiple file descriptor opens and is more efficient
  # Note: Variables are stored without the "instance_" prefix
  {
    echo "# KGSM Instance Configuration File"
    echo "# Created: $(date +"%Y-%m-%d %H:%M:%S")"
    echo "# This file contains configuration for a game server instance"
    echo "# Do not edit this file manually unless you know what you're doing"
    echo ""

    echo "# Name of the instance, used for identification and file naming"
    echo "name=\"$instance_name\""
    echo ""

    echo "# Path to the blueprint file used to create this instance"
    echo "blueprint_file=\"$blueprint_abs_path\""
    echo ""

    echo "# Directory where the instance files are stored"
    echo "working_dir=\"$instance_working_dir\""
    echo ""

    echo "# Path to the instance configuration file"
    echo "config_file=\"$instance_config_file\""
    echo ""

    echo "# Timestamp when the instance was installed"
    echo "install_datetime=\"$instance_install_datetime\""
    echo ""

    echo "# File that stores the current version of the game server"
    echo "version_file=\"$instance_version_file\""
    echo ""

    echo "# How the instance is managed (standalone, systemd)"
    echo "lifecycle_manager=\"$instance_lifecycle_manager\""
    echo ""

    echo "# Path to the management script for this instance"
    echo "management_file=\"$instance_manage_file\""
    echo ""

    echo "# Whether to automatically update the server before starting"
    echo "auto_update=\"${config_instance_auto_update_before_start:-false}\""
    echo ""

    echo "# File that stores the PID of the running server process"
    echo "pid_file=\"${instance_pid_file:-}\""
    echo ""

    echo "# File that stores the PID of the tail process for log following"
    echo "tail_pid_file=\"${tail_pid_file:-}\""
    echo ""

    echo "# Named pipe used for sending commands to the server"
    echo "socket_file=\"${instance_socket_file:-}\""
    echo ""

    echo "# Log redirection into file"
    echo "logs_redirect=\"$instance_logs_redirect\""
    echo ""

    echo "# Directory from which to launch the instance binary"
    echo "launch_dir=\"$instance_launch_dir\""
    echo ""

    echo "# If there's a specific subdirectory for the executable"
    echo "executable_subdirectory=\"$instance_install_subdir\""
    echo ""

  } >>"$instance_config_file"

  return 0
}

# IMPORTANT: This function cannot echo or print anything to stdout
# other than the final instance file path.
function _create_instance() {
  local blueprint=$1
  local install_dir=$2
  local identifier=${3:-}

  local blueprint_abs_path
  blueprint_abs_path="$(__find_blueprint "$blueprint")"

  # Extract the blueprint name from the path (remove extension and directory)
  local blueprint_name
  blueprint_name="$(__extract_blueprint_name "$blueprint_abs_path")"

  local instance_name
  instance_name=$identifier

  # Ensure instance_name is unique
  if [[ -z "$instance_name" ]]; then
    # If no identifier is provided, we generate a unique instance name
    instance_name="$(_generate_unique_instance_name "$blueprint_name")"
    export instance_name
  else
    # If an identifier is provided, we use it as the instance_name
    # We also need to ensure that the identifier is valid
    if __instance_config_file_exists "$instance_name" "$blueprint_name"; then
      __print_error "Instance with id \"$instance_name\" already exists for blueprint \"$blueprint_name\""
      return $EC_INVALID_INSTANCE
    fi
  fi

  # Temporary instance config file, we build from here until it's ready
  local instance_config_file
  instance_config_file="$(_create_instance_config_file "$instance_name" "$blueprint_name")"

  # All common instance variables are set in this function
  __create_base_instance "$instance_config_file" "$instance_name" "$blueprint_abs_path" "$install_dir"

  # Determine which specialized module to use for instance creation
  local instance_module=""
  local instance_type=""

  # $blueprint_abs_path is the absolute path to the blueprint file
  # We need to check the extension to determine instance type
  if [[ "$blueprint_abs_path" == *.bp ]]; then
    # Native instance
    instance_module="$(__find_module instances.native.sh)"
    instance_type="native"
  elif [[ "$blueprint_abs_path" == *.docker-compose.yml ]] || [[ "$blueprint_abs_path" == *.yaml ]]; then
    # Container instance
    instance_module="$(__find_module instances.container.sh)"
    instance_type="container"
  else
    __print_error "Invalid blueprint file: $blueprint_abs_path"
    return $EC_INVALID_BLUEPRINT
  fi

  # Ensure we found the appropriate module
  if [[ -z "$instance_module" ]]; then
    __print_error "Could not find module for $instance_type instances"
    return $EC_FAILED_FIND_MODULE
  fi

  # Delegate to the specialized module for instance creation
  # Use the module to add the instance-type specific configuration
  if ! "$instance_module" --create-instance-config "$instance_config_file" "$blueprint_abs_path" $debug; then
    __print_error "Failed to create instance configuration with specialized module"
    return $EC_FAILED_INSTANCE_CREATION
  fi

  # All done
  __emit_instance_created "$instance_name" "$blueprint"

  echo "$instance_name"
}

function _remove() {
  local instance=$1
  local instance_abs_path
  instance_abs_path="$(__find_instance_config "$instance")"

  local instance_blueprint_file
  instance_blueprint_file="$(grep "blueprint_file=" <"$instance_abs_path" | cut -d "=" -f2 | tr -d '"')"
  instance_blueprint_file="$(__extract_blueprint_name "$instance_blueprint_file")"

  # Remove instance config file
  if ! rm "$instance_abs_path"; then
    __print_error "Failed to remove $instance_abs_path"
    return $EC_FAILED_RM
  fi

  # Remove directory if no other instances are found
  local instances_dir
  instances_dir="${INSTANCES_SOURCE_DIR}/${instance_blueprint_file}"
  if [[ -z "$(ls -A "${instances_dir}")" ]]; then
    rmdir "${instances_dir}"
  fi

  __emit_instance_removed "${instance%.ini}"
  return 0
}

function _print_info() {
  local instance=$1

  __source_instance "$instance"

  {
    echo "Name:                $instance_name"
    echo "Lifecycle manager:   $instance_lifecycle_manager"

    local status=""
    if [[ "$instance_lifecycle_manager" == "systemd" ]]; then
      # systemctl return exit code 3 but it gives correct response
      if [[ $(type -t __disable_error_checking) == function ]]; then
        __disable_error_checking
      fi
      status="$(systemctl is-active "$instance_name")"
      if [[ $(type -t __enable_error_checking) == function ]]; then
        __enable_error_checking
      fi
    else
      status="$($instance_management_file --is-active &>/dev/null && echo "active" || echo "inactive")"
    fi

    echo "Status:              $status"
    echo "Configuration file:  $instance_config_file"

    if [[ -f "$instance_pid_file" ]]; then
      echo "PID:                 $(cat "$instance_pid_file")"
    fi
    if [[ "$instance_lifecycle_manager" == "standalone" ]]; then
      echo "Logs directory:      $instance_logs_dir"
    fi
    echo "Directory:           $instance_working_dir"
    echo "Installation date:   $instance_install_datetime"
    echo "Version:             $($instance_management_file --version)"
    echo "Blueprint:           $instance_blueprint_file"

    if [[ "$instance_lifecycle_manager" == "systemd" ]]; then
      if [[ -f "$instance_systemd_service_file" ]]; then
        echo "Service file:        $instance_systemd_service_file"
      fi
      if [[ -n "$instance_socket_file" ]]; then
        echo "Socket file:         $instance_socket_file"
      fi
    fi

    if [[ "$config_enable_firewall_management" == "true" ]]; then
      if [[ -f "$instance_ufw_file" ]]; then
        echo "Firewall rule:       $instance_ufw_file"
      fi
    fi

    echo ""
  } >&1
}

function _print_info_json() {
  local instance=$1

  # shellcheck disable=SC1090
  source "$(__find_instance_config "$instance")" || return "$EC_FAILED_SOURCE"

  local status=""
  if [[ "$instance_lifecycle_manager" == "systemd" ]]; then
    __disable_error_checking
    status="$(systemctl is-active "$instance_name")"
    __enable_error_checking
  else
    status="$([[ -f "$instance_pid_file" ]] && echo "active" || echo "inactive")"
  fi

  local pid
  pid=$([[ -f "$instance_pid_file" ]] && cat "$instance_pid_file" || echo "None")
  local logs_dir
  logs_dir=$([[ "$instance_lifecycle_manager" == "standalone" ]] && echo "$instance_logs_dir" || echo "None")
  local service_file
  service_file=$([[ "$instance_lifecycle_manager" == "systemd" ]] && [[ -f "$instance_systemd_service_file" ]] && echo "$instance_systemd_service_file" || echo "")
  local socket_file
  socket_file=$([[ "$instance_lifecycle_manager" == "systemd" ]] && [[ -n "$instance_socket_file" ]] && echo "$instance_socket_file" || echo "")
  local firewall_rule
  firewall_rule=$([[ "$config_enable_firewall_management" == "true" ]] && [[ -f "$instance_ufw_file" ]] && echo "$instance_ufw_file" || echo "")

  jq -n \
    --arg instance "$instance_name" \
    --arg lifecycleManager "$instance_lifecycle_manager" \
    --arg status "$status" \
    --arg pid "$pid" \
    --arg logsDir "$logs_dir" \
    --arg directory "$instance_working_dir" \
    --arg installDate "$instance_install_datetime" \
    --arg version "$INSTANCE_INSTALLED_VERSION" \
    --arg blueprint "$instance_blueprint_file" \
    --arg serviceFile "$service_file" \
    --arg socketFile "$socket_file" \
    --arg firewallRule "$firewall_rule" \
    '{
      Name: $instance,
      LifecycleManager: $lifecycleManager,
      Status: $status,
      PID: $pid,
      LogsDirectory: $logsDir,
      Directory: $directory,
      InstallationDate: $installDate,
      Version: $version,
      Blueprint: $blueprint,
      ServiceFile: $serviceFile,
      SocketFile: $socketFile,
      FirewallRule: $firewallRule
    }'
}

function _list_instances() {
  local blueprint=${1:-}
  local detailed=${2:-}

  shopt -s extglob nullglob

  local -a instances=()
  if [[ -z "$blueprint" ]]; then
    instances=("$INSTANCES_SOURCE_DIR"/**/*.ini)
  else
    # shellcheck disable=SC2034
    instances=("$INSTANCES_SOURCE_DIR/$blueprint"/*.ini)
  fi

  # Remove trailing directories from path, leave only filename
  for i in "${!instances[@]}"; do
    # instances["$i"]=$(basename "${instances[$i]}")
    local filename
    filename="$(basename "${instances[$i]}")"

    if [[ -z "$detailed" ]]; then
      echo "${filename%.ini}"
    else
      _print_info "$(basename "${instances[$i]}")"
    fi
  done
}

function _list_instances_json() {
  local blueprint=${1:-}
  local detailed=${2:-}

  shopt -s extglob nullglob

  local -a instances=()
  if [[ -z "$blueprint" ]]; then
    instances=("$INSTANCES_SOURCE_DIR"/**/*.ini)
  else
    # shellcheck disable=SC2034
    instances=("$INSTANCES_SOURCE_DIR/$blueprint"/*.ini)
  fi

  filenames=("${instances[@]##*/}")  # Remove paths
  filenames=("${filenames[@]%.ini}") # Remove extensions

  if [[ -z "$detailed" ]]; then
    jq -n --argjson instances_list "$(printf '%s\n' "${filenames[@]}" | jq -R . | jq -s .)" '$instances_list'
  else
    # Build a JSON object with instance contents
    jq -n --argjson instances_list \
      "$(for instance in "${filenames[@]}"; do
        # Get the content of an instance as JSON
        local content
        content=$(_print_info_json "${instance##*/}")
        # Skip instances with invalid content
        if [[ $? -ne 0 || -z "$content" ]]; then
          continue
        fi
        jq -n --arg key "${instance##*/}" --argjson value "$content" '{"key": $key, "value": $value}'
      done | jq -s 'from_entries')" '$instances_list'
  fi
}

function _get_instance_status() {
  local instance=$1

  # shellcheck disable=SC1090
  source "$(__find_instance_config "$instance")" || return "$EC_FAILED_SOURCE"

  if [[ "$instance_lifecycle_manager" == "systemd" ]]; then
    # systemctl status doesn't require sudo
    systemctl status "${instance%.ini}" --no-pager
    # systemctl status returns exit code 3, but it prints everything we need
    # so just return 0 afterwords to exit the function
    return 0
  else
    _print_info "$instance"
  fi
}

function _send_save_to_instance() {
  local instance=$1

  # shellcheck disable=SC1090
  source "$(__find_instance_config "$instance")" || return "$EC_FAILED_SOURCE"

  "$instance_management_file" --save $debug
}

function _send_input_to_instance() {
  local instance=$1
  local command=$2

  # shellcheck disable=SC1090
  source "$(__find_instance_config "$instance")" || return "$EC_FAILED_SOURCE"

  "$instance_management_file" --input "$command" $debug
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

while [[ $# -gt 0 ]]; do
  case "$1" in
  --list)
    shift
    while [[ $# -gt 0 ]]; do
      case "$1" in
      --detailed)
        detailed=1
        ;;
      *)
        blueprint=$1
        ;;
      esac
      shift
    done
    if [[ -z "$json_format" ]]; then
      _list_instances "$blueprint" "$detailed"
      exit $?
    else
      _list_instances_json "$blueprint" "$detailed"
      exit $?
    fi
    ;;
  --generate-id)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <blueprint>" && exit $EC_MISSING_ARG
    _generate_unique_instance_name "$1"
    exit $?
    ;;
  --input)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <instance>" && exit $EC_MISSING_ARG
    instance=$1
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <command>" && exit $EC_MISSING_ARG
    command=$1
    _send_input_to_instance "$instance" "$command"
    exit $?
    ;;
  --create)
    blueprint=
    install_dir=
    identifier=
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <blueprint>" && exit $EC_MISSING_ARG
    blueprint=$1
    shift
    if [[ -n "$1" ]]; then
      while [[ $# -ne 0 ]]; do
        case "$1" in
        --install-dir)
          shift
          [[ -z "$1" ]] && __print_error "Missing argument <install_dir>" && exit $EC_MISSING_ARG
          install_dir=$1
          ;;
        --name)
          shift
          [[ -z "$1" ]] && __print_error "Missing argument <id>" && exit $EC_MISSING_ARG
          identifier=$1
          ;;
        *)
          __print_error "Invalid argument $1" && exit $EC_INVALID_ARG
          ;;
        esac
        shift
      done
    fi
    _create_instance "$blueprint" "$install_dir" $identifier
    exit $?
    ;;
  --status)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <instance>" && exit $EC_MISSING_ARG
    _get_instance_status "$1"
    exit $?
    ;;
  --save)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <instance>" && exit $EC_MISSING_ARG
    _send_save_to_instance "$1"
    exit $?
    ;;
  --remove)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <instance>" && exit $EC_MISSING_ARG
    _remove "$1"
    exit $?
    ;;
  --find)
    shift
    if [[ -z "$1" ]]; then
      __print_error "Missing argument <instance>"
      exit $EC_MISSING_ARG
    fi

    instance=$1
    instance_path=$(__find_instance_config "$instance")
    if [[ -z "$instance_path" ]]; then
      __print_error "Instance '$instance' not found"
      exit $EC_NOT_FOUND
    fi

    echo "$instance_path"
    exit 0
    ;;
  --info)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <instance>" && exit $EC_MISSING_ARG
    instance=$1
    if [[ -z "$json_format" ]]; then
      _print_info "$instance"
    else
      _print_info_json "$instance"
    fi
    exit $?
    ;;
  *)
    __print_error "Invalid argument $1" && exit $EC_INVALID_ARG
    ;;
  esac
  shift
done
