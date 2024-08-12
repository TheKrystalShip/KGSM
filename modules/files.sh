#!/bin/bash

function usage() {
  echo "Manages the various necessary files to run a game server.
Generates the necessary systemd *.service and *.socket files,
also creates the UFW firewall rule on install.
Removes everything on uninstall

Usage:
  Must be called with root privilages
  sudo ./${0##*/} [-i | --instance] <instance> OPTION

Options:
  -i, --instance <instance>   Full name of the instance, equivalent of
                              INSTANCE_FULL_NAME from the instance config file
                              The .ini extension is not required

  -h, --help                 Prints this message

  --install                  Generates all files:
                             [instance].manage.sh file, [instance].override.sh file
                             if applicable, systemd service/ socket files and ufw
                             firewall rules if applicable.

    --manage                 Creates the [instance].manage.sh file
    --override               Creates the [instance].overrides.sh file if applicable
    --systemd                Installs the systemd service/socket files
    --ufw                    Installs the ufw firewall rule file

  --uninstall                Removes and disables systemd service/socket files and
                             UFW firewall rule

    --systemd                Removes the systemd service and socket files
    --ufw                    Removes the ufw firewall rule files

Examples:
  ./${0##*/} -i factorio-L2ZeLQ.ini --install

  ./${0##*/} -i 7dtd-fqcLvt --uninstall --ufw
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

if [ "$EUID" -ne 0 ]; then
  echo "${0##*/} Please run as root" >&2 && exit 1
fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
  -h | --help)
    usage && exit 0
    ;;
  -i | --instance)
    shift
    [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument <instance>" >&2 && exit 1
    INSTANCE=$1
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

COMMON_SCRIPT=$(find "$KGSM_ROOT" -type f -name common.sh)
[[ -z "$COMMON_SCRIPT" ]] && echo "${0##*/} ERROR: Could not find module common.sh" >&2 && exit 1

# shellcheck disable=SC1090
source "$COMMON_SCRIPT" || exit 1

[[ $INSTANCE != *.ini ]] && INSTANCE="${INSTANCE}.ini"

INSTANCE_CONFIG_FILE=$(find "$KGSM_ROOT" -type f -name "$INSTANCE")
[[ -z "$INSTANCE_CONFIG_FILE" ]] && echo "${0##*/} ERROR: Could not find instance $INSTANCE" >&2 && exit 1

# shellcheck disable=SC1090
source "$INSTANCE_CONFIG_FILE" || exit 1

function __create_manage_file() {
  # shellcheck disable=SC2155
  local manage_template_file="$(find "$TEMPLATES_SOURCE_DIR" -type f -name manage.tp)"
  [[ -z "$manage_template_file" ]] && echo "${0##*/} ERROR: Failed to load manage.tp" >&2 && return 1

  local instance_manage_file="${INSTANCE_WORKING_DIR}/${INSTANCE_FULL_NAME}.manage.sh"
  export INSTANCE_SOCKET_FILE="${INSTANCE_WORKING_DIR}/.${INSTANCE_FULL_NAME}.stdin"

  # shellcheck disable=SC2155
  local instance_install_subdir=$(grep "SERVICE_INSTALL_SUBDIRECTORY=" <"$INSTANCE_BLUEPRINT_FILE" | cut -d "=" -f2 | tr -d '"')

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

  if [[ "$INSTANCE_LIFECYCLE_MANAGER" == "systemd" ]]; then
    INSTANCE_LOGS_REDIRECT=""
  else
    # shellcheck disable=SC2140
    stdout_file="$INSTANCE_LOGS_DIR/$INSTANCE_FULL_NAME-\"\$(date +"%Y-%m-%dT%H:%M:%S")\".log"

    export INSTANCE_LOGS_REDIRECT="1>$stdout_file 2>&1"

    if grep -q "INSTANCE_PID_FILE=" <"$INSTANCE_CONFIG_FILE"; then
      sed -i "/INSTANCE_PID_FILE=*/c\INSTANCE_PID_FILE=$INSTANCE_PID_FILE" "$INSTANCE_CONFIG_FILE" >/dev/null
    else
      {
        echo ""
        echo "# File where the instance process ID will be stored while the instance is running"
        echo "INSTANCE_PID_FILE=$INSTANCE_PID_FILE"
      } >>"$INSTANCE_CONFIG_FILE"
    fi
  fi

  # Create manage.sh from template and put it in $instance_manage_file
  if ! eval "cat <<EOF
$(<"$manage_template_file")
EOF
" >"$instance_manage_file" 2>/dev/null; then
    echo "${0##*/} ERROR: Could not generate template for $instance_manage_file" >&2 && return 1
  fi

  SERVICE_USER=$USER
  if [ "$EUID" -eq 0 ]; then
    SERVICE_USER=$SUDO_USER
  fi

  # Make sure file is owned by the user and not root
  if ! chown "$SERVICE_USER":"$SERVICE_USER" "$instance_manage_file"; then
    echo "${0##*/} ERROR: Failed to assing $instance_manage_file to $SERVICE_USER" >&2 && return 1
  fi

  if ! chmod +x "$instance_manage_file"; then
    echo "${0##*/} ERROR: Failed to add +x permission to $instance_manage_file" >&2 && return 1
  fi

  if grep -q "INSTANCE_MANAGE_FILE=" <"$INSTANCE_CONFIG_FILE"; then
    sed -i "/INSTANCE_MANAGE_FILE=*/c\INSTANCE_MANAGE_FILE=$instance_manage_file" "$INSTANCE_CONFIG_FILE" >/dev/null
  else
    {
      echo ""
      echo "# Path to the [instance].manage.sh script file"
      echo "INSTANCE_MANAGE_FILE=$instance_manage_file"
    } >>"$INSTANCE_CONFIG_FILE"
  fi

  return 0
}

function __create_overrides_file() {
  # shellcheck disable=SC2155
  local overrides_file="$(find "$OVERRIDES_SOURCE_DIR" -type f -name "$INSTANCE_NAME".overrides.sh)"
  [[ ! -f "$overrides_file" ]] && return 0

  local instance_overrides_file=${INSTANCE_WORKING_DIR}/${INSTANCE_FULL_NAME}.overrides.sh

  # Make copy
  if ! cp -f "$overrides_file" "$instance_overrides_file"; then
    echo "${0##*/} ERROR: Could not copy $overrides_file to $instance_overrides_file" >&2 && return 1
  fi

  SERVICE_USER=$USER
  if [ "$EUID" -eq 0 ]; then
    SERVICE_USER=$SUDO_USER
  fi

  # Make sure file is owned by the user and not root
  if ! chown "$SERVICE_USER":"$SERVICE_USER" "$instance_overrides_file"; then
    echo "${0##*/} ERROR: Failed to assing $instance_overrides_file to $SERVICE_USER" >&2 && return 1
  fi

  # if ! chmod +x "$instance_overrides_file"; then
  #   echo "${0##*/} ERROR: Failed to add +x permission to $instance_overrides_file" >&2 && return 1
  # fi

  if grep -q "INSTANCE_OVERRIDES_FILE=" <"$INSTANCE_CONFIG_FILE"; then
    sed -i "/INSTANCE_OVERRIDES_FILE=*/c\INSTANCE_OVERRIDES_FILE=$instance_overrides_file" "$INSTANCE_CONFIG_FILE" >/dev/null
  else
    {
      echo ""
      echo "# Path to the [instance].overrides.sh script file"
      echo "INSTANCE_OVERRIDES_FILE=$instance_overrides_file"
    } >>"$INSTANCE_CONFIG_FILE"
  fi

  return 0
}

function __systemd_uninstall() {
  [[ -z "$INSTANCE_SYSTEMD_SERVICE_FILE" ]] && echo "${0##*/} ERROR: $INSTANCE_FULL_NAME doesn't have a systemd service file set" >&2 && return 1
  [[ -z "$INSTANCE_SYSTEMD_SOCKET_FILE" ]] && echo "${0##*/} ERROR: $INSTANCE_FULL_NAME doesn't have a systemd socket file set" >&2 && return 1

  if systemctl is-active "$INSTANCE_FULL_NAME" &>/dev/null; then
    if ! systemctl stop "$INSTANCE_FULL_NAME" &>/dev/null; then
      echo "${0##*/} ERROR: Failed to stop $INSTANCE_FULL_NAME before uninstalling systemd files" >&2 && return 1
    fi
  fi

  if systemctl is-enabled "$INSTANCE_FULL_NAME" &>/dev/null; then
    if ! systemctl disable "$INSTANCE_FULL_NAME"; then
      echo "WARNING: Failed to disable $INSTANCE_FULL_NAME" >&2
    fi
  fi

  # Remove service file
  # shellcheck disable=SC2153
  if [ -f "$INSTANCE_SYSTEMD_SERVICE_FILE" ]; then
    if ! rm "$INSTANCE_SYSTEMD_SERVICE_FILE"; then
      echo "${0##*/} ERROR: Failed to remove $INSTANCE_SYSTEMD_SERVICE_FILE" >&2 && return 1
    fi
  fi

  # Remove socket file
  # shellcheck disable=SC2153
  if [ -f "$INSTANCE_SYSTEMD_SOCKET_FILE" ]; then
    if ! rm "$INSTANCE_SYSTEMD_SOCKET_FILE"; then
      echo "${0##*/} ERROR: Failed to remove $INSTANCE_SYSTEMD_SOCKET_FILE" >&2 && return 1
    fi
  fi

  # Reload systemd
  if ! systemctl daemon-reload; then
    echo "${0##*/} ERROR: Failed to reload systemd" >&2 && return 1
  fi

  return 0
}

function __systemd_install() {
  [[ -z "$SYSTEMD_DIR" ]] && echo "${0##*/} ERROR: SYSTEMD_DIR is expected but it's not set" >&2 && return 1

  # shellcheck disable=SC2155
  local service_template_file="$(find "$TEMPLATES_SOURCE_DIR" -type f -name service.tp)"
  [[ -z "$service_template_file" ]] && echo "${0##*/} ERROR: Failed to locate service.tp template" >&2 && return 1

  # shellcheck disable=SC2155
  local socket_template_file="$(find "$TEMPLATES_SOURCE_DIR" -type f -name socket.tp)"
  [[ -z "$socket_template_file" ]] && echo "${0##*/} ERROR: Failed to locate socket.tp template" >&2 && return 1

  local instance_systemd_service_file=${SYSTEMD_DIR}/${INSTANCE_FULL_NAME}.service
  local instance_systemd_socket_file=${SYSTEMD_DIR}/${INSTANCE_FULL_NAME}.socket

  # Required by template
  # shellcheck disable=SC2155
  export INSTANCE_MANAGE_FILE=$(grep "INSTANCE_MANAGE_FILE=" <"$INSTANCE_CONFIG_FILE" | cut -d "=" -f2 | tr -d '"')
  export INSTANCE_SOCKET_FILE=${INSTANCE_WORKING_DIR}/${INSTANCE_FULL_NAME}.stdin

  # If either files already exist, uninstall first
  if [ -f "$instance_systemd_service_file" ] || [ -f "$instance_systemd_socket_file" ]; then
    if ! _uninstall; then return 1; fi
  fi

  SERVICE_USER=$USER
  if [ "$EUID" -eq 0 ]; then
    SERVICE_USER=$SUDO_USER
  fi

  # Create the service file
  if ! eval "cat <<EOF
$(<"$service_template_file")
EOF
" >"$instance_systemd_service_file" 2>/dev/null; then
    echo "${0##*/} ERROR: Could not copy $service_template_file to $instance_systemd_service_file" >&2 && return 1
  fi

  # Create the socket file
  if ! eval "cat <<EOF
$(<"$socket_template_file")
EOF
" >"$instance_systemd_socket_file" 2>/dev/null; then
    echo "${0##*/} ERROR: Could not copy $socket_template_file to $instance_systemd_socket_file" >&2 && return 1
  fi

  # Reload systemd
  if ! systemctl daemon-reload; then
    echo "${0##*/} ERROR: Failed to reload systemd" >&2 && return 1
  fi

  if grep -q "INSTANCE_SOCKET_FILE=" <"$INSTANCE_CONFIG_FILE"; then
    sed -i "/INSTANCE_SOCKET_FILE=*/c\INSTANCE_SOCKET_FILE=$INSTANCE_SOCKET_FILE" "$INSTANCE_CONFIG_FILE" >/dev/null
  else
    {
      echo ""
      echo "# Path to the Unix Domain Socket"
      echo "INSTANCE_SOCKET_FILE=$INSTANCE_SOCKET_FILE"
    } >>"$INSTANCE_CONFIG_FILE"
  fi

  if grep -q "INSTANCE_SYSTEMD_SERVICE_FILE=" <"$INSTANCE_CONFIG_FILE"; then
    sed -i "/INSTANCE_SYSTEMD_SERVICE_FILE=*/c\INSTANCE_SYSTEMD_SERVICE_FILE=$instance_systemd_service_file" "$INSTANCE_CONFIG_FILE" >/dev/null
  else
    {
      echo ""
      echo "# Path to the systemd [instance].service file"
      echo "INSTANCE_SYSTEMD_SERVICE_FILE=$instance_systemd_service_file"
    } >>"$INSTANCE_CONFIG_FILE"
  fi

  if grep -q "INSTANCE_SYSTEMD_SOCKET_FILE=" <"$INSTANCE_CONFIG_FILE"; then
    sed -i "/INSTANCE_SYSTEMD_SOCKET_FILE=*/c\INSTANCE_SYSTEMD_SOCKET_FILE=$instance_systemd_socket_file" "$INSTANCE_CONFIG_FILE" >/dev/null
  else
    {
      echo ""
      echo "# Path to the systemd [instance].socket file"
      echo "INSTANCE_SYSTEMD_SOCKET_FILE=$instance_systemd_socket_file"
    } >>"$INSTANCE_CONFIG_FILE"
  fi

  return 0
}

function __ufw_uninstall() {
  [[ -z "$UFW_RULES_DIR" ]] && echo "${0##*/} ERROR: UFW_RULES_DIR is expected but it's not set" >&2 && return 1
  [[ -z "$INSTANCE_UFW_FILE" ]] && return 0
  [[ ! -f "$INSTANCE_UFW_FILE" ]] && return 0

  # Remove ufw rule
  if ! ufw delete allow "$INSTANCE_FULL_NAME" &>/dev/null; then
    echo "${0##*/} ERROR: Failed to remove UFW rule for $INSTANCE_FULL_NAME" >&2 && return 1
  fi

  if [ -f "$INSTANCE_UFW_FILE" ]; then
    # Delete firewall rule file
    if ! rm "$INSTANCE_UFW_FILE"; then
      echo "${0##*/} ERROR: Failed to remove $INSTANCE_UFW_FILE" >&2 && return 1
    fi
  fi

  return 0
}

function __ufw_install() {
  [[ -z "$UFW_RULES_DIR" ]] && echo "${0##*/} ERROR: UFW_RULES_DIR is expected but it's not set" >&2 && return 1

  local instance_ufw_file=${UFW_RULES_DIR}/kgsm-${INSTANCE_FULL_NAME}

  # If firewall rule file already exists, remove it
  if [ -f "$instance_ufw_file" ]; then
    if ! __ufw_uninstall; then return 1; fi
  fi

  # shellcheck disable=SC2155
  local ufw_template_file="$(find "$TEMPLATES_SOURCE_DIR" -type f -name ufw.tp)"
  [[ -z "$ufw_template_file" ]] && echo "${0##*/} ERROR: Could not load ufw.tp template" >&2 && return 1

  # Create file
  if ! touch "$instance_ufw_file"; then
    echo "${0##*/} ERROR: Failed to create file $instance_ufw_file" >&2 && return 1
  fi

  # Create firewall rule file from template
  if ! eval "cat <<EOF
$(<"$ufw_template_file")
EOF
" >"$instance_ufw_file"; then
    echo "${0##*/} ERROR: Failed writing rules to $instance_ufw_file" >&2 && return 1
  fi

  # Enable firewall rule
  if ! ufw allow "$INSTANCE_FULL_NAME" &>/dev/null; then
    echo "${0##*/} ERROR: Failed to allow UFW rule for $INSTANCE_FULL_NAME" >&2 && return 1
  fi

  if grep -q "INSTANCE_UFW_FILE=" <"$INSTANCE_CONFIG_FILE"; then
    sed -i "/INSTANCE_UFW_FILE=*/c\INSTANCE_UFW_FILE=$instance_ufw_file" "$INSTANCE_CONFIG_FILE" >/dev/null
  else
    {
      echo ""
      echo "# Path the the UFW firewall rule file"
      echo "INSTANCE_UFW_FILE=$instance_ufw_file"
    } >>"$INSTANCE_CONFIG_FILE"
  fi

  return 0
}

function _install() {
  __create_manage_file || return 1
  __create_overrides_file || return 1

  if [[ "$INSTANCE_LIFECYCLE_MANAGER" == "systemd" ]]; then
    __systemd_install || return 1
  fi

  if [[ "$USE_UFW" -eq 1 ]]; then
    __ufw_install || return 1
  fi

  return 0
}

function _uninstall() {
  if [[ "$INSTANCE_LIFECYCLE_MANAGER" == "systemd" ]]; then
    __systemd_uninstall || return 1
  fi

  if [[ "$USE_UFW" -eq 1 ]]; then
    __ufw_uninstall || return 1
  fi

  return 0
}

#Read the argument values
while [ $# -gt 0 ]; do
  case "$1" in
  --install)
    shift
    [[ -z "$1" ]] && _install && exit $?
    case "$1" in
    --manage)
      __create_manage_file && exit $?
      ;;
    --override)
      __create_overrides_file && exit $?
      ;;
    --systemd)
      __systemd_install && exit $?
      ;;
    --ufw)
      __ufw_install && exit $?
      ;;
    *) echo "${0##*/} ERROR: Invalid argument $1" >&2 && exit 1 ;;
    esac
    ;;
  --uninstall)
    shift
    [[ -z "$1" ]] && _uninstall && exit $?
    case "$1" in
    --systemd)
      __systemd_uninstall && exit $?
      ;;
    --ufw)
      __ufw_uninstall && exit $?
      ;;
    *) echo "${0##*/} ERROR: Invalid argument $1" >&2 && exit 1 ;;
    esac
    ;;
  *) echo "${0##*/} ERROR: Invalid argument $1" >&2 && exit 1 ;;
  esac
  shift
done
