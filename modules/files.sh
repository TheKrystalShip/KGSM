#!/usr/bin/env bash

set -eo pipefail

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

function usage() {
  echo "Usage: $(basename "$0") [OPTION]... [COMMAND] [FLAGS]

Manage necessary files for running a game server.

Options:
  -h, --help                  Display this help and exit
  -i, --instance=INSTANCE     Specify the instance name (without .ini extension)
                              Equivalent to instance_name in the config

Commands:
  --create                    Generate all required files:
                                - instance.manage.sh
                                - instance.override.sh (if applicable)
                                - systemd service/socket files
                                - UFW firewall rules (if applicable)
    --manage                   Create instance.manage.sh
    --systemd                  Generate systemd service/socket files
    --ufw                      Generate and enable UFW firewall rule
    --symlink                  Create a symlink to the management file in the
                               PATH

  --remove                    Remove and disable:
                                - systemd service/socket files
                                - UFW firewall rules
                                - symlink to the management file
    --systemd                  Remove systemd service/socket files
    --ufw                      Remove UFW firewall rules
    --symlink                  Remove the symlink to the management file

Examples:
  $(basename "$0") --instance factorio-space-age --create
  $(basename "$0") -i 7dtd-32 --remove --ufw
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

instance_config_file=$(__find_instance_config "$instance")
# shellcheck disable=SC1090
source "$instance_config_file" || exit $EC_FAILED_SOURCE

[[ "$EUID" -ne 0 ]] && SUDO="sudo -E"

function __inject_native_management_variables() {
  # UPnP ports on startup & disabled them on shutdown
  export config_enable_port_forwarding

  # shellcheck disable=SC2155
  local instance_install_subdir=$(grep "blueprint_executable_subdirectory=" < "$instance_blueprint_file" | cut -d "=" -f2 | tr -d '"')

  instance_launch_dir="$instance_install_dir"
  if [[ -n "$instance_install_subdir" ]]; then
    instance_launch_dir="$instance_install_dir/$instance_install_subdir"
  fi

  # Log redirection into file happens when the instance is launched
  # as a background process.
  # The log file is named after the instance and the current date/time.
  # It is stored in the instance logs directory.
  # shellcheck disable=SC2140
  stdout_file="\$instance_logs_dir/\$instance_name-\$(date +"%Y-%m-%dT%H:%M:%S").log"
  export instance_logs_redirect="$stdout_file"

  # Avoid evaluating instance_executable_arguments as it can contain variables that need
  # to just be passed along, not evaluated
  local instance_launch_args
  instance_launch_args="$(grep "instance_executable_arguments=" < "$instance_config_file" | cut -d '"' -f2 | tr -d '"')"
  export instance_launch_args

  local injected_config
  injected_config=$(
    cat << EOF
# Log redirection into file
instance_logs_redirect="$instance_logs_redirect"

# Directory from which to launch the instance binary
instance_launch_dir="$instance_launch_dir"

$(< "$instance_config_file")
EOF
  )

  local marker="# === BEGIN INJECT CONFIG ==="

  # Replace the marker with the injected config
  if ! sed -i "/${marker}/{
      r /dev/stdin
      d
  }" "$instance_management_file" <<< "$injected_config"; then
    __print_error "Failed to inject config into $instance_management_file"
    return $EC_FAILED_TEMPLATE
  fi

  return 0
}

function __inject_docker_management_variables() {
  local injected_config
  injected_config=$(
    cat << EOF
$(< "$instance_config_file")
EOF
  )

  local marker="# === BEGIN INJECT CONFIG ==="

  # Replace the marker with the injected config
  if ! sed -i "/${marker}/{
      r /dev/stdin
      d
  }" "$instance_management_file" <<< "$injected_config"; then
    __print_error "Failed to inject config into $instance_management_file"
    exit $EC_FAILED_TEMPLATE
  fi

  return 0
}

