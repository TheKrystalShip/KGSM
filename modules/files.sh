#!/usr/bin/env bash

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

function usage() {
  echo "Usage: $(basename "$0") [OPTION]... [COMMAND] [FLAGS]

Manage necessary files for running a game server.

Options:
  -h, --help                  Display this help and exit
  -i, --instance=INSTANCE     Specify the instance name (without .ini extension)
                              Equivalent to INSTANCE_FULL_NAME in the config

Commands:
  --create                    Generate all required files:
                                - instance.manage.sh
                                - instance.override.sh (if applicable)
                                - systemd service/socket files
                                - UFW firewall rules (if applicable)
    --manage                   Create instance.manage.sh
    --override                 Create instance.override.sh if applicable
    --systemd                  Generate systemd service/socket files
    --ufw                      Generate and enable UFW firewall rule

  --remove                    Remove and disable:
                                - systemd service/socket files
                                - UFW firewall rules
    --systemd                  Remove systemd service/socket files
    --ufw                      Remove UFW firewall rules

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
  module_common="$(find "$KGSM_ROOT" -type f -name common.sh -print -quit)"
  [[ -z "$module_common" ]] && echo "${0##*/} ERROR: Failed to load module common.sh" >&2 && exit 1
  # shellcheck disable=SC1090
  source "$module_common" || exit 1
fi

instance_config_file=$(__load_instance "$instance")
# shellcheck disable=SC1090
source "$instance_config_file" || exit $EC_FAILED_SOURCE

[[ "$EUID" -ne 0 ]] && SUDO="sudo -E"

function __inject_native_management_variables() {
  # UPnP ports on startup & disabled them on shutdown
  export USE_UPNP

  # shellcheck disable=SC2155
  local instance_install_subdir=$(grep "BP_INSTALL_SUBDIRECTORY=" < "$INSTANCE_BLUEPRINT_FILE" | cut -d "=" -f2 | tr -d '"')

  INSTANCE_LAUNCH_DIR="$INSTANCE_INSTALL_DIR"
  if [[ -n "$instance_install_subdir" ]]; then
    INSTANCE_LAUNCH_DIR="$INSTANCE_INSTALL_DIR/$instance_install_subdir"
  fi

  # shellcheck disable=SC2140
  stdout_file="\$INSTANCE_LOGS_DIR/\$INSTANCE_FULL_NAME-\$(date +"%Y-%m-%dT%H:%M:%S").log"

  export INSTANCE_LOGS_REDIRECT="1>$stdout_file 2>&1"

  # Avoid evaluating INSTANCE_LAUNCH_ARGS as it can contain variables that need
  # to just be passed along, not evaluated
  local instance_launch_args
  instance_launch_args="$(grep "INSTANCE_LAUNCH_ARGS=" < "$instance_config_file" | cut -d '"' -f2 | tr -d '"')"
  export instance_launch_args

  local injected_config
  injected_config=$(
    cat << EOF
# Log redirection into file
INSTANCE_LOGS_REDIRECT="$INSTANCE_LOGS_REDIRECT"

# Directory from which to launch the instance binary
INSTANCE_LAUNCH_DIR="$INSTANCE_LAUNCH_DIR"

$(< "$instance_config_file")
EOF
  )

  local marker="# === BEGIN INJECT CONFIG ==="

  # Replace the marker with the injected config
  if ! sed -i "/${marker}/{
      r /dev/stdin
      d
  }" "$INSTANCE_MANAGE_FILE" <<< "$injected_config"; then
    __print_error "Failed to inject config into $INSTANCE_MANAGE_FILE"
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
  }" "$INSTANCE_MANAGE_FILE" <<< "$injected_config"; then
    __print_error "Failed to inject config into $INSTANCE_MANAGE_FILE"
    return $EC_FAILED_TEMPLATE
  fi

  return 0
}

