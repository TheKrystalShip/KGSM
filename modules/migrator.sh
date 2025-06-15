#!/usr/bin/env bash

function usage() {
  local UNDERLINE="\e[4m"
  local END="\e[0m"

  echo -e "${UNDERLINE}Migration Helper for Krystal Game Server Manager${END}

A tool to migrate previous versions of instance config files, blueprints, and the main KGSM config.ini to the latest format.
This ensures KGSM version 2.0 can work with existing instances without needing to recreate them from scratch.

${UNDERLINE}Usage:${END}
  $(basename "$0") [OPTIONS]

${UNDERLINE}General Options:${END}
  -h, --help                     Display this help information

${UNDERLINE}Migration Options:${END}
  --instances                     Migrate all instance configuration files to the latest format
  --instance <instance-name>      Migrate an instance configuration file to the latest format
  --config                        Migrate the main KGSM config.ini file to the latest format

${UNDERLINE}Examples:${END}
  $(basename "$0") --instance factorio
  $(basename "$0") --config
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

SELF_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check for KGSM_ROOT
if [[ -z "$KGSM_ROOT" ]]; then
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

if [[ "$#" -eq 0 ]]; then
  usage
  exit $EC_MISSING_ARG
fi

module_files=$(__find_module files.sh)
module_instances=$(__find_module instances.sh)

# Function to migrate instance config file
function _migrate_instance() {
  local instance="$1"

  instance_config_file=$(__find_instance_config "$instance")

  if [[ ! -f "$instance_config_file" ]]; then
    __print_error "Instance file not found: $instance_config_file"
    exit $EC_FILE_NOT_FOUND
  fi

  __print_info "Migrating instance config file: $instance_config_file"

  # Create a backup of the original file
  local backup_file
  backup_file="${instance_config_file}.$(date +%Y%m%d%H%M%S).bak"
  cp "$instance_config_file" "$backup_file"
  __print_info "Backup created: $backup_file"

  # Create a temporary file for the new format
  local temp_file
  temp_file="${instance_config_file}.new"
  true >"$temp_file"

  # Read the old format line by line
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines and comments
    if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
      continue
    fi

    # Process key-value pairs
    if [[ "$line" =~ ^[[:space:]]*([A-Z_]+)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
      local key="${BASH_REMATCH[1]}"
      local value="${BASH_REMATCH[2]}"

      # Remove quotes if present
      value="${value//\"/}"

      # Map old keys to new keys
      case "$key" in
      INSTANCE_NAME | INSTANCE_FULL_NAME)
        # Use INSTANCE_FULL_NAME if available, otherwise use INSTANCE_NAME
        if [[ "$key" == "INSTANCE_FULL_NAME" ]]; then
          echo "instance_name=\"$value\"" >>"$temp_file"
        fi
        ;;
      INSTANCE_BLUEPRINT_FILE) echo "instance_blueprint_file=\"$value\"" >>"$temp_file" ;;
      INSTANCE_WORKING_DIR) echo "instance_working_dir=\"$value\"" >>"$temp_file" ;;
      INSTANCE_SAVES_DIR) echo "instance_saves_dir=\"$value\"" >>"$temp_file" ;;
      INSTANCE_INSTALL_DIR) echo "instance_install_dir=\"$value\"" >>"$temp_file" ;;
      INSTANCE_TEMP_DIR) echo "instance_temp_dir=\"$value\"" >>"$temp_file" ;;
      INSTANCE_BACKUPS_DIR) echo "instance_backups_dir=\"$value\"" >>"$temp_file" ;;
      INSTANCE_LOGS_DIR) echo "instance_logs_dir=\"$value\"" >>"$temp_file" ;;
      INSTANCE_INSTALL_DATETIME) echo "instance_install_datetime=\"$value\"" >>"$temp_file" ;;
      INSTANCE_LIFECYCLE_MANAGER) echo "instance_lifecycle_manager=\"$value\"" >>"$temp_file" ;;
      INSTANCE_MANAGE_FILE) echo "instance_management_file=\"$value\"" >>"$temp_file" ;;
      INSTANCE_PORT) echo "instance_ports=$value" >>"$temp_file" ;;
      INSTANCE_LAUNCH_BIN) echo "instance_executable_file=\"$value\"" >>"$temp_file" ;;
      INSTANCE_LAUNCH_ARGS)
        # Replace references to old variables with new lowercase ones
        local new_args="$value"
        # List of old variables that might be referenced
        local old_vars=("INSTANCE_LEVEL_NAME" "INSTANCE_SAVES_DIR" "INSTANCE_WORKING_DIR"
          "INSTANCE_INSTALL_DIR" "INSTANCE_TEMP_DIR" "INSTANCE_BACKUPS_DIR"
          "INSTANCE_LOGS_DIR" "INSTANCE_ID" "INSTANCE_NAME" "INSTANCE_FULL_NAME"
          "INSTANCE_PORT" "INSTANCE_LAUNCH_BIN" "INSTANCE_SOCKET_FILE")
        for old_var in "${old_vars[@]}"; do
          # Convert to new variable name format
          local new_var="instance_${old_var#INSTANCE_}"
          new_var="${new_var,,}"
          # Replace in arguments string
          new_args="${new_args//\$$old_var/\$$new_var}"
        done
        echo "instance_executable_arguments=\"$new_args\"" >>"$temp_file"
        ;;
      INSTANCE_SOCKET_FILE) echo "instance_socket_file=\"$value\"" >>"$temp_file" ;;
      INSTANCE_STOP_COMMAND) echo "instance_stop_command=\"$value\"" >>"$temp_file" ;;
      INSTANCE_SAVE_COMMAND) echo "instance_save_command=\"$value\"" >>"$temp_file" ;;
      INSTANCE_PID_FILE) echo "instance_pid_file=\"$value\"" >>"$temp_file" ;;
      INSTANCE_LEVEL_NAME) echo "instance_level_name=\"$value\"" >>"$temp_file" ;;
      INSTANCE_APP_ID) echo "instance_steam_app_id=\"$value\"" >>"$temp_file" ;;
      INSTANCE_UFW_FILE) echo "instance_ufw_file=\"$value\"" >>"$temp_file" ;;
      INSTANCE_TAIL_PID_FILE) echo "instance_tail_pid_file=\"$value\"" >>"$temp_file" ;;
      INSTANCE_SYSTEMD_SERVICE_FILE) echo "instance_systemd_service_file=\"$value\"" >>"$temp_file" ;;
      INSTANCE_SYSTEMD_SOCKET_FILE) echo "instance_systemd_socket_file=\"$value\"" >>"$temp_file" ;;
      INSTANCE_STEAM_ACCOUNT_NEEDED)
        # Convert 0/1 to false/true
        if [[ "$value" == "0" ]]; then
          echo "instance_is_steam_account_required=\"false\"" >>"$temp_file"
        elif [[ "$value" == "1" ]]; then
          echo "instance_is_steam_account_required=\"true\"" >>"$temp_file"
        else
          # Keep the original value if it's not 0/1
          echo "instance_is_steam_account_required=\"$value\"" >>"$temp_file"
        fi
        ;;
      # Skip these fields, they are not used in the new format
      INSTANCE_ID | INSTANCE_INSTALLED_VERSION)
        continue
        ;;
      *)
        # For any other fields, convert to lowercase and keep them
        local new_key="instance_${key#INSTANCE_}"
        new_key="${new_key,,}"
        echo "${new_key}=\"$value\"" >>"$temp_file"
        ;;
      esac
    fi
  done <"$instance_config_file"

  # Add instance_runtime if it doesn't exist
  if ! grep -q "instance_runtime" "$temp_file"; then
    echo "instance_runtime=\"native\"" >>"$temp_file"
  fi

  if ! grep -q "instance_save_command_timeout_seconds" "$temp_file"; then
    echo "instance_save_command_timeout_seconds=\"${config_instance_save_command_timeout_seconds:-5}\"" >>"$temp_file"
  fi

  if ! grep -q "instance_stop_command_timeout_seconds" "$temp_file"; then
    echo "instance_stop_command_timeout_seconds=\"${config_instance_stop_command_timeout_seconds:-30}\"" >>"$temp_file"
  fi

  if ! grep -q "instance_compress_backups" "$temp_file"; then
    echo "instance_compress_backups=\"${config_enable_backup_compression:-false}\"" >>"$temp_file"
  fi

  if ! grep -q "instance_enable_port_forwarding" "$temp_file"; then
    echo "instance_enable_port_forwarding=\"${config_instance_enable_port_forwarding:-false}\"" >>"$temp_file"
  fi

  {
    # shellcheck disable=SC1090
    if [[ -f "$temp_file" ]]; then
      source "$temp_file"
      if [[ -n "$instance_ports" ]]; then
        # shellcheck disable=SC2207
        local instance_upnp_ports=($(__parse_ufw_to_upnp_ports "$instance_ports"))
        echo "instance_upnp_ports=(${instance_upnp_ports[*]})" >>"$temp_file"
      fi

      if [[ -n "$instance_systemd_service_file" ]] && [[ -n "$instance_systemd_socket_file" ]]; then
        echo "instance_enable_systemd=\"true\"" >>"$temp_file"
      else
        echo "instance_enable_systemd=\"false\"" >>"$temp_file"
      fi

      if [[ -n "$instance_ufw_file" ]]; then
        echo "instance_enable_firewall_management=\"true\"" >>"$temp_file"
      else
        echo "instance_enable_firewall_management=\"false\"" >>"$temp_file"
      fi

      if [[ -z "$instance_tail_pid_file" ]]; then
        # shellcheck disable=SC2154
        instance_tail_pid_file="${instance_working_dir}/.${instance_name}.tail.pid"
        echo "instance_tail_pid_file=\"$instance_tail_pid_file\"" >>"$temp_file"
      fi
    fi
  }

  # This is a new feature in KGSM 2.0, none of the old instances had this setting
  if ! grep -q "instance_enable_command_shortcuts" "$temp_file"; then
    echo "instance_enable_command_shortcuts=\"false\"" >>"$temp_file"
  fi

  # Replace the original file with the new format
  mv "$temp_file" "$instance_config_file"
  __print_success "Migration completed: $instance"

  return 0
}

