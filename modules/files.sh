#!/bin/bash

function usage() {
  echo "Manages the various necessary files to run a game server.
Generates the necessary systemd *.service and *.socket files,
also creates the UFW firewall rule on install.
Removes everything on uninstall

Usage:
    Must be called with root privilages
    sudo ./${0##*/} [-b | --blueprint] <blueprint> <option>

Options:
    -b --blueprint <bp>   Name of the blueprint file.
                          The .bp extension in the name is optional

    -h --help             Prints this message

    --install             Creates and enables systemd service/socket files and
                          UFW firewall rule

    --uninstall           Removes and disables systemd service/socket files and
                          UFW firewall rule

Examples:
    ./${0##*/} -b valheim --install

    ./${0##*/} --blueprint terraria --uninstall
"
}

if [ "$#" -eq 0 ]; then usage && return 1; fi

if [ "$EUID" -ne 0 ]; then
  echo "${0##*/} Please run as root" >&2
  exit 1
fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
  -h | --help)
    usage && exit 0
    ;;
  -b | --blueprint)
    shift
    BLUEPRINT=$1
    shift
    ;;
  *)
    break
    ;;
  esac
done

# Check for KGSM_ROOT env variable
if [ -z "$KGSM_ROOT" ]; then
  echo "${0##*/} WARNING: KGSM_ROOT not found, sourcing /etc/environment." >&2
  # shellcheck disable=SC1091
  source /etc/environment

  # If not found in /etc/environment
  if [ -z "$KGSM_ROOT" ]; then
    echo ">>> ${0##*/} ERROR: KGSM_ROOT not found, exiting." >&2
    return 1
  else
    echo "${0##*/} INFO: KGSM_ROOT found in /etc/environment, consider rebooting the system" >&2

    # Check if KGSM_ROOT is exported
    if ! declare -p KGSM_ROOT | grep -q 'declare -x'; then
      export KGSM_ROOT
    fi
  fi
fi

# Trap CTRL-C
trap "echo "" && exit" INT

COMMON_SCRIPT="$(find "$KGSM_ROOT" -type f -name common.sh)"
BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"
MANAGE_TEMPLATE_FILE="$(find "$KGSM_ROOT" -type f -name manage.tp)"
OVERRIDES_FILE="$(find "$KGSM_ROOT" -type f -name "$SERVICE_NAME".bp.overrides.sh)"

# shellcheck disable=SC1090
source "$COMMON_SCRIPT" || return 1

# shellcheck disable=SC1090
source "$BLUEPRINT_SCRIPT" "$BLUEPRINT" || return 1