function _inject_management_overrides() {

  # Source the overrides

  # shellcheck disable=SC1090
  source "$(__load_module overrides.sh)" "$INSTANCE_BP_NAME" || {
    __print_error "Failed to source module overrides.sh"
    return 1
  }

  # Check for function definitions and replace defaults with overrides
  __print_info "Checking for overrides..."

  # Check for _get_latest_version
  if declare -F _get_latest_version > /dev/null; then
    get_latest_version_def=$(declare -f _get_latest_version)
    unset -f _get_latest_version

    __print_into "Found definition for '_get_latest_version', overriding..."
    sed -i "/^function _get_latest_version/,/^}/c\\$get_latest_version_def" "$INSTANCE_MANAGE_FILE"
  fi

  # Check for _download
  if declare -F _download > /dev/null; then
    download_def=$(declare -f _download)
    unset -r _download

    __print_into "Found definition for '_download', overriding..."
    sed -i "/^function _download/,/^}/c\\$download_def" "$INSTANCE_MANAGE_FILE"
  fi

  # Check for _deploy
  if declare -F _deploy > /dev/null; then
    deploy_def=$(declare -f _deploy)
    unset -f _deploy

    __print_into "Found definition for '_deploy', overriding..."
    sed -i "/^function _deploy/,/^}/c\\$deploy_def" "$INSTANCE_MANAGE_FILE"
  fi

  return 0
}

function _create_manage_file() {

  # Prepare source file
  local manage_template_file

  __print_info "Generating management file..."

  # Choose appropriate template based on runtime
  if ! manage_template_file="$(__load_template "manage.${INSTANCE_RUNTIME}")"; then
    __print_error "Failed to manage template for $INSTANCE_FULL_NAME"
    return $EC_FILE_NOT_FOUND
  fi

  # Create the new management file
  if ! cp -f "$manage_template_file" "$INSTANCE_MANAGE_FILE"; then
    __print_error "Failed to generate management template for $INSTANCE_MANAGE_FILE"
    return $EC_FAILED_TEMPLATE
  fi

  # Inject config
  case "$INSTANCE_RUNTIME" in
    native)
      __inject_native_management_variables
      ;;
    docker)
      __inject_docker_management_variables
      ;;
    *)
      __print_error "Invalid instance runtime: $INSTANCE_LIFECYCLE_MANAGER"
      return $EC_GENERAL
      ;;
  esac

  # Inject overrides
  _inject_management_overrides

  # File permissions
  INSTANCE_USER=$USER
  if [ "$EUID" -eq 0 ]; then
    INSTANCE_USER=$SUDO_USER
  fi

  # Make sure file is owned by the user and not root
  if ! chown "$INSTANCE_USER":"$INSTANCE_USER" "$INSTANCE_MANAGE_FILE"; then
    __print_error "Failed to assing $INSTANCE_MANAGE_FILE to user $INSTANCE_USER"
    return $EC_PERMISSION
  fi

  # Make sure it's executable
  if ! chmod +x "$INSTANCE_MANAGE_FILE"; then
    __print_error "Failed to add +x permission to $INSTANCE_MANAGE_FILE"
    return $EC_PERMISSION
  fi

  __print_info "Management file created"

  return 0
}

