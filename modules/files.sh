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
                             [instance].manage.sh file, [instance].override.sh
                             file if applicable, systemd service/ socket files
                             and ufw firewall rules if applicable.
      [--manage]             Creates the [instance].manage.sh file
      [--override]           Creates the [instance].overrides.sh file if applicable
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

set -eo pipefail

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

# Check for KGSM_ROOT env variable
if [ -z "$KGSM_ROOT" ]; then
  echo "WARNING: KGSM_ROOT not found, sourcing /etc/environment." >&2
  # shellcheck disable=SC1091
  source /etc/environment
  [[ -z "$KGSM_ROOT" ]] && echo "${0##*/} ERROR: KGSM_ROOT not found, exiting." >&2 && exit 1
  echo "INFO: KGSM_ROOT found in /etc/environment, consider rebooting the system" >&2
  if ! declare -p KGSM_ROOT | grep -q 'declare -x'; then export KGSM_ROOT; fi
fi

# Read configuration file
if [ -z "$KGSM_CONFIG_LOADED" ]; then
  CONFIG_FILE="$(find "$KGSM_ROOT" -type f -name config.ini)"
  [[ -z "$CONFIG_FILE" ]] && echo "${0##*/} ERROR: Failed to load config.ini file" >&2 && exit 1
  while IFS= read -r line || [ -n "$line" ]; do
    # Ignore comment lines and empty lines
    if [[ "$line" =~ ^#.*$ ]] || [[ -z "$line" ]]; then continue; fi
    export "${line?}"
  done <"$CONFIG_FILE"
  export KGSM_CONFIG_LOADED=1
fi

# Trap CTRL-C
trap "echo "" && exit" INT

module_common=$(find "$KGSM_ROOT" -type f -name common.sh)
[[ -z "$module_common" ]] && echo "${0##*/} ERROR: Could not find module common.sh" >&2 && exit 1

# shellcheck disable=SC1090
source "$module_common" || exit 1

instance_config_file=$(__load_instance "$instance")
# shellcheck disable=SC1090
source "$instance_config_file" || exit 1

[[ "$EUID" -ne 0 ]] && SUDO="sudo -E"

function _create_manage_file() {
  # shellcheck disable=SC2155
  local manage_template_file="$(__load_template manage.tp)"

  local instance_manage_file="${INSTANCE_WORKING_DIR}/${INSTANCE_FULL_NAME}.manage.sh"
  export INSTANCE_SOCKET_FILE="${INSTANCE_WORKING_DIR}/.${INSTANCE_FULL_NAME}.stdin"

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
    echo "${0##*/} ERROR: Could not generate template for $instance_manage_file" >&2 && return 1
  fi

  INSTANCE_USER=$USER
  if [ "$EUID" -eq 0 ]; then
    INSTANCE_USER=$SUDO_USER
  fi

  # Make sure file is owned by the user and not root
  if ! chown "$INSTANCE_USER":"$INSTANCE_USER" "$instance_manage_file"; then
    echo "${0##*/} ERROR: Failed to assing $instance_manage_file to $INSTANCE_USER" >&2 && return 1
  fi

  if ! chmod +x "$instance_manage_file"; then
    echo "${0##*/} ERROR: Failed to add +x permission to $instance_manage_file" >&2 && return 1
  fi

  if grep -q "INSTANCE_MANAGE_FILE=" <"$instance_config_file"; then
    sed -i "/INSTANCE_MANAGE_FILE=*/c\INSTANCE_MANAGE_FILE=$instance_manage_file" "$instance_config_file" >/dev/null
  else
    {
      echo ""
      echo "# Path to the [instance].manage.sh script file"
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
    echo "${0##*/} ERROR: Could not copy $overrides_file to $instance_overrides_file" >&2 && return 1
  fi

  INSTANCE_USER=$USER
  if [ "$EUID" -eq 0 ]; then
    INSTANCE_USER=$SUDO_USER
  fi

  # Make sure file is owned by the user and not root
  if ! chown "$INSTANCE_USER":"$INSTANCE_USER" "$instance_overrides_file"; then
    echo "${0##*/} ERROR: Failed to assing $instance_overrides_file to $INSTANCE_USER" >&2 && return 1
  fi

  # if ! chmod +x "$instance_overrides_file"; then
  #   echo "${0##*/} ERROR: Failed to add +x permission to $instance_overrides_file" >&2 && return 1
  # fi

  if grep -q "INSTANCE_OVERRIDES_FILE=" <"$instance_config_file"; then
    sed -i "/INSTANCE_OVERRIDES_FILE=*/c\INSTANCE_OVERRIDES_FILE=$instance_overrides_file" "$instance_config_file" >/dev/null
  else
    {
      echo ""
      echo "# Path to the [instance].overrides.sh script file"
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
      echo "${0##*/} ERROR: Failed to stop $INSTANCE_FULL_NAME before uninstalling systemd files" >&2 && return 1
    fi
  fi

  if systemctl is-enabled "$INSTANCE_FULL_NAME" &>/dev/null; then
    if ! $SUDO systemctl disable "$INSTANCE_FULL_NAME"; then
      echo "WARNING: Failed to disable $INSTANCE_FULL_NAME" >&2
    fi
  fi

  # Remove service file
  # shellcheck disable=SC2153
  if [ -f "$INSTANCE_SYSTEMD_SERVICE_FILE" ]; then
    if ! $SUDO rm "$INSTANCE_SYSTEMD_SERVICE_FILE"; then
      echo "${0##*/} ERROR: Failed to remove $INSTANCE_SYSTEMD_SERVICE_FILE" >&2 && return 1
    fi
  fi

  # Remove socket file
  # shellcheck disable=SC2153
  if [ -f "$INSTANCE_SYSTEMD_SOCKET_FILE" ]; then
    if ! $SUDO rm "$INSTANCE_SYSTEMD_SOCKET_FILE"; then
      echo "${0##*/} ERROR: Failed to remove $INSTANCE_SYSTEMD_SOCKET_FILE" >&2 && return 1
    fi
  fi

  # Reload systemd
  if ! $SUDO systemctl daemon-reload; then
    echo "${0##*/} ERROR: Failed to reload systemd" >&2 && return 1
  fi

  return 0
}

function _systemd_install() {
  [[ -z "$SYSTEMD_DIR" ]] && echo "${0##*/} ERROR: SYSTEMD_DIR is expected but it's not set" >&2 && return 1

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
      echo "${0##*/} ERROR: File '$instance_systemd_service_file' already exists but it doesn't belong to $INSTANCE_FULL_NAME" >&2 && return 1
    else
      if ! _systemd_uninstall; then return 1; fi
    fi
  fi

  # If socket file already exists, check that it belongs to the instance
  if [[ -f "$instance_systemd_socket_file" ]]; then
    if [[ -z "$INSTANCE_SYSTEMD_SOCKET_FILE" ]]; then
      echo "${0##*/} ERROR: File '$instance_systemd_socket_file' already exists but it doesn't belong to $INSTANCE_FULL_NAME" >&2 && return 1
    else
      if ! _systemd_uninstall; then return 1; fi
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
    echo "${0##*/} ERROR: Could not generate $service_template_file to $temp_systemd_service_file" >&2 && return 1
  fi

  if ! $SUDO mv "$temp_systemd_service_file" "$instance_systemd_service_file"; then
    echo "${0##*/} ERROR: Failed to move $temp_systemd_socket_file into $instance_systemd_service_file" >&2 && return 1
  fi

  if ! $SUDO chown root:root "$instance_systemd_service_file"; then
    echo "${0##*/} ERROR: Failed to assign root user ownership to $instance_systemd_service_file" >&2 && return 1
  fi

  # Create the socket file
  if ! eval "cat <<EOF
$(<"$socket_template_file")
EOF
" >"$temp_systemd_socket_file" 2>/dev/null; then
    echo "${0##*/} ERROR: Could not generate $socket_template_file to $temp_systemd_socket_file" >&2 && return 1
  fi

  if ! $SUDO mv "$temp_systemd_socket_file" "$instance_systemd_socket_file"; then
    echo "${0##*/} ERROR: Failed to move $instance_systemd_socket_file into $instance_systemd_socket_file" >&2 && return 1
  fi

  if ! $SUDO chown root:root "$instance_systemd_socket_file"; then
    echo "${0##*/} ERROR: Failed to assign root user ownership to $instance_systemd_socket_file" >&2 && return 1
  fi

  # Reload systemd
  if ! $SUDO systemctl daemon-reload; then
    echo "${0##*/} ERROR: Failed to reload systemd" >&2 && return 1
  fi

  if grep -q "INSTANCE_SOCKET_FILE=" <"$instance_config_file"; then
    sed -i "/INSTANCE_SOCKET_FILE=*/c\INSTANCE_SOCKET_FILE=$INSTANCE_SOCKET_FILE" "$instance_config_file" >/dev/null
  else
    {
      echo ""
      echo "# Path to the Unix Domain Socket"
      echo "INSTANCE_SOCKET_FILE=$INSTANCE_SOCKET_FILE"
    } >>"$instance_config_file"
  fi

  if grep -q "INSTANCE_SYSTEMD_SERVICE_FILE=" <"$instance_config_file"; then
    sed -i "/INSTANCE_SYSTEMD_SERVICE_FILE=*/c\INSTANCE_SYSTEMD_SERVICE_FILE=$instance_systemd_service_file" "$instance_config_file" >/dev/null
  else
    {
      echo ""
      echo "# Path to the systemd [instance].service file"
      echo "INSTANCE_SYSTEMD_SERVICE_FILE=$instance_systemd_service_file"
    } >>"$instance_config_file"
  fi

  if grep -q "INSTANCE_SYSTEMD_SOCKET_FILE=" <"$instance_config_file"; then
    sed -i "/INSTANCE_SYSTEMD_SOCKET_FILE=*/c\INSTANCE_SYSTEMD_SOCKET_FILE=$instance_systemd_socket_file" "$instance_config_file" >/dev/null
  else
    {
      echo ""
      echo "# Path to the systemd [instance].socket file"
      echo "INSTANCE_SYSTEMD_SOCKET_FILE=$instance_systemd_socket_file"
    } >>"$instance_config_file"
  fi

  return 0
}

function _ufw_uninstall() {
  [[ -z "$UFW_RULES_DIR" ]] && echo "${0##*/} ERROR: UFW_RULES_DIR is expected but it's not set" >&2 && return 1
  [[ -z "$INSTANCE_UFW_FILE" ]] && return 0
  [[ ! -f "$INSTANCE_UFW_FILE" ]] && return 0

  # Remove ufw rule
  if ! $SUDO ufw delete allow "$INSTANCE_FULL_NAME" &>/dev/null; then
    echo "${0##*/} ERROR: Failed to remove UFW rule for $INSTANCE_FULL_NAME" >&2 && return 1
  fi

  if [ -f "$INSTANCE_UFW_FILE" ]; then
    # Delete firewall rule file
    if ! $SUDO rm "$INSTANCE_UFW_FILE"; then
      echo "${0##*/} ERROR: Failed to remove $INSTANCE_UFW_FILE" >&2 && return 1
    fi
  fi

  return 0
}

function _ufw_install() {
  [[ -z "$UFW_RULES_DIR" ]] && echo "${0##*/} ERROR: UFW_RULES_DIR is expected but it's not set" >&2 && return 1

  local instance_ufw_file=${UFW_RULES_DIR}/kgsm-${INSTANCE_FULL_NAME}
  local temp_ufw_file=/tmp/kgsm-${INSTANCE_FULL_NAME}

  # If firewall rule file already exists, remove it
  if [ -f "$instance_ufw_file" ]; then
    if ! _ufw_uninstall; then return 1; fi
  fi

  # shellcheck disable=SC2155
  local ufw_template_file="$(__load_template ufw.tp)"

  # Create firewall rule file from template
  if ! eval "cat <<EOF
$(<"$ufw_template_file")
EOF
" >"$temp_ufw_file"; then
    echo "${0##*/} ERROR: Failed writing rules to $temp_ufw_file" >&2 && return 1
  fi

  if ! $SUDO mv "$temp_ufw_file" "$instance_ufw_file"; then
    echo "${0##*/} ERROR: Failed to move $temp_ufw_file into $instance_ufw_file" >&2 && return 1
  fi

  # UFW expect the rule file to belong to root
  if ! $SUDO chown root:root "$instance_ufw_file"; then
    echo "${0##*/} ERROR: Failed to assign root user ownership to $instance_ufw_file" >&2 && return 1
  fi

  # Enable firewall rule
  if ! $SUDO ufw allow "$INSTANCE_FULL_NAME" &>/dev/null; then
    echo "${0##*/} ERROR: Failed to allow UFW rule for $INSTANCE_FULL_NAME" >&2 && return 1
  fi

  if grep -q "INSTANCE_UFW_FILE=" <"$instance_config_file"; then
    sed -i "/INSTANCE_UFW_FILE=*/c\INSTANCE_UFW_FILE=$instance_ufw_file" "$instance_config_file" >/dev/null
  else
    {
      echo ""
      echo "# Path the the UFW firewall rule file"
      echo "INSTANCE_UFW_FILE=$instance_ufw_file"
    } >>"$instance_config_file"
  fi

  return 0
}

function _create() {
  _create_manage_file || return 1
  _create_overrides_file || return 1

  if [[ "$INSTANCE_LIFECYCLE_MANAGER" == "systemd" ]]; then
    _systemd_install || return 1
  fi

  if [[ "$USE_UFW" -eq 1 ]]; then
    _ufw_install || return 1
  fi

  return 0
}

function _remove() {
  if [[ "$INSTANCE_LIFECYCLE_MANAGER" == "systemd" ]]; then
    _systemd_uninstall || return 1
  fi

  if [[ "$USE_UFW" -eq 1 ]]; then
    _ufw_uninstall || return 1
  fi

  return 0
}

#Read the argument values
while [ $# -gt 0 ]; do
  case "$1" in
  --create)
    shift
    [[ -z "$1" ]] && _create && exit $?
    case "$1" in
    --manage)
      _create_manage_file && exit $?
      ;;
    --override)
      _create_overrides_file && exit $?
      ;;
    --systemd)
      _systemd_install && exit $?
      ;;
    --ufw)
      _ufw_install && exit $?
      ;;
    *) echo "${0##*/} ERROR: Invalid argument $1" >&2 && exit 1 ;;
    esac
    ;;
  --remove)
    shift
    [[ -z "$1" ]] && _remove && exit $?
    case "$1" in
    --systemd)
      _systemd_uninstall && exit $?
      ;;
    --ufw)
      _ufw_uninstall && exit $?
      ;;
    *) echo "${0##*/} ERROR: Invalid argument $1" >&2 && exit 1 ;;
    esac
    ;;
  *) echo "${0##*/} ERROR: Invalid argument $1" >&2 && exit 1 ;;
  esac
  shift
done