function __create_manage_file() {
  # MANAGE_TEMPLATE_FILE expects a $WORKING_DIR var
  # shellcheck disable=SC2034
  WORKING_DIR="$SERVICE_WORKING_DIR"

  # Prepend "./" to $SERVICE_LAUNCH_BIN if it doesn't start with "./" or "/"
  if [[ "$SERVICE_LAUNCH_BIN" != ./* && "$SERVICE_LAUNCH_BIN" != /* ]]; then
    SERVICE_LAUNCH_BIN="./$SERVICE_LAUNCH_BIN"
  fi

  # Create manage.sh from template and put it in $SERVICE_MANAGE_SCRIPT_FILE
  if ! eval "cat <<EOF
$(<"$MANAGE_TEMPLATE_FILE")
EOF
" >"$SERVICE_MANAGE_SCRIPT_FILE" 2>/dev/null; then
    echo ">>> ${0##*/} ERROR: Could not copy $MANAGE_TEMPLATE_FILE to $SERVICE_MANAGE_SCRIPT_FILE" >&2
    return 1
  fi

  # Make sure file is owned by the user and not root
  if ! chown "$SUDO_USER":"$SUDO_USER" "$SERVICE_MANAGE_SCRIPT_FILE"; then
    echo ">>> ${0##*/} ERROR: Failed to assing $SERVICE_MANAGE_SCRIPT_FILE to $SUDO_USER" >&2ç
    return 1
  fi

  if ! chmod +x "$SERVICE_MANAGE_SCRIPT_FILE"; then
    echo ">>> ${0##*/} ERROR: Failed to add +x permission to $SERVICE_MANAGE_SCRIPT_FILE" >&2
    return 1
  fi

  return 0
}

function __create_overrides_file() {
  # If overrides file exists, copy it
  if [ -f "$OVERRIDES_FILE" ]; then
    # Make copy
    if ! cp -f "$OVERRIDES_FILE" "$SERVICE_OVERRIDES_SCRIPT_FILE"; then
      echo ">>> ${0##*/} ERROR: Could not copy $OVERRIDES_FILE to $SERVICE_OVERRIDES_SCRIPT_FILE" >&2
      return 1
    fi

    # Make sure file is owned by the user and not root
    if ! chown "$SUDO_USER":"$SUDO_USER" "$SERVICE_OVERRIDES_SCRIPT_FILE"; then
      echo ">>> ${0##*/} ERROR: Failed to assing $SERVICE_OVERRIDES_SCRIPT_FILE to $SUDO_USER" >&2ç
      return 1
    fi

    if ! chmod +x "$SERVICE_OVERRIDES_SCRIPT_FILE"; then
      echo ">>> ${0##*/} ERROR: Failed to add +x permission to $SERVICE_OVERRIDES_SCRIPT_FILE" >&2
      return 1
    fi
  fi

  return 0
}

function __systemd_uninstall() {
  # Remove service file
  if [ -f "$SERVICE_SYSTEMD_SERVICE_FILE" ]; then
    if ! rm "$SERVICE_SYSTEMD_SERVICE_FILE"; then
      echo ">>> ${0##*/} ERROR: Failed to remove $SERVICE_SYSTEMD_SERVICE_FILE" >&2
      return 1
    fi
  fi

  # Remove socket file
  if [ -f "$SERVICE_SYSTEMD_SOCKET_FILE" ]; then
    if ! rm "$SERVICE_SYSTEMD_SOCKET_FILE"; then
      echo ">>> ${0##*/} ERROR: Failed to remove $SERVICE_SYSTEMD_SOCKET_FILE" >&2
      return 1
    fi
  fi

  # Reload systemd
  if ! systemctl daemon-reload; then
    echo ">>> ${0##*/} ERROR: Failed to reload systemd" >&2
    return 1
  fi

  return 0
}

function __systemd_install() {
  # shellcheck disable=SC2155
  local service_template_file="$(find "$KGSM_ROOT" -type f -name service.tp)"

  if [ -z "$service_template_file" ]; then
    echo ">>> ${0##*/} ERROR: Failed to locate service.tp template" >&2
    return 1
  fi

  # shellcheck disable=SC2155
  local socket_template_file="$(find "$KGSM_ROOT" -type f -name socket.tp)"

  if [ -z "$socket_template_file" ]; then
    echo ">>> ${0##*/} ERROR: Failed to locate socket.tp template" >&2
    return 1
  fi

  # If either files already exist, uninstall first
  if [ -f "$SERVICE_SYSTEMD_SERVICE_FILE" ] || [ -f "$SERVICE_SYSTEMD_SOCKET_FILE" ]; then
    if ! _uninstall; then return 1; fi
  fi

  # Create the service file
  if ! eval "cat <<EOF
$(<"$service_template_file")
EOF
" >"$SERVICE_SYSTEMD_SERVICE_FILE" 2>/dev/null; then
    echo ">>> ${0##*/} ERROR: Could not copy $service_template_file to $SERVICE_SYSTEMD_SERVICE_FILE" >&2
    return 1
  fi

  # Create the socket file
  if ! eval "cat <<EOF
$(<"$socket_template_file")
EOF
" >"$SERVICE_SYSTEMD_SOCKET_FILE" 2>/dev/null; then
    echo ">>> ${0##*/} ERROR: Could not copy $socket_template_file to $SERVICE_SYSTEMD_SOCKET_FILE" >&2
    return 1
  fi

  # Reload systemd
  if ! systemctl daemon-reload; then
    echo ">>> ${0##*/} ERROR: Failed to reload systemd" >&2
    return 1
  fi

  return 0
}

function __ufw_uninstall() {
  # Remove ufw rule
  if ! ufw delete allow "$SERVICE_NAME" &>>/dev/null; then
    echo ">>> ${0##*/} ERROR: Failed to remove UFW rule for $SERVICE_NAME" >&2
    return 1
  fi

  if [ -f "$SERVICE_UFW_FIREWALL_FILE" ]; then
    # Delete firewall rule file
    if ! rm "$SERVICE_UFW_FIREWALL_FILE"; then
      echo ">>> ${0##*/} ERROR: Failed to remove $SERVICE_UFW_FIREWALL_FILE" >&2
      return 1
    fi
  fi

  return 0
}

function __ufw_install() {
  # If firewall rule file already exists, remove it
  if [ -f "$SERVICE_UFW_FIREWALL_FILE" ]; then
    # echo "${0##*/} WARNING: UFW rule for $SERVICE_NAME already exists, removing" >&2
    if ! __ufw_uninstall; then return 1; fi
  fi

  # shellcheck disable=SC2155
  local ufw_template_file="$(find "$KGSM_ROOT" -type f -name ufw.tp)"

  if [ -z "$ufw_template_file" ]; then
    echo ">>> ${0##*/} ERROR: Could not load ufw.tp template" >&2
    return 1
  fi

  # Create file
  if ! touch "$SERVICE_UFW_FIREWALL_FILE"; then
    echo ">>> ${0##*/} ERROR: Failed to create file $SERVICE_UFW_FIREWALL_FILE" >&2
    return 1
  fi

  # Create firewall rule file from template
  if ! eval "cat <<EOF
$(<"$ufw_template_file")
EOF
" >"$SERVICE_UFW_FIREWALL_FILE"; then
    echo ">>> ${0##*/} ERROR: Failed writing rules to $SERVICE_UFW_FIREWALL_FILE" >&2
    return 1
  fi

  # Enable firewall rule
  if ! ufw allow "$SERVICE_NAME" &>>/dev/null; then
    echo ">>> ${0##*/} ERROR: Failed to allow UFW rule for $SERVICE_NAME" >&2
    return 1
  fi

  return 0
}

function _install() {
  local ret=0
  __create_manage_file || ret=$?
  __create_overrides_file || ret=$?
  __systemd_install || ret=$?

  if command -v ufw &>/dev/null; then
    __ufw_install || ret=$?
  fi

  return "$ret"
}

function _uninstall() {
  local ret=0
  __systemd_uninstall || ret=$?

  if command -v ufw &>/dev/null; then
    __ufw_uninstall || ret=$?
  fi

  return "$ret"
}

#Read the argument values
while [ $# -gt 0 ]; do
  case "$1" in
  --install)
    _install && exit $?
    shift
    ;;
  --uninstall)
    _uninstall && exit $?
    shift
    ;;
  *)
    echo ">>> ${0##*/} Error: Invalid argument $1" >&2
    usage && exit 1
    ;;
  esac
  shift
done