function _systemd_uninstall() {

  __print_info "Removing systemd integration..."

  if [[ -z "$INSTANCE_SYSTEMD_SERVICE_FILE" ]] && [[ -z "$INSTANCE_SYSTEMD_SOCKET_FILE" ]]; then
    # Nothing to uninstall
    return 0
  fi

  if systemctl is-active "$INSTANCE_FULL_NAME" &> /dev/null; then
    if ! $SUDO systemctl stop "$INSTANCE_FULL_NAME" &> /dev/null; then
      __print_error "Failed to stop $INSTANCE_FULL_NAME before uninstalling systemd files" && return "$EC_SYSTEMD"
    fi
  fi

  if systemctl is-enabled "$INSTANCE_FULL_NAME" &> /dev/null; then
    if ! $SUDO systemctl disable "$INSTANCE_FULL_NAME"; then
      __print_warning "Failed to disable $INSTANCE_FULL_NAME" && return "$EC_SYSTEMD"
    fi
  fi

  # Remove service file
  # shellcheck disable=SC2153
  if [ -f "$INSTANCE_SYSTEMD_SERVICE_FILE" ]; then
    if ! $SUDO rm "$INSTANCE_SYSTEMD_SERVICE_FILE"; then
      __print_error "Failed to remove $INSTANCE_SYSTEMD_SERVICE_FILE" && return "$EC_FAILED_RM"
    fi
  fi

  # Remove socket file
  # shellcheck disable=SC2153
  if [ -f "$INSTANCE_SYSTEMD_SOCKET_FILE" ]; then
    if ! $SUDO rm "$INSTANCE_SYSTEMD_SOCKET_FILE"; then
      __print_error "Failed to remove $INSTANCE_SYSTEMD_SOCKET_FILE" && return "$EC_FAILED_RM"
    fi
  fi

  # Reload systemd

  __print_info "Reloading systemd..."
  if ! $SUDO systemctl daemon-reload; then
    __print_error "Failed to reload systemd" && return "$EC_SYSTEMD"
  fi

  # Remove entries from instance config file and management file
  if ! {
    sed -i "\%# Path to the systemd instance.service file%d" "$instance_config_file" "$INSTANCE_MANAGE_FILE" > /dev/null
    sed -i "\%INSTANCE_SYSTEMD_SERVICE_FILE=$INSTANCE_SYSTEMD_SERVICE_FILE%d" "$instance_config_file" "$INSTANCE_MANAGE_FILE" > /dev/null
  }; then
    __print_error "Failed to remove INSTANCE_SYSTEMD_SERVICE_FILE from config and management files"
    return $EC_FAILED_SED
  fi

  if ! {
    sed -i "\%# Path to the systemd instance.socket file%d" "$instance_config_file" "$INSTANCE_MANAGE_FILE" > /dev/null
    sed -i "\%INSTANCE_SYSTEMD_SOCKET_FILE=$INSTANCE_SYSTEMD_SOCKET_FILE%d" "$instance_config_file" "$INSTANCE_MANAGE_FILE" > /dev/null
  }; then
    __print_error "Failed to remove INSTANCE_SYSTEMD_SOCKET_FILE from config and management files"
    return $EC_FAILED_SED
  fi

  # Change the INSTANCE_LIFECYCLE_MANAGER to standalone
  if ! sed -i "/INSTANCE_LIFECYCLE_MANAGER=*/c\INSTANCE_LIFECYCLE_MANAGER=standalone" "$instance_config_file" "$INSTANCE_MANAGE_FILE" > /dev/null; then
    __print_error "Failed to update the INSTANCE_LIFECYCLE_MANAGER to standalone"
    return $EC_FAILED_SED
  fi

  __print_info "Systemd integration removed"

  return 0
}