# Function to migrate main KGSM config.ini file
function _migrate_config() {
  local config_path="$KGSM_ROOT/config.ini"

  __print_info "Migrating KGSM config.ini file"

  if [[ -f "$config_path" ]]; then
    # Create a backup of the existing config file with timestamp
    local backup_file
    backup_file="${config_path}.$(date +%Y%m%d%H%M%S).bak"
    cp "$config_path" "$backup_file"
    __print_info "Backup of existing config file created: $backup_file"
  else
    __print_info "No existing config file found at $config_path, creating a new one"
  fi

  # Copy the default config file to create a new config.ini
  if [[ -f "$KGSM_ROOT/config.default.ini" ]]; then
    cp "$KGSM_ROOT/config.default.ini" "$config_path"
    __print_success "New config.ini created from default template"
    __print_info "Please review and update $config_path to configure KGSM according to your preferences"
  else
    __print_error "Default config file not found at $KGSM_ROOT/config.default.ini"
    exit $EC_FILE_NOT_FOUND
  fi

  return 0
}

function _migrate_instances() {
  local instances
  # shellcheck disable=SC2207
  instances=($("$module_instances" --list))

  if [[ ${#instances[@]} -eq 0 ]]; then
    __print_info "No instances found to migrate"
    return 0
  fi

  for instance in "${instances[@]}"; do
    # First update the instance config file to the latest format
    if ! _migrate_instance "$instance"; then
      __print_error "Failed to migrate instance: $instance"
      return 1
    fi

    # After each migration, the management file needs to be regenerated
    __print_info "Updating management file for instance: $instance"
    if ! "$module_files" -i "$instance" --create --manage; then
      __print_error "Failed to update management file for instance: $instance"
      exit 1
    fi
  done

  __print_success "All instances migrated successfully"
  return 0
}

function _migrate_all() {
  if ! _migrate_config; then
    __print_error "Failed to migrate config"
    return 1
  fi

  if ! _migrate_instances; then
    __print_error "Failed to migrate instances"
    return 1
  fi

  __print_success "All migrations completed successfully"
  return 0
}

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
  -h | --help)
    usage
    exit 0
    ;;
  --instance)
    shift
    if [[ -z "$1" ]]; then
      __print_error "Missing instance file path argument"
      exit $EC_MISSING_ARG
    fi
    _migrate_instance "$1"
    exit $?
    ;;
  --instances)
    _migrate_instances
    exit $?
    ;;
  --config)
    _migrate_config
    exit $?
    ;;
  --all)
    _migrate_all
    exit $?
    ;;
  *)
    __print_error "Unknown option: $1"
    usage
    exit $EC_INVALID_ARG
    ;;
  esac
  shift
done

exit $?
