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
  --list --status [blueprint]     Show runtime status for all instances
                                  Displays comprehensive status information for each instance
  --list --json [blueprint]       Output instance list in JSON format
  --list --json --detailed        Output detailed instance information in JSON format
      [blueprint]                 Suitable for programmatic consumption
  --list --json --status          Output runtime status for all instances in JSON format
      [blueprint]                 Perfect for monitoring dashboards and automation

${UNDERLINE}Instance Monitoring:${END}
  --status <instance>             Display comprehensive runtime status for monitoring and troubleshooting
                                  Shows: active/inactive state, process info, resource usage, version status,
                                  disk usage, backup count, and recent log activity
                                  Human-readable format designed for administrators
  --status <instance> --json      Output runtime status information as structured JSON data
                                  Same information as --status but in JSON format
                                  Perfect for web interfaces, APIs, and automation
  --status <instance> --fast      Display rapid runtime status without update checking (< 50ms)
                                  Skips version comparison and latest version lookup for speed
                                  Ideal for web APIs and frequent monitoring
  --status <instance> --json --fast
                                  Output rapid runtime status as JSON without update checking
                                  Combines JSON format with fast mode for optimal API performance

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

${UNDERLINE}Configuration Access (Programmatic):${END}
  --info <instance>               Output raw instance configuration file contents
                                  Displays the complete .ini file exactly as stored on disk
                                  Use for manual configuration review or debugging
  --info <instance> --json        Output instance configuration as structured JSON data
                                  Parses all configuration keys/values into JSON format
                                  Ideal for automation, scripting, and programmatic access

${UNDERLINE}Bulk Operations:${END}
  --regenerate --management-script Regenerate management scripts for all instances
                                  Updates all instance.manage.sh files to latest template version
                                  Useful after KGSM updates or template improvements
  --regenerate --all              Regenerate all files for all instances
                                  Regenerates management scripts, systemd files, UFW rules, etc.
                                  Complete refresh of all instance-related files

Examples:
  $(basename "$0") --create factorio.bp --name factorio-01 --install-dir /opt
  $(basename "$0") --status factorio-01         # Human-readable runtime status
  $(basename "$0") --status factorio-01 --json  # Runtime status as JSON for APIs
  $(basename "$0") --info factorio-01           # Raw configuration file
  $(basename "$0") --info factorio-01 --json    # Configuration as JSON for scripts
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
  module_common="$(find "$KGSM_ROOT/lib" -type f -name common.sh -print -quit)"
  [[ -z "$module_common" ]] && echo "${0##*/} ERROR: Failed to load module common.sh" >&2 && exit 1
  # shellcheck disable=SC1090
  source "$module_common" || exit 1
fi