function _inject_management_overrides() {
  # shellcheck disable=SC1090

  source "$(__find_module overrides.sh)" "$instance" || {
    __print_error "Failed to source module overrides.sh"
    return 1
  }

  # Check for function definitions and replace defaults with overrides
  __print_info "Checking for overrides..."

  # Overrides are located in $KGSM_ROOT/overrides/${INSTANCE_BP_NAME}.overrides.sh

  # $instance_blueprint_file is the absolute path to the blueprint file, we just need the name
  local instance_bp_name
  instance_bp_name=$(basename "$instance_blueprint_file" | sed 's/\.bp$//')

  local instance_overrides_file="${OVERRIDES_SOURCE_DIR}/${instance_bp_name}.overrides.sh"
  # Check if the overrides file exists
  if [[ ! -f "$instance_overrides_file" ]]; then
    __print_info "No overrides file found for ${instance_bp_name}, skipping."
    return 0
  fi

  # For each function name declared in the overrides file…
  grep -Po '^function \K[[:alnum:]_]+' "${instance_overrides_file}" | while read -r fn; do

    # Check if the function is defined in the overrides file
    # Since the overrides file is sourced, we can check if the function exists
    if ! declare -F "${fn}" &> /dev/null; then
      __print_warning "Function '${fn}' not found in overrides file '${instance_overrides_file}', skipping."
      continue
    fi

    func_def=$(declare -f "${fn}")

    __print_info "Found function '${fn}' in overrides file, injecting into ${instance_management_file}"

    # Create a temporary file to hold the new function body
    tmp=$(mktemp)
    printf '%s\n' "${func_def}" | sed '1 s|^|function |' > "${tmp}"

    # In-place sed:
    #   1. On the "function NAME" line, `r tmp` will read/insert the new body *below* that line.
    #   2. Then the range delete `/^function NAME.../,/^}/ d` removes the entire old block,
    #      including that matched “function” line and its closing `}`.
    #   The net effect is that your new body (from the tmp file) ends up in place of the old.
    sed -i \
      -e "/^function ${fn}[[:space:]]*(/ r ${tmp}" \
      -e "/^function ${fn}[[:space:]]*(/,/^}/ d" \
      "${instance_management_file}"

    # shellcheck disable=SC2181
    if [[ $? -ne 0 ]]; then
      __print_error "Failed to inject function '${fn}' into ${instance_management_file}"
      rm -f "${tmp}" # Clean up the temporary file
      return $EC_FAILED_TEMPLATE
    fi

    __print_success "Injected function '${fn}' into ${instance_management_file}"

    # Clean up the temporary file
    rm -f "${tmp}"
  done

  return 0
}

function _create_manage_file() {

  # Prepare source file
  local manage_template_file

  __print_info "Generating management file..."

  # Choose appropriate template based on runtime
  if ! manage_template_file="$(__find_template "manage.${instance_runtime}")"; then
    __print_error "Failed to manage template for $instance_name"
    return $EC_FILE_NOT_FOUND
  fi

  # Create the new management file
  if ! cp -f "$manage_template_file" "$instance_management_file"; then
    __print_error "Failed to generate management template for $instance_management_file"
    return $EC_FAILED_TEMPLATE
  fi

  # Inject config
  case "$instance_runtime" in
    native)
      __inject_native_management_variables || {
        __print_error "Failed to inject native management variables into $instance_management_file"
        return $EC_FAILED_TEMPLATE
      }
      ;;
    docker)
      __inject_docker_management_variables || {
        __print_error "Failed to inject docker management variables into $instance_management_file"
        return $EC_FAILED_TEMPLATE
      }
      ;;
    *)
      __print_error "Invalid instance runtime: $instance_runtime"
      return $EC_GENERAL
      ;;
  esac

  # Inject overrides
  _inject_management_overrides || {
    __print_error "Failed to inject overrides into $instance_management_file"
    return $EC_FAILED_TEMPLATE
  }

  # File permissions
  instance_user=$USER
  if [ "$EUID" -eq 0 ]; then
    instance_user=$SUDO_USER
  fi

  # Make sure file is owned by the user and not root
  if ! chown "$instance_user":"$instance_user" "$instance_management_file"; then
    __print_error "Failed to assing $instance_management_file to user $instance_user"
    return $EC_PERMISSION
  fi

  # Make sure it's executable
  if ! chmod +x "$instance_management_file"; then
    __print_error "Failed to add +x permission to $instance_management_file"
    return $EC_PERMISSION
  fi

  __print_success "Management file created"

  return 0
}