function _systemd_install() {

  __print_info "Adding systemd integration..."

  [[ -z "$SYSTEMD_DIR" ]] && __print_error "SYSTEMD_DIR is expected but it's not set" && return $EC_MISSING_ARG

  local service_template_file
  local socket_template_file
  service_template_file="$(__load_template service.tp)"
  socket_template_file="$(__load_template socket.tp)"

  local instance_systemd_service_file=${SYSTEMD_DIR}/${INSTANCE_FULL_NAME}.service
  local instance_systemd_socket_file=${SYSTEMD_DIR}/${INSTANCE_FULL_NAME}.socket

  local temp_systemd_service_file=/tmp/${INSTANCE_FULL_NAME}.service
  local temp_systemd_socket_file=/tmp/${INSTANCE_FULL_NAME}.socket

  local instance_bin_absolute_path
  instance_bin_absolute_path="$INSTANCE_LAUNCH_DIR/$INSTANCE_LAUNCH_BIN"

  # Required by template
  export INSTANCE_BIN_ABSOLUTE_PATH="$instance_bin_absolute_path"
  export INSTANCE_SOCKET_FILE=${INSTANCE_WORKING_DIR}/.${INSTANCE_FULL_NAME}.stdin

  # If service file already exists, check that it belongs to the instance
  if [[ -f "$instance_systemd_service_file" ]]; then
    if [[ -z "$INSTANCE_SYSTEMD_SERVICE_FILE" ]]; then
      __print_error "File '$instance_systemd_service_file' already exists but it doesn't belong to $INSTANCE_FULL_NAME"
      return $EC_GENERAL
    else
      if ! _systemd_uninstall; then
        return "$EC_GENERAL"
      fi
    fi
  fi

  # If socket file already exists, check that it belongs to the instance
  if [[ -f "$instance_systemd_socket_file" ]]; then
    if [[ -z "$INSTANCE_SYSTEMD_SOCKET_FILE" ]]; then
      __print_error "File '$instance_systemd_socket_file' already exists but it doesn't belong to $INSTANCE_FULL_NAME"
      return $EC_GENERAL
    else
      if ! _systemd_uninstall; then
        return $EC_GENERAL
      fi
    fi
  fi

  INSTANCE_USER=$USER
  if [ "$EUID" -eq 0 ]; then
    INSTANCE_USER=$SUDO_USER
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

  if grep -q "INSTANCE_SYSTEMD_SERVICE_FILE=" < "$instance_config_file"; then
    if ! sed -i "/INSTANCE_SYSTEMD_SERVICE_FILE=*/c\INSTANCE_SYSTEMD_SERVICE_FILE=$instance_systemd_service_file" "$instance_config_file" > /dev/null; then
      return $EC_FAILED_SED
    fi
  else
    {
      echo "# Path to the systemd instance.service file"
      echo "INSTANCE_SYSTEMD_SERVICE_FILE=$instance_systemd_service_file"
    } >> "$instance_config_file"
  fi

  if grep -q "INSTANCE_SYSTEMD_SOCKET_FILE=" < "$instance_config_file"; then
    if ! sed -i "/INSTANCE_SYSTEMD_SOCKET_FILE=*/c\INSTANCE_SYSTEMD_SOCKET_FILE=$instance_systemd_socket_file" "$instance_config_file" > /dev/null; then
      return $EC_FAILED_SED
    fi
  else
    {
      echo "# Path to the systemd instance.socket file"
      echo "INSTANCE_SYSTEMD_SOCKET_FILE=$instance_systemd_socket_file"
    } >> "$instance_config_file"
  fi

  # Save it into the instance's management file also. Prepend just before the bottom marker
  local marker="# === END INJECT CONFIG ==="

  if grep -q "INSTANCE_SYSTEMD_SERVICE_FILE=" < "$INSTANCE_MANAGE_FILE"; then
    if ! sed -i "/INSTANCE_SYSTEMD_SERVICE_FILE=*/c\INSTANCE_SYSTEMD_SERVICE_FILE=$instance_systemd_service_file" "$INSTANCE_MANAGE_FILE" > /dev/null; then
      return $EC_FAILED_SED
    fi
  else
    sed -i "/${marker}/i\
# Path to the systemd instance.service file\
INSTANCE_SYSTEMD_SERVICE_FILE=$instance_systemd_service_file
"
    "$INSTANCE_MANAGE_FILE"
  fi

  if grep -q "INSTANCE_SYSTEMD_SOCKET_FILE=" < "$INSTANCE_MANAGE_FILE"; then
    if ! sed -i "/INSTANCE_SYSTEMD_SOCKET_FILE=*/c\INSTANCE_SYSTEMD_SOCKET_FILE=$instance_systemd_socket_file" "$INSTANCE_MANAGE_FILE" > /dev/null; then
      return $EC_FAILED_SED
    fi
  else
    sed -i "/${marker}/i\
# Path to the systemd instance.socket file\
INSTANCE_SYSTEMD_SOCKET_FILE=$instance_systemd_socket_file
"
    "$INSTANCE_MANAGE_FILE"
  fi

  # Change the INSTANCE_LIFECYCLE_MANAGER to systemd in both files
  if ! sed -i "/INSTANCE_LIFECYCLE_MANAGER=*/c\INSTANCE_LIFECYCLE_MANAGER=systemd" "$instance_config_file" "$INSTANCE_MANAGE_FILE" > /dev/null; then
    __print_error "Failed to update the INSTANCE_LIFECYCLE_MANAGER to systemd"
    return $EC_FAILED_SED
  fi

  __print_info "Systemd integration complete"

  return 0
}

function _ufw_uninstall() {

  __print_info "Removing UFW integration..."

  [[ -z "$UFW_RULES_DIR" ]] && __print_error "UFW_RULES_DIR is expected but it's not set" && return "$EC_MISSING_ARG"
  [[ -z "$INSTANCE_UFW_FILE" ]] && return 0
  [[ ! -f "$INSTANCE_UFW_FILE" ]] && return 0

  # Remove ufw rule
  __print_info "Deleting UFW rule"
  if ! $SUDO ufw delete allow "$INSTANCE_FULL_NAME" &> /dev/null; then
    __print_error "Failed to remove UFW rule for $INSTANCE_FULL_NAME"
    return $EC_UFW
  fi

  if [ -f "$INSTANCE_UFW_FILE" ]; then
    # Delete firewall rule file
    __print_info "Deleting rule definition file"
    if ! $SUDO rm "$INSTANCE_UFW_FILE"; then
      __print_error "Failed to remove $INSTANCE_UFW_FILE"
      return $EC_FAILED_RM
    fi
  fi

  # Remove UFW entries from the instance config file
  sed -i "\%# Path the the UFW firewall rule file%d" "$instance_config_file" "$INSTANCE_MANAGE_FILE" > /dev/null
  if ! sed -i "\%INSTANCE_UFW_FILE=$INSTANCE_UFW_FILE%d" "$instance_config_file" "$INSTANCE_MANAGE_FILE" > /dev/null; then
    __print_error "Failed to remove UFW firewall rule file from config and management files"
    return $EC_UFW
  fi

  __print_info "UFW integration removed"

  return 0
}