function _generate_unique_instance_name() {
  # VALIDATION: Ensure blueprint exists and is valid before generating ID
  if ! validate_blueprint "$1"; then
    return $EC_BLUEPRINT_NOT_FOUND
  fi

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

  ############################################################################
  # Common instance variables
  ############################################################################

  # Source the blueprint file to get the blueprint variables
  # Only do this for native instances, container instances have
  # docker-compose.yml files which can't be sourced as a blueprint
  if [[ "$blueprint_abs_path" == *.bp ]]; then
    __source_blueprint "$blueprint_abs_path"
  fi

  # Set the instance variables
  export instance_name=$instance_name
  export instance_blueprint_file=$blueprint_abs_path
  export instance_working_dir="${install_dir}/${instance_name}"

  # shellcheck disable=SC2155
  export instance_install_datetime="$(date +"%Y-%m-%dT%H:%M:%S")"
  export instance_version_file="${instance_working_dir}/.${instance_name}.version"
  export instance_lifecycle_manager="standalone"
  export instance_manage_file="${instance_working_dir}/${instance_name}.manage.sh"
  export instance_auto_update_before_start="${config_instance_auto_update_before_start:-false}"
  export instance_pid_file="${instance_working_dir}/.${instance_name}.pid"
  export instance_tail_pid_file="${instance_working_dir}/.${instance_name}.tail.pid"
  export instance_socket_file="${instance_working_dir}/.${instance_name}.stdin"
  export instance_logs_redirect="\$instance_logs_dir/\$instance_name-\$(date +\"%Y-%m-%dT%H:%M:%S\").log"

  export instance_launch_dir="$install_dir"
  if [[ -n "$instance_install_subdir" ]]; then
    instance_launch_dir="$install_dir/$instance_install_subdir"
  fi

  export instance_install_subdir
  instance_install_subdir=$(grep "executable_subdirectory=" <"$blueprint_abs_path" | cut -d "=" -f2 | tr -d '"')

  export instance_ports="${blueprint_ports:-}"
  export instance_stop_command="${blueprint_stop_command:-}"
  export instance_save_command="${blueprint_save_command:-}"
  export instance_platform="${blueprint_platform:-linux}"
  export instance_level_name="${blueprint_level_name:-default}"
  export instance_steam_app_id="${blueprint_steam_app_id:-0}"
  export instance_is_steam_account_required="${blueprint_is_steam_account_required:-false}"

  export instance_save_command_timeout_seconds="${config_instance_save_command_timeout_seconds:-5}"
  export instance_stop_command_timeout_seconds="${config_instance_stop_command_timeout_seconds:-30}"
  export instance_compress_backups="${config_enable_backup_compression:-false}"
  export instance_enable_port_forwarding="${config_instance_enable_port_forwarding:-false}"

  local instance_executable_file

  # The executable file needs "./" appended to it if it's not a global bin
  # like java, python, wine64, etc.
  case "${blueprint_executable_file:-}" in
  java | python | wine64 | wine32 | wine | mono | mono64 | mono-wine | mono-wine64 | mono-wine32 | mono-wine-wine64 | mono-wine-wine32 | mono-wine-wine | mono-wine-wine64 | mono-wine-wine32 | mono-wine-wine)
    instance_executable_file="${blueprint_executable_file}"
    ;;
  *)
    instance_executable_file="./${blueprint_executable_file}"
    ;;
  esac
  export instance_executable_file
  export instance_executable_arguments="${blueprint_executable_arguments:-}"

  # Some variables need to be extracted and parsed from the blueprint file
  # but because of the way container based blueprints are set up, we need
  # different logic for native and container instances.

  if [[ "$blueprint_abs_path" == *.bp ]]; then

    # Native instance
    instance_runtime="native"
    instance_compose_file=""

    instance_upnp_ports=()
    if [[ -n "${blueprint_ports:-}" ]]; then
      if ! output=$(__parse_ufw_to_upnp_ports "$blueprint_ports") || ! read -ra instance_upnp_ports <<<"$output"; then
        __print_warning "Failed to generate 'instance_upnp_ports'. Disabling UPnP for instance $instance_name"
        export instance_enable_port_forwarding="false"
      fi
    fi

  elif
    [[ "$blueprint_abs_path" == *.docker-compose.yml ]] || [[ "$blueprint_abs_path" == *.yaml ]]
  then

    # Container instance
    instance_runtime="container"
    instance_compose_file="${instance_working_dir}/${instance_name}.docker-compose.yml"

    local blueprint_parsed_ports
    if ! blueprint_parsed_ports=$(__parse_docker_compose_to_ufw_ports "$blueprint_abs_path"); then
      __print_error "Failed to parse ports from the docker-compose file: $blueprint_abs_path"
      return $EC_INVALID_ARG
    fi

    export instance_ports="$blueprint_parsed_ports"

    instance_upnp_ports=()
    if [[ -n "${blueprint_parsed_ports:-}" ]]; then
      if ! output=$(__parse_ufw_to_upnp_ports "$blueprint_parsed_ports") || ! read -ra instance_upnp_ports <<<"$output"; then
        __print_warning "Failed to generate 'instance_upnp_ports'. Disabling UPnP for instance $instance_name"
        export instance_enable_port_forwarding="false"
      fi
    fi

  else
    __print_error "Invalid blueprint file: $blueprint_abs_path"
    return $EC_INVALID_BLUEPRINT
  fi

  export instance_runtime
  export instance_compose_file
  export instance_upnp_ports

  # Render the instance config file template
  local instance_config_file_template
  instance_config_file_template="$(__find_template instance.tp)"

  if ! eval "cat <<EOF
