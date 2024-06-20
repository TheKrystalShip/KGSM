#!/bin/bash

function usage() {
  echo "Creates a new blueprint. It will prompt the user to input
the required fields one by one until the blueprint is finished, at
which point it can be found in \$BLUEPRINTS_SOURCE_DIR under the
same name the user input when prompted.

Usage:
    ./${0##*/} [option]

Options:
    -h --help     Prints this message

Examples:
    ./${0##*/}
"
}

while [ $# -gt 0 ]; do
  case "$1" in
  -h | --help)
    usage && exit 0
    shift
    ;;
  *)
    echo ">>> ${0##*/} Error: Invalid argument $1" >&2
    usage && exit 1
    ;;
  esac
  shift
done

# Check for KGSM_ROOT env variable
if [ -z "$KGSM_ROOT" ]; then
  echo "${0##*/} WARNING: KGSM_ROOT environmental variable not found, sourcing /etc/environment." >&2
  # shellcheck disable=SC1091
  source /etc/environment

  # If not found in /etc/environment
  if [ -z "$KGSM_ROOT" ]; then
    echo ">>> ${0##*/} ERROR: KGSM_ROOT environmental variable not found, exiting." >&2
    exit 1
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
TEMPLATE_INPUT_FILE="$(find "$KGSM_ROOT" -type f -name blueprint.tp)"

# shellcheck disable=SC1090
source "$COMMON_SCRIPT" || exit 1

_name=""
read -rp "Name: " _name

_port=""
read -rp "Port: " _port

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

_stop_command=""
read -rp "(Optional) Socket stop command: " _stop_command

_save_command=""
read -rp "(Optional) Socket save command: " _save_command

# Output file path
BLUEPRINT_OUTPUT_FILE="$BLUEPRINTS_SOURCE_DIR/$_name.bp"

# Create blueprint from template file
if ! eval "cat <<EOF
$(<"$TEMPLATE_INPUT_FILE")
EOF
" >"$BLUEPRINT_OUTPUT_FILE" 2>/dev/null; then
  echo ">>> ${0##*/} ERROR: Failed to create $BLUEPRINT_OUTPUT_FILE" >&2
fi