function _ufw_install() {

  __print_info "Adding UFW integration..."

  if [[ -z "$UFW_RULES_DIR" ]]; then
    __print_error "UFW_RULES_DIR is expected but it's not set"
    return $EC_MISSING_ARG
  fi

  local instance_ufw_file=${UFW_RULES_DIR}/kgsm-${INSTANCE_FULL_NAME}
  local temp_ufw_file=/tmp/kgsm-${INSTANCE_FULL_NAME}

  # If firewall rule file already exists, remove it
  if [[ -f "$instance_ufw_file" ]]; then
    __print_error "A UFW rule definition file for this instance already exists at '${instance_ufw_file}'. Manually remove it before trying again"
    return $EC_GENERAL
  fi

  # shellcheck disable=SC2155
  local ufw_template_file="$(__load_template ufw.tp)"

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
  if ! $SUDO ufw allow "$INSTANCE_FULL_NAME" &> /dev/null; then
    __print_error "Failed to allow UFW rule for $INSTANCE_FULL_NAME" && return "$EC_UFW"
  fi

  if grep -q "INSTANCE_UFW_FILE=" < "$instance_config_file"; then
    if ! sed -i "/INSTANCE_UFW_FILE=*/c\INSTANCE_UFW_FILE=$instance_ufw_file" "$instance_config_file" > /dev/null; then
      return $EC_FAILED_SED
    fi
  else
    {
      echo "# Path the the UFW firewall rule file"
      echo "INSTANCE_UFW_FILE=$instance_ufw_file"
    } >> "$instance_config_file"
  fi

  # Update INSTANCE_MANAGE_FILE UFW definition

  local marker="=== END INJECT CONFIG ==="

  if grep -q "INSTANCE_UFW_FILE=" < "$INSTANCE_MANAGE_FILE"; then
    if ! sed -i "/INSTANCE_UFW_FILE=*/c\INSTANCE_UFW_FILE=$instance_ufw_file" "$INSTANCE_MANAGE_FILE" > /dev/null; then
      return $EC_FAILED_SED
    fi
  else
    sed -i "/${marker}/i\
# Path the the UFW firewall rule file
INSTANCE_UFW_FILE=$instance_ufw_file
"
    "$INSTANCE_MANAGE_FILE"
  fi

  __print_info "UFW integration complete"

  return 0
}

function _create_symlink() {


  __print_info "Instance \"${instance%.ini}\" symlink created in $INSTANCE_MANAGEMENT_SYMLINK_DIR"
}

function _create() {
  _create_manage_file || return $?

  if [[ "$INSTANCE_LIFECYCLE_MANAGER" == "systemd" ]]; then
    _systemd_install || return $?
  fi

  if [[ "$USE_UFW" -eq 1 ]]; then
    _ufw_install || return $?
  fi

  if [[ "$USE_INSTANCE_MANAGEMENT_SYMLINK" -eq 1 ]]; then
    _create_symlink || return $?
  fi

  __emit_instance_files_created "${instance%.ini}"
  return 0
}

function _remove() {
  if [[ "$INSTANCE_LIFECYCLE_MANAGER" == "systemd" ]]; then
    _systemd_uninstall || return $?
  fi

  if [[ "$USE_UFW" -eq 1 ]]; then
    _ufw_uninstall || return $?
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
        *)
          __print_error "Invalid argument $1"
          exit $EC_INVALID_ARG
          ;;
      esac
      ;;
    *)
      __print_error "Invalid argument $1"
      exit$EC_INVALID_ARG
      ;;
  esac
  shift
done

exit $?