$(<"$instance_config_file_template")
EOF
" >"$instance_config_file" 2>/dev/null; then
    __print_error "Failed to render instance config file template"
    return $EC_FAILED_TEMPLATE
  fi

  return 0
}

# IMPORTANT: This function cannot echo or print anything to stdout
# other than the final instance file path.
function _create_instance() {
  local blueprint=$1
  local install_dir=$2
  local identifier=${3:-}

  # VALIDATION: Ensure blueprint exists and is valid before proceeding
  if ! validate_blueprint "$blueprint"; then
    return $EC_BLUEPRINT_NOT_FOUND
  fi

  # VALIDATION: Ensure install directory exists and is writable if provided
  if [[ -n "$install_dir" ]]; then
    if ! validate_directory_exists "$install_dir" "install directory"; then
      return $EC_FILE_NOT_FOUND
    fi
    if ! validate_directory_writable "$install_dir" "install directory"; then
      return $EC_PERMISSION
    fi
  fi

  local blueprint_abs_path
  if ! blueprint_abs_path="$(__find_blueprint "$blueprint")"; then
    __print_error "Could not find blueprint $blueprint"
    return $EC_FILE_NOT_FOUND
  fi

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

  # All done
  __emit_instance_created "$instance_name" "$blueprint"

  echo "$instance_name"
}

function _remove() {
  local instance=$1

  # Find the instance config symlink path (works even if broken)
  local instance_config_symlink
  if ! instance_config_symlink=$(__find_instance_config "$instance"); then
    __print_error "Instance '$instance' not found"
    return $EC_NOT_FOUND
  fi

  # Extract blueprint name from the symlink path (parent directory name)
  local blueprint_name
  blueprint_name="$(basename "$(dirname "$instance_config_symlink")")"

  # Remove the symlink (works for both valid and broken symlinks)
  if ! rm "$instance_config_symlink"; then
    __print_error "Failed to remove instance config symlink: $instance_config_symlink"
    return $EC_FAILED_RM
  fi

  # Remove directory if no other instances are found
  local instances_dir
  instances_dir="${INSTANCES_SOURCE_DIR}/${blueprint_name}"
  if [[ -d "$instances_dir" ]] && [[ -z "$(ls -A "$instances_dir" 2>/dev/null)" ]]; then
    if ! rmdir "$instances_dir"; then
      __print_warning "Failed to remove empty directory: $instances_dir"
      # Don't return error here, the main task (removing the symlink) succeeded
    fi
  fi

  __emit_instance_removed "${instance}"
  return 0
}

function _print_info() {
  local instance=$1
  local instance_config_file
  instance_config_file=$(__find_instance_config "$instance")

  cat "$instance_config_file"
}