function _systemd_uninstall() {

  __print_info "Removing systemd integration..."

  if [[ -z "$instance_systemd_service_file" ]] && [[ -z "$instance_systemd_socket_file" ]]; then
    # Nothing to uninstall
    return 0
  fi

  if systemctl is-active "$instance_name" &> /dev/null; then
    if ! $SUDO systemctl stop "$instance_name" &> /dev/null; then
      __print_error "Failed to stop $instance_name before uninstalling systemd files"
      return $EC_SYSTEMD
    fi
  fi

  if systemctl is-enabled "$instance_name" &> /dev/null; then
    if ! $SUDO systemctl disable "$instance_name"; then
      __print_warning "Failed to disable $instance_name"
      return $EC_SYSTEMD
    fi
  fi

  # Remove service file
  # shellcheck disable=SC2153
  if [ -f "$instance_systemd_service_file" ]; then
    if ! $SUDO rm "$instance_systemd_service_file"; then
      __print_error "Failed to remove $instance_systemd_service_file"
      return $EC_FAILED_RM
    fi
  fi

  # Remove socket file
  # shellcheck disable=SC2153
  if [ -f "$instance_systemd_socket_file" ]; then
    if ! $SUDO rm "$instance_systemd_socket_file"; then
      __print_error "Failed to remove $instance_systemd_socket_file"
      return $EC_FAILED_RM
    fi
  fi

  # Reload systemd

  __print_info "Reloading systemd..."
  if ! $SUDO systemctl daemon-reload; then
    __print_error "Failed to reload systemd" && return "$EC_SYSTEMD"
  fi

  # Remove entries from instance config file and management file
  __remove_config "$instance_config_file" "instance_systemd_service_file"
  __remove_config "$instance_config_file" "instance_systemd_socket_file"
  __remove_config "$instance_management_file" "instance_systemd_service_file"
  __remove_config "$instance_management_file" "instance_systemd_socket_file"

  # Change the instance_lifecycle_manager to standalone
  __add_or_update_config "$instance_config_file" "instance_lifecycle_manager" "standalone" || {
    return $EC_FAILED_UPDATE_CONFIG
  }

  __print_success "Systemd integration removed"

  return 0
}

