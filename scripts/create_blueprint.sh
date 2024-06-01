#!/bin/bash

# Check for KGSM_ROOT env variable
if [ -z "$KGSM_ROOT" ]; then
  echo "WARNING: KGSM_ROOT environmental variable not found, sourcing /etc/environment." >&2
  # shellcheck disable=SC1091
  source /etc/environment

  # If not found in /etc/environment
  if [ -z "$KGSM_ROOT" ]; then
    echo ">>> ERROR: KGSM_ROOT environmental variable not found, exiting." >&2
    exit 1
  else
    echo "INFO: KGSM_ROOT found in /etc/environment, consider rebooting the system" >&2

    # Check if KGSM_ROOT is exported
    if ! declare -p KGSM_ROOT | grep -q 'declare -x'; then
      export KGSM_ROOT
    fi
  fi
fi

COMMON_SCRIPT="$(find "$KGSM_ROOT" -type f -name common.sh)"
TEMPLATE_INPUT_FILE="$(find "$KGSM_ROOT" -type f -name blueprint.tp)"

# shellcheck disable=SC1090
source "$COMMON_SCRIPT" || exit 1

_name=""
read -rp "Name: " _name

_port=""
read -rp "Port: " _port

_working_dir=""
read -rp "Install directory: " _working_dir
_working_dir+="/$_name"

_app_id=""
read -rp "Steam APP_ID (0 for none): " _app_id

_steam_auth_level="0"
if [ "$_app_id" != "0" ]; then
  read -rp "Steam Auth Level (0 for anonymous, 1 for account required): " _steam_auth_level
fi

_launch_bin=""
read -rp "Executable name: " _launch_bin

_install_subdirectory=""
read -rp "(Optional) Executable subdirectory: " _install_subdirectory

_launch_args=""
read -rp "(Optional) Launch args: " _launch_args

_uses_input_socket="0"
read -rp "Command input socket (0|1): " _uses_input_socket

_socket_stop_command=""
read -rp "(Optional) Socket stop command: " _socket_stop_command

_socket_save_command=""
read -rp "(Optional) Socket save command: " _socket_save_command

# Output file path
BLUEPRINT_OUTPUT_FILE="$BLUEPRINTS_SOURCE_DIR/$_name.bp"

# Create blueprint from template file
if ! eval "cat <<EOF
$(<"$TEMPLATE_INPUT_FILE")
EOF
" >"$BLUEPRINT_OUTPUT_FILE" 2>/dev/null; then
  echo ">>> ERROR: Failed to create $BLUEPRINT_OUTPUT_FILE" >&2
fi