function _print_info_json() {
  local instance=$1
  local instance_config_file
  instance_config_file=$(__find_instance_config "$instance")

  # Parse INI file and convert to JSON
  {
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
      # Skip comments and empty lines
      [[ "$key" =~ ^[[:space:]]*# || -z "$key" ]] && continue

      # Clean up whitespace and quotes
      key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^"//;s/"$//')

      # Output tab-separated key-value pairs for jq processing
      printf '%s\t%s\n' "$key" "$value"
    done < <(grep -v '^[[:space:]]*$' "$instance_config_file" | grep -v '^[[:space:]]*#')
  } | jq -R 'split("\t") | {(.[0]): .[1]}' | jq -s 'add'
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

function _list_instances_status() {
  local blueprint=${1:-}

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
    local filename
    filename="$(basename "${instances[$i]}")"
    local instance_name="${filename%.ini}"

    echo "=== Instance: $instance_name ==="
    _get_instance_status "$instance_name"
    echo ""
  done
}

function _list_instances_status_json() {
  local blueprint=${1:-}

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

  # Build a JSON object with instance status information
  jq -n --argjson instances_list \
    "$(for instance in "${filenames[@]}"; do
      # Get the status of an instance as JSON
      local status_content
      status_content=$(_get_instance_status_json "${instance##*/}")
      # Skip instances with invalid status content
      if [[ $? -ne 0 || -z "$status_content" ]]; then
        continue
      fi
      jq -n --arg key "${instance##*/}" --argjson value "$status_content" '{"key": $key, "value": $value}'
    done | jq -s 'from_entries')" '$instances_list'
}

# Function to check if management file supports --status command
function _check_management_file_status_support() {
  local management_file="$1"

  # Check if the management file exists and is executable
  if [[ ! -f "$management_file" ]] || [[ ! -x "$management_file" ]]; then
    return 1
  fi

  # Check if the management file supports --status by looking for it in help output
  if "$management_file" --help 2>/dev/null | grep -q -- "--status"; then
    return 0
  fi

  return 1
}

function _get_instance_status() {
  local instance=$1
  __source_instance "$instance"

  # Check if management file supports the new --status command
  if _check_management_file_status_support "$instance_management_file"; then
    # Use the new unified status command from the management file
    local status_args=""
    if [[ -n "$json_format" ]]; then
      status_args="--json"
    fi
    if [[ -n "$fast_mode" ]]; then
      status_args="$status_args --fast"
    fi

    "$instance_management_file" --status $status_args $debug
  else
    # Fallback for older management files that don't support --status
    __print_warning "Instance '$instance' uses an older management file that doesn't support the --status command."
    __print_warning "To enable faster status queries, regenerate the management file using:"
    __print_warning "  ./kgsm.sh --regenerate-management-files"

    # TODO: Implement fallback status gathering logic here
    # For now, just indicate the instance is not compatible
    if [[ -n "$json_format" ]]; then
      echo '{"error": "Management file does not support --status command", "instance": "'"$instance"'", "requires_regeneration": true}'
    else
      echo "Error: Management file does not support --status command"
      echo "Instance: $instance"
      echo "Action required: Regenerate management files"
    fi
  fi
}

function _get_instance_status_json() {
  local instance=$1
  __source_instance "$instance"

  # Check if management file supports the new --status command
  if _check_management_file_status_support "$instance_management_file"; then
    # Use the new unified status command from the management file
    local status_args="--json"
    if [[ -n "$fast_mode" ]]; then
      status_args="$status_args --fast"
    fi

    "$instance_management_file" --status $status_args $debug
  else
    # Fallback for older management files that don't support --status
    __print_warning "Instance '$instance' uses an older management file that doesn't support the --status command."
    __print_warning "To enable faster status queries, regenerate the management file using:"
    __print_warning "  ./kgsm.sh --regenerate-management-files"

    # Return JSON error response
    echo '{"error": "Management file does not support --status command", "instance": "'"$instance"'", "requires_regeneration": true}'
  fi
}

function _send_save_to_instance() {
  local instance=$1

  __source_instance "$instance"

  "$instance_management_file" --save $debug
}

function _send_input_to_instance() {
  local instance=$1
  local command=$2

  __source_instance "$instance"

  "$instance_management_file" --input "$command" $debug
}

function _regenerate_files() {
  local operation="$1"  # "management-script" or "all"

  local operation_name
  local files_args

  case "$operation" in
    "management-script")
      operation_name="management scripts"
      files_args="--create --manage"
      ;;
    "all")
      operation_name="all files"
      files_args="--create"
      ;;
    *)
      __print_error "Invalid regenerate operation: $operation"
      return $EC_INVALID_ARG
      ;;
  esac

  __print_info "Regenerating $operation_name for all instances..."

  local files_module
  files_module="$(__find_module files.sh)"

  local instance_count=0
  local success_count=0
  local error_count=0

  # Get list of all instances using existing function
  local instances
  instances=$(_list_instances)

  if [[ -z "$instances" ]]; then
    __print_info "No instances found to regenerate"
    return 0
  fi

  # Process each instance
  while IFS= read -r instance_name; do
    [[ -z "$instance_name" ]] && continue

    __print_info "Regenerating $operation_name for instance: $instance_name"

    # Call files.sh module with appropriate arguments
    # Capture both stdout and stderr to check for actual success/failure
    local files_output
    files_output=$("$files_module" --instance "$instance_name" $files_args $debug 2>&1)
    local files_exit_code=$?

    # Check if the command succeeded and didn't produce error messages
    if [[ $files_exit_code -eq 0 ]] && ! echo "$files_output" | grep -q "ERROR\|Failed to"; then
      __print_success "Successfully regenerated $operation_name for: $instance_name"
      ((success_count++))
    else
      __print_error "Failed to regenerate $operation_name for: $instance_name"
      # Log the actual error for debugging
      if [[ -n "$files_output" ]]; then
        __print_error "Error details: $files_output"
      fi
      ((error_count++))
    fi

    ((instance_count++))
  done <<< "$instances"

  __print_info "Regeneration complete: $success_count successful, $error_count failed, $instance_count total"

  if [[ $error_count -gt 0 ]]; then
    return 1
  fi

  return 0
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