function _systemd_install() {

  __print_info "Adding systemd integration..."

  [[ -z "$config_systemd_files_dir" ]] && __print_error "config_systemd_files_dir is expected but it's not set" && return $EC_MISSING_ARG

  local service_template_file
  local socket_template_file
  service_template_file="$(__find_template service.tp)"
  socket_template_file="$(__find_template socket.tp)"

  local instance_systemd_service_file=${config_systemd_files_dir}/${instance_name}.service
  local instance_systemd_socket_file=${config_systemd_files_dir}/${instance_name}.socket

  local temp_systemd_service_file=/tmp/${instance_name}.service
  local temp_systemd_socket_file=/tmp/${instance_name}.socket

  local instance_bin_absolute_path
  instance_bin_absolute_path="$instance_launch_dir/$instance_executable_file"

  # Required by template
  export instance_bin_absolute_path
  export instance_socket_file=${instance_working_dir}/.${instance_name}.stdin

  # If service file already exists, check that it belongs to the instance
  if [[ -f "$instance_systemd_service_file" ]]; then
    if [[ -z "$instance_systemd_service_file" ]]; then
      __print_error "File '$instance_systemd_service_file' already exists but it doesn't belong to $instance_name"
      return $EC_GENERAL
    else
      if ! _systemd_uninstall; then
        return "$EC_GENERAL"
      fi
    fi
  fi

  # If socket file already exists, check that it belongs to the instance
  if [[ -f "$instance_systemd_socket_file" ]]; then
    if [[ -z "$instance_systemd_socket_file" ]]; then
      __print_error "File '$instance_systemd_socket_file' already exists but it doesn't belong to $instance_name"
      return $EC_GENERAL
    else
      if ! _systemd_uninstall; then
        return $EC_GENERAL
      fi
    fi
  fi

  instance_user=$USER
  if [ "$EUID" -eq 0 ]; then
    instance_user=$SUDO_USER
  fi

  # Create the service file
  if ! eval "cat <<EOF
$(< "$service_template_file")
EOF
" > "$temp_systemd_service_file" 2> /dev/null; then
    __print_error "Could not generate $service_template_file to $temp_systemd_service_file"
    return $EC_FAILED_TEMPLATE
  fi

  if ! $SUDO mv "$temp_systemd_service_file" "$instance_systemd_service_file"; then
    __print_error "Failed to move $temp_systemd_socket_file into $instance_systemd_service_file"
    return $EC_FAILED_MV
  fi

  if ! $SUDO chown root:root "$instance_systemd_service_file"; then
    __print_error "Failed to assign root user ownership to $instance_systemd_service_file"
    return $EC_PERMISSION
  fi

  # Create the socket file
  if ! eval "cat <<EOF
$(< "$socket_template_file")
EOF
" > "$temp_systemd_socket_file" 2> /dev/null; then
    __print_error "Could not generate $socket_template_file to $temp_systemd_socket_file"
    return $EC_FAILED_TEMPLATE
  fi

  if ! $SUDO mv "$temp_systemd_socket_file" "$instance_systemd_socket_file"; then
    __print_error "Failed to move $instance_systemd_socket_file into $instance_systemd_socket_file"
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

  # Save new files into instance config file

  # Add the service file to the instance config file
  __add_or_update_config "$instance_config_file" "instance_systemd_service_file" "$instance_systemd_service_file" || {
    return $EC_FAILED_UPDATE_CONFIG
  }

  # Add the socket file to the instance config file
  __add_or_update_config "$instance_config_file" "instance_systemd_socket_file" "$instance_systemd_socket_file" || {
    return $EC_FAILED_UPDATE_CONFIG
  }

  # Save it into the instance's management file also. Prepend just before the bottom marker
  local marker="# === END INJECT CONFIG ==="

  # Add the service file to the management file
  __add_or_update_config "$instance_management_file" "instance_systemd_service_file" "$instance_systemd_service_file" "$marker" || {
    return $EC_FAILED_UPDATE_CONFIG
  }

  # Add the socket file to the management file
  __add_or_update_config "$instance_management_file" "instance_systemd_socket_file" "$instance_systemd_socket_file" "$marker" || {
    return $EC_FAILED_UPDATE_CONFIG
  }

  # Change the instance_lifecycle_manager to systemd
  __add_or_update_config "$instance_config_file" "instance_lifecycle_manager" "systemd" || {
    return $EC_FAILED_UPDATE_CONFIG
  }

  # Also change the instance_lifecycle_manager in the management file
  __add_or_update_config "$instance_management_file" "instance_lifecycle_manager" "systemd" || {
    return $EC_FAILED_UPDATE_CONFIG
  }

  __print_success "Systemd integration complete"

  return 0
}

