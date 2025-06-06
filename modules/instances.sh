#!/usr/bin/env bash

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

function usage() {
  echo "Manages instance creation and gathers information post-creation

Usage:
  $(basename "$0") OPTION

Options:
  -h, --help                      Prints this message

  --generate-id <blueprint>       Create a unique instance identifier
  --list [blueprint]              Prints a list of all instances.
  --list --detailed [blueprint]   Print a list with detailed information about
                                  instances.
  --list --json [blueprint]       Prints a JSON formatted list of instances
  --list --json --detailed        Print a list with detailed information of
      [blueprint]                 instances.
                                  Optionally a blueprint name can be provided
                                  to show only instances of that blueprint.
  --status <instance>             Return a detailed running status.
  --save <instance>               Issue the save command to the instance.
  --input <command>               Issue a command to the instance if it has an
                                  interactive console. Displays the last 10
                                  lines of the instance log after issuing the
                                  command.
  --create <blueprint>
    --install-dir <install_dir>   Creates a new instance for the given blueprint
                                  and returns the name of the instance config
                                  file.
                                  <blueprint> The blueprint file to create an
                                  instance from.
                                  <install_dir> Directory where the instance
                                  will be created.
    --id <identifier>             Optional: Specify an instance identifier
                                  instead of using an auto-generated one.
  --remove <instance>             Remove an instance's configuration
  --info <instance>               Print a detailed description of an instance
  --info <instance> --json        Print a detailed description of an instance in
                                  JSON format.

Examples:
  $(basename "$0") --create factorio.bp --id factorio-01 --install-dir /opt
  $(basename "$0") --status factorio-01
  $(basename "$0") --list --detailed factorio.bp
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
  module_common="$(find "$KGSM_ROOT" -type f -name common.sh -print -quit)"
  [[ -z "$module_common" ]] && echo "${0##*/} ERROR: Failed to load module common.sh" >&2 && exit 1
  # shellcheck disable=SC1090
  source "$module_common" || exit 1
fi

function _generate_unique_instance_name() {
  local blueprint_name
  blueprint_name="$(__extract_blueprint_name $1)"
  local instance_id

  # If no instance with the same name as the blueprint exists, then don't
  # create a name with a numbered id, just use the same name as the blueprint
  if [[ ! -f "$INSTANCES_SOURCE_DIR/$blueprint_name/${blueprint_name}.ini" ]]; then
    echo "$blueprint_name" && return
  fi

  while :; do
    instance_id=$(tr -dc 0-9 </dev/urandom | head -c "${INSTANCE_RANDOM_CHAR_COUNT:-2}")
    instance_id="${blueprint_name}-${instance_id}"

    if [[ ! -f "$INSTANCES_SOURCE_DIR/$blueprint_name/${instance_id}.ini" ]]; then
      echo "$instance_id" && return
    fi
  done
}

# Function to check if an instance config file exists
function __instance_config_file_exists() {
  local instance_id="$1"
  local blueprint="$2"

  if [[ -z "$instance_id" ]]; then
    __print_error "Instance ID is not set"
    return $EC_INVALID_ARG
  fi

  if [[ -z "$blueprint" ]]; then
    __print_error "Blueprint is not set"
    return $EC_INVALID_ARG
  fi

  # If $instance_id doesn't end in .ini, append it
  if [[ ! "$instance_id" =~ \.ini$ ]]; then
    instance_id="${instance_id}.ini"
  fi

  # Path to the instance config file
  local instance_config_file="${INSTANCES_SOURCE_DIR}/${blueprint}/${instance_id}.ini"

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
  local instance_id="$1"
  local blueprint="$2"

  if [[ -z "$instance_id" ]]; then
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
  local instance_config_file="${instance_dir_path}/${instance_id}.ini"
  __create_file "$instance_config_file"

  # Return the instance config file path
  echo "$instance_config_file"
}

# Create a base instance configuration file with common variables
function __create_base_instance() {
  local instance_config_file="$1"
  local instance_id="$2"
  local blueprint_abs_path="$3"
  local install_dir="$4"

  local instance_working_dir="${install_dir}/${instance_id}"
  local instance_version_file="${instance_working_dir}/.${instance_id}.version"

  local instance_lifecycle_manager
  [[ "$USE_SYSTEMD" -eq 0 ]] && instance_lifecycle_manager="standalone" || instance_lifecycle_manager="systemd"

  local instance_systemd_service_file="${SYSTEMD_DIR}/${INSTANCE_ID}.service"
  local instance_systemd_socket_file="${SYSTEMD_DIR}/${INSTANCE_ID}.socket"

  local instance_ufw_file="${UFW_RULES_DIR}/kgsm-${instance_id}"

  local instance_install_datetime
  instance_install_datetime=$(date +"%Y-%m-%d %H:%M:%S")

  local instance_manage_file="${instance_working_dir}/${instance_id}.manage.sh"

  # Write configuration to file with a single redirect
  # This avoids multiple file descriptor opens and is more efficient
  {
    echo "INSTANCE_ID=\"$instance_id\""
    echo "INSTANCE_BLUEPRINT_FILE=\"$blueprint_abs_path\""
    echo "INSTANCE_WORKING_DIR=\"$instance_working_dir\""
    echo "INSTANCE_INSTALL_DATETIME=\"$instance_install_datetime\""
    echo "INSTANCE_VERSION_FILE=\"$instance_version_file\""
    echo "INSTANCE_LIFECYCLE_MANAGER=\"$instance_lifecycle_manager\""
    echo "INSTANCE_MANAGE_FILE=\"$instance_manage_file\""

    [[ "$USE_SYSTEMD" -eq 1 ]] && {
      echo "INSTANCE_SYSTEMD_SERVICE_FILE=\"$instance_systemd_service_file\""
      echo "INSTANCE_SYSTEMD_SOCKET_FILE=\"$instance_systemd_socket_file\""
    }

    [[ "$USE_UFW" -eq 1 ]] && {
      echo "INSTANCE_UFW_FILE=\"$instance_ufw_file\""
    }

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

  local instance_id
  instance_id=$identifier

  # Ensure instance_id is unique
  if [[ -z "$instance_id" ]]; then
    # If no identifier is provided, we generate a unique instance name
    instance_id="$(_generate_unique_instance_name "$blueprint_name")"
    export instance_id
  else
    # If an identifier is provided, we use it as the instance_id
    # We also need to ensure that the identifier is valid
    if __instance_config_file_exists "$instance_id" "$blueprint_name"; then
      __print_error "Instance with id \"$instance_id\" already exists for blueprint \"$blueprint_name\""
      return $EC_INVALID_INSTANCE
    fi
  fi

  # Temporary instance config file, we build from here until it's ready
  local instance_config_file
  instance_config_file="$(_create_instance_config_file "$instance_id" "$blueprint_name")"

  # All common instance variables are set in this function
  __create_base_instance "$instance_config_file" "$instance_id" "$blueprint_abs_path" "$install_dir"

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
  __emit_instance_created "$instance_id" "$blueprint"

  echo "$instance_id"
}

function _remove() {
  local instance=$1
  local instance_abs_path
  instance_abs_path="$(__find_instance_config "$instance")"

  local instance_blueprint_file
  instance_blueprint_file="$(grep "INSTANCE_BLUEPRINT_FILE=" <"$instance_abs_path" | cut -d "=" -f2 | tr -d '"')"
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
    echo "Name:                $INSTANCE_ID"
    echo "Lifecycle manager:   $INSTANCE_LIFECYCLE_MANAGER"

    local status=""
    if [[ "$INSTANCE_LIFECYCLE_MANAGER" == "systemd" ]]; then
      # systemctl return exit code 3 but it gives correct response
      if [[ $(type -t __disable_error_checking) == function ]]; then
        __disable_error_checking
      fi
      status="$(systemctl is-active "$INSTANCE_ID")"
      if [[ $(type -t __enable_error_checking) == function ]]; then
        __enable_error_checking
      fi
    else
      status="$([[ -f "$INSTANCE_PID_FILE" ]] && echo "active" || echo "inactive")"
    fi

    echo "Status:              $status"

    if [[ -f "$INSTANCE_PID_FILE" ]]; then
      echo "PID:                 $(cat "$INSTANCE_PID_FILE")"
    fi
    if [[ "$INSTANCE_LIFECYCLE_MANAGER" == "standalone" ]]; then
      echo "Logs directory:      $INSTANCE_LOGS_DIR"
    fi
    echo "Directory:           $INSTANCE_WORKING_DIR"
    echo "Installation date:   $INSTANCE_INSTALL_DATETIME"
    echo "Version:             $($INSTANCE_MANAGE_FILE --version)"
    echo "Blueprint:           $INSTANCE_BLUEPRINT_FILE"

    if [[ "$INSTANCE_LIFECYCLE_MANAGER" == "systemd" ]]; then
      if [[ -f "$INSTANCE_SYSTEMD_SERVICE_FILE" ]]; then
        echo "Service file:        $INSTANCE_SYSTEMD_SERVICE_FILE"
      fi
      if [[ -n "$INSTANCE_SOCKET_FILE" ]]; then
        echo "Socket file:         $INSTANCE_SOCKET_FILE"
      fi
    fi

    if [[ "$USE_UFW" -eq 1 ]]; then
      if [[ -f "$INSTANCE_UFW_FILE" ]]; then
        echo "Firewall rule:       $INSTANCE_UFW_FILE"
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
  if [[ "$INSTANCE_LIFECYCLE_MANAGER" == "systemd" ]]; then
    __disable_error_checking
    status="$(systemctl is-active "$INSTANCE_ID")"
    __enable_error_checking
  else
    status="$([[ -f "$INSTANCE_PID_FILE" ]] && echo "active" || echo "inactive")"
  fi

  local pid
  pid=$([[ -f "$INSTANCE_PID_FILE" ]] && cat "$INSTANCE_PID_FILE" || echo "None")
  local logs_dir
  logs_dir=$([[ "$INSTANCE_LIFECYCLE_MANAGER" == "standalone" ]] && echo "$INSTANCE_LOGS_DIR" || echo "None")
  local service_file
  service_file=$([[ "$INSTANCE_LIFECYCLE_MANAGER" == "systemd" && -f "$INSTANCE_SYSTEMD_SERVICE_FILE" ]] && echo "$INSTANCE_SYSTEMD_SERVICE_FILE" || echo "")
  local socket_file
  socket_file=$([[ "$INSTANCE_LIFECYCLE_MANAGER" == "systemd" && -n "$INSTANCE_SOCKET_FILE" ]] && echo "$INSTANCE_SOCKET_FILE" || echo "")
  local firewall_rule
  firewall_rule=$([[ "$USE_UFW" -eq 1 && -f "$INSTANCE_UFW_FILE" ]] && echo "$INSTANCE_UFW_FILE" || echo "")

  jq -n \
    --arg instance "$INSTANCE_ID" \
    --arg lifecycleManager "$INSTANCE_LIFECYCLE_MANAGER" \
    --arg status "$status" \
    --arg pid "$pid" \
    --arg logsDir "$logs_dir" \
    --arg directory "$INSTANCE_WORKING_DIR" \
    --arg installDate "$INSTANCE_INSTALL_DATETIME" \
    --arg version "$INSTANCE_INSTALLED_VERSION" \
    --arg blueprint "$INSTANCE_BLUEPRINT_FILE" \
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

  if [[ "$INSTANCE_LIFECYCLE_MANAGER" == "systemd" ]]; then
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

  "$INSTANCE_MANAGE_FILE" --save $debug
}

function _send_input_to_instance() {
  local instance=$1
  local command=$2

  # shellcheck disable=SC1090
  source "$(__find_instance_config "$instance")" || return "$EC_FAILED_SOURCE"

  "$INSTANCE_MANAGE_FILE" --input "$command" $debug
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
    [[ -z "$1" ]] && __print_error "Missing argument <blueprint>" && exit "$EC_MISSING_ARG"
    _generate_unique_instance_name "$1"
    exit $?
    ;;
  --input)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <instance>" && exit "$EC_MISSING_ARG"
    instance=$1
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <command>" && exit "$EC_MISSING_ARG"
    command=$1
    _send_input_to_instance "$instance" "$command"
    exit $?
    ;;
  --create)
    blueprint=
    install_dir=
    identifier=
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <blueprint>" && exit "$EC_MISSING_ARG"
    blueprint=$1
    shift
    if [[ -n "$1" ]]; then
      while [[ $# -ne 0 ]]; do
        case "$1" in
        --install-dir)
          shift
          [[ -z "$1" ]] && __print_error "Missing argument <install_dir>" && exit "$EC_MISSING_ARG"
          install_dir=$1
          ;;
        --id)
          shift
          [[ -z "$1" ]] && __print_error "Missing argument <id>" && exit "$EC_MISSING_ARG"
          identifier=$1
          ;;
        *)
          __print_error "Invalid argument $1" && exit "$EC_INVALID_ARG"
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
    [[ -z "$1" ]] && __print_error "Missing argument <instance>" && exit "$EC_MISSING_ARG"
    _get_instance_status "$1"
    exit $?
    ;;
  --save)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <instance>" && exit "$EC_MISSING_ARG"
    _send_save_to_instance "$1"
    exit $?
    ;;
  --remove)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <instance>" && exit "$EC_MISSING_ARG"
    _remove "$1"
    exit $?
    ;;
  --info)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <instance>" && exit "$EC_MISSING_ARG"
    instance=$1
    if [[ -z "$json_format" ]]; then
      _print_info "$instance"
    else
      _print_info_json "$instance"
    fi
    exit $?
    ;;
  *)
    __print_error "Invalid argument $1" && exit "$EC_INVALID_ARG"
    ;;
  esac
  shift
done