# shellcheck disable=SC2199
if [[ $@ =~ "--fast" ]]; then
  fast_mode=1
  for a; do
    shift
    case $a in
    --fast) continue ;;
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
      --status)
        status=1
        ;;
      *)
        blueprint=$1
        ;;
      esac
      shift
    done
    if [[ -n "$status" ]]; then
      # Status listing
      if [[ -z "$json_format" ]]; then
        _list_instances_status "$blueprint"
        exit $?
      else
        _list_instances_status_json "$blueprint"
        exit $?
      fi
    else
      # Regular listing (existing functionality)
      if [[ -z "$json_format" ]]; then
        _list_instances "$blueprint" "$detailed"
        exit $?
      else
        _list_instances_json "$blueprint" "$detailed"
        exit $?
      fi
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
    instance=$1
    if [[ -z "$json_format" ]]; then
      _get_instance_status "$instance"
    else
      _get_instance_status_json "$instance"
    fi
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
  --regenerate)
    shift
    [[ -z "$1" ]] && __print_error "Missing regenerate option (--management-script or --all)" && exit $EC_MISSING_ARG

    # Validate that only one regenerate option is provided
    regenerate_option="$1"
    shift

    # Check for additional regenerate options (conflicting)
    if [[ -n "$1" ]] && [[ "$1" == "--management-script" || "$1" == "--all" ]]; then
      __print_error "Multiple regenerate options provided: $regenerate_option and $1"
      __print_error "Only one regenerate option allowed: --management-script or --all"
      exit $EC_INVALID_ARG
    fi

    case "$regenerate_option" in
    --management-script)
      _regenerate_files "management-script"
      exit $?
      ;;
    --all)
      _regenerate_files "all"
      exit $?
      ;;
    *)
      __print_error "Invalid regenerate option: $regenerate_option"
      __print_error "Valid options: --management-script, --all"
      exit $EC_INVALID_ARG
      ;;
    esac
    ;;
  *)
    __print_error "Invalid argument $1" && exit $EC_INVALID_ARG
    ;;
  esac
  shift
done