function _ufw_uninstall() {

  __print_info "Removing UFW integration..."

  [[ -z "$config_firewall_rules_dir" ]] && __print_error "config_firewall_rules_dir is expected but it's not set" && return "$EC_MISSING_ARG"
  [[ -z "$instance_ufw_file" ]] && return 0
  [[ ! -f "$instance_ufw_file" ]] && return 0

  # Remove ufw rule
  __print_info "Deleting UFW rule"
  if ! $SUDO ufw delete allow "$instance_name" &> /dev/null; then
    __print_error "Failed to remove UFW rule for $instance_name"
    return $EC_UFW
  fi

  if [ -f "$instance_ufw_file" ]; then
    # Delete firewall rule file
    __print_info "Deleting rule definition file"
    if ! $SUDO rm "$instance_ufw_file"; then
      __print_error "Failed to remove $instance_ufw_file"
      return $EC_FAILED_RM
    fi
  fi

  # Remove UFW entries from the instance config file
  __remove_config "$instance_config_file" "instance_ufw_file"
  __remove_config "$instance_management_file" "instance_ufw_file"

  __print_success "UFW integration removed"

  return 0
}

function _ufw_install() {

  __print_info "Adding UFW integration..."

  if [[ -z "$config_firewall_rules_dir" ]]; then
    __print_error "'firewall_rules_dir' is expected but it's not set"
    return $EC_MISSING_ARG
  fi

  local instance_ufw_file=${config_firewall_rules_dir}/kgsm-${instance_name}
  local temp_ufw_file=/tmp/kgsm-${instance_name}

  # If firewall rule file already exists, remove it
  if [[ -f "$instance_ufw_file" ]]; then
    __print_error "A UFW rule definition file for this instance already exists at '${instance_ufw_file}'. Manually remove it before trying again"
    return $EC_GENERAL
  fi

  # shellcheck disable=SC2155
  local ufw_template_file="$(__find_template ufw.tp)"

  __print_info "Creating UFW rule definition file"
  # Create firewall rule file from template
  if ! eval "cat <<EOF
$(< "$ufw_template_file")
EOF
" > "$temp_ufw_file"; then
    __print_error "Failed writing rules to $temp_ufw_file" && return "$EX_FAILED_TEMPLATE"
  fi

  if ! $SUDO mv "$temp_ufw_file" "$instance_ufw_file"; then
    __print_error "Failed to move $temp_ufw_file into $instance_ufw_file" && return "$EC_FAILED_MV"
  fi

  # UFW expect the rule file to belong to root
  if ! $SUDO chown root:root "$instance_ufw_file"; then
    __print_error "Failed to assign root user ownership to $instance_ufw_file" && return "$EC_PERMISSION"
  fi

  # Enable firewall rule
  __print_info "Allowing UFW rule"
  if ! $SUDO ufw allow "$instance_name" &> /dev/null; then
    __print_error "Failed to allow UFW rule for $instance_name" && return "$EC_UFW"
  fi

  # Save the UFW file into the instance config file
  __add_or_update_config "$instance_config_file" "instance_ufw_file" "$instance_ufw_file" || {
    return $EC_FAILED_UPDATE_CONFIG
  }

  # Update instance_management_file UFW definition

  local marker="=== END INJECT CONFIG ==="

  # Add the UFW file to the management file
  __add_or_update_config "$instance_management_file" "instance_ufw_file" "$instance_ufw_file" "$marker" || {
    return $EC_FAILED_UPDATE_CONFIG
  }

  __print_success "UFW integration complete"

  return 0
}

function _symlink_uninstall() {

  # Remove the symlink from the $config_command_shortcuts_directory
  # if it exists.

  # Check if the symlink directory is set
  if [[ -z "$config_command_shortcuts_directory" ]]; then
    __print_error "config_command_shortcuts_directory is expected but it's not set"
    return $EC_MISSING_ARG
  fi

  local symlink_path="${config_command_shortcuts_directory}/${instance_name}"

  # Check if the symlink exists
  if [[ -L "$symlink_path" ]]; then
    __print_info "Removing symlink '$symlink_path'"
    if ! $SUDO rm "$symlink_path"; then
      __print_error "Failed to remove symlink '$symlink_path'"
      return $EC_FAILED_RM
    fi
  else
    __print_info "Symlink '$symlink_path' does not exist, nothing to remove"
  fi

  # Remove the symlink entry from the instance config file
  __remove_config "$instance_config_file" "command_shortcuts_directory"

  __print_success "Symlink for instance '$instance_name' removed from $config_command_shortcuts_directory"

  return 0
}

