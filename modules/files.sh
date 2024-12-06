#!/bin/bash

function usage() {
  echo "Manages the various necessary files to run a game server.

Usage:
  $(basename "$0") [-i | --instance <instance>] OPTION

Options:
  -h, --help                 Prints this message
  -i, --instance <instance>  Full name of the instance, equivalent of
                             INSTANCE_FULL_NAME from the instance config file
                             The .ini extension is not required
    --create                 Generates all files:
                             instance.manage.sh file, instance.override.sh
                             file if applicable, systemd service/ socket files
                             and ufw firewall rules if applicable.
      [--manage]             Creates the instance.manage.sh file
      [--override]           Creates the instance.overrides.sh file if applicable
      [--systemd]            Generates the systemd service/socket files
      [--ufw]                Generates the ufw firewall rule file and enables it
    --remove                 Removes and disables systemd service/socket files
                             and UFW firewall rule
      [--systemd]            Removes the systemd service and socket files
      [--ufw]                Removes the ufw firewall rule files

Examples:
  $(basename "$0") -i factorio-L2ZeLQ.ini --create
  $(basename "$0") -i 7dtd-fqcLvt --remove --ufw
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check for KGSM_ROOT
if [ -z "$KGSM_ROOT" ]; then
  # Search for the kgsm.sh file to dynamically set KGSM_ROOT
  KGSM_ROOT=$(find "$SCRIPT_DIR" -maxdepth 2 -name 'kgsm.sh' -exec dirname {} \;)
  [[ -z "$KGSM_ROOT" ]] && echo "Error: Could not locate kgsm.sh. Ensure the directory structure is intact." && exit 1
  export KGSM_ROOT
fi

module_common="$(find "$KGSM_ROOT" -type f -name common.sh -print -quit)"
[[ -z "$module_common" ]] && echo "${0##*/} ERROR: Failed to load module common.sh" >&2 && exit 1

# shellcheck disable=SC1090
source "$module_common" || exit 1

instance_config_file=$(__load_instance "$instance")
# shellcheck disable=SC1090
source "$instance_config_file" || exit "$EC_FAILED_SOURCE"

[[ "$EUID" -ne 0 ]] && SUDO="sudo -E"

function _create_manage_file() {
  # shellcheck disable=SC2155
  local manage_template_file="$(__load_template manage.tp)"

  local instance_manage_file="${INSTANCE_WORKING_DIR}/${INSTANCE_FULL_NAME}.manage.sh"
  export INSTANCE_SOCKET_FILE="${INSTANCE_WORKING_DIR}/.${INSTANCE_FULL_NAME}.stdin"

  if grep -q "INSTANCE_SOCKET_FILE=" <"$instance_config_file"; then
    sed -i "/INSTANCE_SOCKET_FILE=*/c\INSTANCE_SOCKET_FILE=$INSTANCE_SOCKET_FILE" "$instance_config_file" >/dev/null
  else
    {
      echo ""
      echo "# Path to the Unix Domain Socket"
      echo "INSTANCE_SOCKET_FILE=$INSTANCE_SOCKET_FILE"
    } >>"$instance_config_file"
  fi

  # shellcheck disable=SC2155
  local instance_install_subdir=$(grep "BP_INSTALL_SUBDIRECTORY=" <"$INSTANCE_BLUEPRINT_FILE" | cut -d "=" -f2 | tr -d '"')

  # Used by the template
  INSTANCE_LAUNCH_DIR="$INSTANCE_INSTALL_DIR"
  if [[ -n "$instance_install_subdir" ]]; then
    INSTANCE_LAUNCH_DIR="$INSTANCE_INSTALL_DIR/$instance_install_subdir"
  fi

  # Required by the template
  export INSTANCE_LAUNCH_DIR
  # Stores PID of the game server
  export INSTANCE_PID_FILE="$INSTANCE_WORKING_DIR/.${INSTANCE_FULL_NAME}.pid"
  # Stores PID of the dummy writer that keeps input socket alive
  export TAIL_PID_FILE="$INSTANCE_WORKING_DIR/.${INSTANCE_FULL_NAME}.tail.pid"

  # shellcheck disable=SC2140
  stdout_file="$INSTANCE_LOGS_DIR/$INSTANCE_FULL_NAME-\"\$(date +"%Y-%m-%dT%H:%M:%S")\".log"

  export INSTANCE_LOGS_REDIRECT="1>$stdout_file 2>&1"

  if grep -q "INSTANCE_PID_FILE=" <"$instance_config_file"; then
    sed -i "/INSTANCE_PID_FILE=*/c\INSTANCE_PID_FILE=$INSTANCE_PID_FILE" "$instance_config_file" >/dev/null
  else
    {
      echo ""
      echo "# File where the instance process ID will be stored while the instance is running"
      echo "INSTANCE_PID_FILE=$INSTANCE_PID_FILE"
    } >>"$instance_config_file"
  fi

  # Create manage.sh from template and put it in $instance_manage_file
  if ! eval "cat <<EOF
$(<"$manage_template_file")
EOF
" >"$instance_manage_file" 2>/dev/null; then
    __print_error "Could not generate template for $instance_manage_file" && return 1
  fi

  INSTANCE_USER=$USER
  if [ "$EUID" -eq 0 ]; then
    INSTANCE_USER=$SUDO_USER
  fi

  # Make sure file is owned by the user and not root
  if ! chown "$INSTANCE_USER":"$INSTANCE_USER" "$instance_manage_file"; then
    __print_error "Failed to assing $instance_manage_file to $INSTANCE_USER" && return "$EC_PERMISSION"
  fi

  if ! chmod +x "$instance_manage_file"; then
    __print_error "Failed to add +x permission to $instance_manage_file" && return "$EC_PERMISSION"
  fi

  if grep -q "INSTANCE_MANAGE_FILE=" <"$instance_config_file"; then
    sed -i "/INSTANCE_MANAGE_FILE=*/c\INSTANCE_MANAGE_FILE=$instance_manage_file" "$instance_config_file" >/dev/null
  else
    {
      echo ""
      echo "# Path to the instance.manage.sh script file"
      echo "INSTANCE_MANAGE_FILE=$instance_manage_file"
    } >>"$instance_config_file"
  fi

  return 0
}

function _create_overrides_file() {
  # shellcheck disable=SC2155
  local overrides_file="$(find "$OVERRIDES_SOURCE_DIR" -type f -name "$INSTANCE_NAME".overrides.sh)"
  [[ ! -f "$overrides_file" ]] && return 0

  local instance_overrides_file=${INSTANCE_WORKING_DIR}/${INSTANCE_FULL_NAME}.overrides.sh

  # Make copy
  if ! cp -f "$overrides_file" "$instance_overrides_file"; then
    __print_error "Could not copy $overrides_file to $instance_overrides_file" && return "$EC_FAILED_CP"
  fi

  INSTANCE_USER=$USER
  if [ "$EUID" -eq 0 ]; then
    INSTANCE_USER=$SUDO_USER
  fi

  # Make sure file is owned by the user and not root
  if ! chown "$INSTANCE_USER":"$INSTANCE_USER" "$instance_overrides_file"; then
    __print_error "Failed to assing $instance_overrides_file to $INSTANCE_USER" && return "$EC_PERMISSION"
  fi

  if grep -q "INSTANCE_OVERRIDES_FILE=" <"$instance_config_file"; then
    sed -i "/INSTANCE_OVERRIDES_FILE=*/c\INSTANCE_OVERRIDES_FILE=$instance_overrides_file" "$instance_config_file" >/dev/null
  else
    {
      echo ""
      echo "# Path to the instance.overrides.sh script file"
      echo "INSTANCE_OVERRIDES_FILE=$instance_overrides_file"
    } >>"$instance_config_file"
  fi

  return 0
}

function _systemd_uninstall() {
  if [[ -z "$INSTANCE_SYSTEMD_SERVICE_FILE" ]] && [[ -z "$INSTANCE_SYSTEMD_SOCKET_FILE" ]]; then
    # Nothing to uninstall
    return 0
  fi

  if systemctl is-active "$INSTANCE_FULL_NAME" &>/dev/null; then
    if ! $SUDO systemctl stop "$INSTANCE_FULL_NAME" &>/dev/null; then
      __print_error "Failed to stop $INSTANCE_FULL_NAME before uninstalling systemd files" && return "$EC_SYSTEMD"
    fi
  fi

  if systemctl is-enabled "$INSTANCE_FULL_NAME" &>/dev/null; then
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
  if ! $SUDO systemctl daemon-reload; then
    __print_error "Failed to reload systemd" && return "$EC_SYSTEMD"
  fi

  # Remove entries from instance config file
  sed -i "\%# Path to the systemd instance.service file%d" "$instance_config_file" >/dev/null
  if ! sed -i "\%INSTANCE_SYSTEMD_SERVICE_FILE=$INSTANCE_SYSTEMD_SERVICE_FILE%d" "$instance_config_file" >/dev/null; then
    __print_error "Failed to remove INSTANCE_SYSTEMD_SERVICE_FILE from $instance_config_file" && return "$EC_FAILED_SED"
  fi

  sed -i "\%# Path to the systemd instance.socket file%d" "$instance_config_file" >/dev/null
  if ! sed -i "\%INSTANCE_SYSTEMD_SOCKET_FILE=$INSTANCE_SYSTEMD_SOCKET_FILE%d" "$instance_config_file" >/dev/null; then
    __print_error "Failed to remove INSTANCE_SYSTEMD_SOCKET_FILE from $instance_config_file" && return "$EC_FAILED_SED"
  fi

  # Change the INSTANCE_LIFECYCLE_MANAGER to standalone
  if ! sed -i "/INSTANCE_LIFECYCLE_MANAGER=*/c\INSTANCE_LIFECYCLE_MANAGER=standalone" "$instance_config_file" >/dev/null; then
    __print_error "Failed to update the INSTANCE_LIFECYCLE_MANAGER to standalone" && return "$EC_FAILED_SED"
  fi

  return 0
}

function _systemd_install() {
  [[ -z "$SYSTEMD_DIR" ]] && __print_error "SYSTEMD_DIR is expected but it's not set" && return "$EC_MISSING_ARG"

  local service_template_file
  local socket_template_file
  service_template_file="$(__load_template service.tp)"
  socket_template_file="$(__load_template socket.tp)"

  local instance_systemd_service_file=${SYSTEMD_DIR}/${INSTANCE_FULL_NAME}.service
  local instance_systemd_socket_file=${SYSTEMD_DIR}/${INSTANCE_FULL_NAME}.socket

  local temp_systemd_service_file=/tmp/${INSTANCE_FULL_NAME}.service
  local temp_systemd_socket_file=/tmp/${INSTANCE_FULL_NAME}.socket

  # Required by template
  # shellcheck disable=SC2155
  export INSTANCE_MANAGE_FILE=$(grep "INSTANCE_MANAGE_FILE=" <"$instance_config_file" | cut -d "=" -f2 | tr -d '"')
  export INSTANCE_SOCKET_FILE=${INSTANCE_WORKING_DIR}/.${INSTANCE_FULL_NAME}.stdin

  # If service file already exists, check that it belongs to the instance
  if [[ -f "$instance_systemd_service_file" ]]; then
    if [[ -z "$INSTANCE_SYSTEMD_SERVICE_FILE" ]]; then
      __print_error "File '$instance_systemd_service_file' already exists but it doesn't belong to $INSTANCE_FULL_NAME" && return "$EC_GENERAL"
    else
      if ! _systemd_uninstall; then
        return "$EC_GENERAL"
      fi
    fi
  fi

  # If socket file already exists, check that it belongs to the instance
  if [[ -f "$instance_systemd_socket_file" ]]; then
    if [[ -z "$INSTANCE_SYSTEMD_SOCKET_FILE" ]]; then
      __print_error "File '$instance_systemd_socket_file' already exists but it doesn't belong to $INSTANCE_FULL_NAME" && return "$EC_GENERAL"
    else
      if ! _systemd_uninstall; then
        return "$EC_GENERAL"
      fi
    fi
  fi

  INSTANCE_USER=$USER
  if [ "$EUID" -eq 0 ]; then
    INSTANCE_USER=$SUDO_USER
  fi

  # Create the service file
  if ! eval "cat <<EOF
$(<"$service_template_file")
EOF
" >"$temp_systemd_service_file" 2>/dev/null; then
    __print_error "Could not generate $service_template_file to $temp_systemd_service_file" && return "$EC_FAILED_TEMPLATE"
  fi

  if ! $SUDO mv "$temp_systemd_service_file" "$instance_systemd_service_file"; then
    __print_error "Failed to move $temp_systemd_socket_file into $instance_systemd_service_file" && return "$EC_FAILED_MV"
  fi

  if ! $SUDO chown root:root "$instance_systemd_service_file"; then
    __print_error "Failed to assign root user ownership to $instance_systemd_service_file" && return "$EC_PERMISSION"
  fi

  # Create the socket file
  if ! eval "cat <<EOF
$(<"$socket_template_file")
EOF
" >"$temp_systemd_socket_file" 2>/dev/null; then
    __print_error "Could not generate $socket_template_file to $temp_systemd_socket_file" && return "$EC_FAILED_TEMPLATE"
  fi

  if ! $SUDO mv "$temp_systemd_socket_file" "$instance_systemd_socket_file"; then
    __print_error "Failed to move $instance_systemd_socket_file into $instance_systemd_socket_file" && return "$EC_FAILED_MV"
  fi

  if ! $SUDO chown root:root "$instance_systemd_socket_file"; then
    __print_error "Failed to assign root user ownership to $instance_systemd_socket_file" && return "$EC_PERMISSION"
  fi

  # Reload systemd
  if ! $SUDO systemctl daemon-reload; then
    __print_error "Failed to reload systemd" && return "$EC_SYSTEMD"
  fi

  if grep -q "INSTANCE_SOCKET_FILE=" <"$instance_config_file"; then
    if ! sed -i "/INSTANCE_SOCKET_FILE=*/c\INSTANCE_SOCKET_FILE=$INSTANCE_SOCKET_FILE" "$instance_config_file" >/dev/null; then
      return "$EC_FAILED_SED"
    fi
  else
    {
      echo "# Path to the Unix Domain Socket"
      echo "INSTANCE_SOCKET_FILE=$INSTANCE_SOCKET_FILE"
    } >>"$instance_config_file"
  fi

  if grep -q "INSTANCE_SYSTEMD_SERVICE_FILE=" <"$instance_config_file"; then
    if ! sed -i "/INSTANCE_SYSTEMD_SERVICE_FILE=*/c\INSTANCE_SYSTEMD_SERVICE_FILE=$instance_systemd_service_file" "$instance_config_file" >/dev/null; then
      return "$EC_FAILED_SED"
    fi
  else
    {
      echo "# Path to the systemd instance.service file"
      echo "INSTANCE_SYSTEMD_SERVICE_FILE=$instance_systemd_service_file"
    } >>"$instance_config_file"
  fi

  if grep -q "INSTANCE_SYSTEMD_SOCKET_FILE=" <"$instance_config_file"; then
    if ! sed -i "/INSTANCE_SYSTEMD_SOCKET_FILE=*/c\INSTANCE_SYSTEMD_SOCKET_FILE=$instance_systemd_socket_file" "$instance_config_file" >/dev/null; then
      return "$EC_FAILED_SED"
    fi
  else
    {
      echo "# Path to the systemd instance.socket file"
      echo "INSTANCE_SYSTEMD_SOCKET_FILE=$instance_systemd_socket_file"
    } >>"$instance_config_file"
  fi

  # Change the INSTANCE_LIFECYCLE_MANAGER to systemd
  if ! sed -i "/INSTANCE_LIFECYCLE_MANAGER=*/c\INSTANCE_LIFECYCLE_MANAGER=systemd" "$instance_config_file" >/dev/null; then
     __print_error "Failed to update the INSTANCE_LIFECYCLE_MANAGER to systemd" && return "$EC_FAILED_SED"
  fi

  return 0
}

function _ufw_uninstall() {
  [[ -z "$UFW_RULES_DIR" ]] && __print_error "UFW_RULES_DIR is expected but it's not set" && return "$EC_MISSING_ARG"
  [[ -z "$INSTANCE_UFW_FILE" ]] && return 0
  [[ ! -f "$INSTANCE_UFW_FILE" ]] && return 0

  # Remove ufw rule
  if ! $SUDO ufw delete allow "$INSTANCE_FULL_NAME" &>/dev/null; then
    __print_error "Failed to remove UFW rule for $INSTANCE_FULL_NAME" && return "$EC_UFW"
  fi

  if [ -f "$INSTANCE_UFW_FILE" ]; then
    # Delete firewall rule file
    if ! $SUDO rm "$INSTANCE_UFW_FILE"; then
      __print_error "Failed to remove $INSTANCE_UFW_FILE" && return "$EC_FAILED_RM"
    fi
  fi

  # Remove UFW entries from the instance config file
  sed -i "\%# Path the the UFW firewall rule file%d" "$instance_config_file" >/dev/null
  if ! sed -i "\%INSTANCE_UFW_FILE=$INSTANCE_UFW_FILE%d" "$instance_config_file" >/dev/null; then
    __print_error "Failed to remove UFW firewall rule file from $instance_config_file" && return "$EC_UFW"
  fi

  return 0
}

function _ufw_install() {
  [[ -z "$UFW_RULES_DIR" ]] && __print_error "UFW_RULES_DIR is expected but it's not set" && return "$EC_MISSING_ARG"

  local instance_ufw_file=${UFW_RULES_DIR}/kgsm-${INSTANCE_FULL_NAME}
  local temp_ufw_file=/tmp/kgsm-${INSTANCE_FULL_NAME}

  # If firewall rule file already exists, remove it
  if [ -f "$instance_ufw_file" ]; then
    if ! _ufw_uninstall; then return "$EC_GENERAL"; fi
  fi

  # shellcheck disable=SC2155
  local ufw_template_file="$(__load_template ufw.tp)"

  # Create firewall rule file from template
  if ! eval "cat <<EOF
$(<"$ufw_template_file")
EOF
" >"$temp_ufw_file"; then
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
  if ! $SUDO ufw allow "$INSTANCE_FULL_NAME" &>/dev/null; then
    __print_error "Failed to allow UFW rule for $INSTANCE_FULL_NAME" && return "$EC_UFW"
  fi

  if grep -q "INSTANCE_UFW_FILE=" <"$instance_config_file"; then
    if ! sed -i "/INSTANCE_UFW_FILE=*/c\INSTANCE_UFW_FILE=$instance_ufw_file" "$instance_config_file" >/dev/null; then
      return "$EC_FAILED_SED"
    fi
  else
    {
      echo "# Path the the UFW firewall rule file"
      echo "INSTANCE_UFW_FILE=$instance_ufw_file"
    } >>"$instance_config_file"
  fi

  return 0
}

function _create() {
  _create_manage_file || return $?
  _create_overrides_file || return $?

  if [[ "$INSTANCE_LIFECYCLE_MANAGER" == "systemd" ]]; then
    _systemd_install || return $?
  fi

  if [[ "$USE_UFW" -eq 1 ]]; then
    _ufw_install || return $?
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
    if [[ -z "$1" ]]; then _create; exit $?; fi
    case "$1" in
    --manage)
      _create_manage_file; exit $?
      ;;
    --override)
      _create_overrides_file; exit $?
      ;;
    --systemd)
      _systemd_install; exit $?
      ;;
    --ufw)
      _ufw_install; exit $?
      ;;
    *)
      __print_error "Invalid argument $1" && exit "$EC_INVALID_ARG"
      ;;
    esac
    ;;
  --remove)
    shift
    if [[ -z "$1" ]]; then _remove; exit $?; fi
    case "$1" in
    --systemd)
      _systemd_uninstall; exit $?
      ;;
    --ufw)
      _ufw_uninstall; exit $?
      ;;
    *)
      __print_error "Invalid argument $1" && exit "$EC_INVALID_ARG"
      ;;
    esac
    ;;
  *)
    __print_error "Invalid argument $1" && exit "$EC_INVALID_ARG"
    ;;
  esac
  shift
done