function _symlink_install() {

  # Create a symlink from the $instance_management_file into one of the directories
  # on the PATH, iso that the instance can be managed from anywhere.

  __print_info "Creating symlink for instance '$instance_name'..."

  # Check if the symlink directory is set
  if [[ -z "$config_command_shortcuts_directory" ]]; then
    __print_error "'command_shortcuts_directory' is expected but it's not set"
    return $EC_MISSING_ARG
  fi

  # Check if the symlink directory exists
  if [[ ! -d "$config_command_shortcuts_directory" ]]; then
    __print_error "'command_shortcuts_directory' '$config_command_shortcuts_directory' does not exist"
    return $EC_FILE_NOT_FOUND
  fi

  local symlink_path="${config_command_shortcuts_directory}/${instance_name}"

  # Check if the symlink already exists
  if [[ -L "$symlink_path" ]]; then
    __print_warning "Symlink '$symlink_path' already exists, removing it"
    if ! $SUDO rm "$symlink_path"; then
      __print_error "Failed to remove existing symlink '$symlink_path'"
      return $EC_FAILED_RM
    fi
  fi

  # Create the symlink
  if ! $SUDO ln -s "$instance_management_file" "$symlink_path"; then
    __print_error "Failed to create symlink '$symlink_path' for $instance_management_file"
    return $EC_FAILED_LN
  fi

  # Save the symlink directory into the instance config file
  __add_or_update_config "$instance_config_file" "command_shortcuts_directory" "$config_command_shortcuts_directory" || {
    return $EC_FAILED_UPDATE_CONFIG
  }

  __print_success "Instance \"${instance_name}\" symlink created in $config_command_shortcuts_directory"

  return 0
}

function _create() {
  _create_manage_file || return $?

  if [[ "$instance_lifecycle_manager" == "systemd" ]]; then
    _systemd_install || return $?
  fi

  if [[ "$config_enable_firewall_management" == "true" ]]; then
    _ufw_install || return $?
  fi

  if [[ "$config_enable_command_shortcuts" == "true" ]]; then
    _symlink_install || return $?
  fi

  __emit_instance_files_created "${instance%.ini}"
  return 0
}

function _remove() {
  if [[ "$instance_lifecycle_manager" == "systemd" ]]; then
    _systemd_uninstall || return $?
  fi

  if [[ "$config_enable_firewall_management" == "true" ]]; then
    _ufw_uninstall || return $?
  fi

  if [[ "$config_enable_command_shortcuts" == "true" ]]; then
    _symlink_uninstall || return $?
  fi

  __emit_instance_files_removed "${instance%.ini}"
  return 0
}

#Read the argument values
while [ $# -gt 0 ]; do
  case "$1" in
    --create)
      shift
      if [[ -z "$1" ]]; then
        _create
        exit $?
      fi
      case "$1" in
        --manage)
          _create_manage_file
          exit $?
          ;;
        --systemd)
          _systemd_install
          exit $?
          ;;
        --ufw)
          _ufw_install
          exit $?
          ;;
        --symlink)
          _symlink_install
          exit $?
          ;;
        *)
          __print_error "Invalid argument $1"
          exit $EC_INVALID_ARG
          ;;
      esac
      ;;
    --remove)
      shift
      if [[ -z "$1" ]]; then
        _remove
        exit $?
      fi
      case "$1" in
        --systemd)
          _systemd_uninstall
          exit $?
          ;;
        --ufw)
          _ufw_uninstall
          exit $?
          ;;
        --symlink)
          _symlink_uninstall
          exit $?
          ;;
        *)
          __print_error "Invalid argument $1"
          exit $EC_INVALID_ARG
          ;;
      esac
      ;;
    *)
      __print_error "Invalid argument $1"
      exit $EC_INVALID_ARG
      ;;
  esac
  shift
done

exit $?
