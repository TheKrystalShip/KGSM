#!/bin/bash

function usage() {
  echo "Creates a \$SERVICE_NAME.manage.sh file that's tasked with
starting, stopping and interacting with the service input socket.

The file will be generated from a generic template that can be found
in \$TEMPLATES_SOURCE_DIR, and created inside of \$SERVICE_WORKING_DIR

Usage:
    ./create_manage_file.sh <blueprint>

Options:
    blueprint     Name of the blueprint file.
                  The .bp extension in the name is optional

    -h --help     Prints this message

Examples:
    ./create_manage_file.sh valheim

    ./create_manage_file.sh terraria
"
}

if [ $# -eq 0 ] || [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  usage && exit 1
fi

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

BLUEPRINT=$1

COMMON_SCRIPT="$(find "$KGSM_ROOT" -type f -name common.sh)"
BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"
MANAGE_TEMPLATE_FILE="$(find "$KGSM_ROOT" -type f -name manage.tp)"

# shellcheck disable=SC1090
source "$COMMON_SCRIPT" || exit 1

# shellcheck disable=SC1090
source "$BLUEPRINT_SCRIPT" "$BLUEPRINT" || exit 1

# MANAGE_TEMPLATE_FILE expects a $WORKING_DIR var
# shellcheck disable=SC2034
WORKING_DIR="$SERVICE_WORKING_DIR"

# Prepend "./" to $SERVICE_LAUNCH_BIN if it doesn't start with "./" or "/"
if [[ "$SERVICE_LAUNCH_BIN" != \.\/* ]] && [[ "$SERVICE_LAUNCH_BIN" != \/* ]]; then
  SERVICE_LAUNCH_BIN="./$SERVICE_LAUNCH_BIN"
fi

# Create manage.sh from template and put it in $SERVICE_MANAGE_SCRIPT_FILE
if ! eval "cat <<EOF
$(<"$MANAGE_TEMPLATE_FILE")
EOF
" >"$SERVICE_MANAGE_SCRIPT_FILE" 2>/dev/null; then
  echo ">>> ${0##*/} ERROR: Could not copy $MANAGE_TEMPLATE_FILE to $SERVICE_MANAGE_SCRIPT_FILE" >&2
  exit 1
fi

if ! chmod +x "$SERVICE_MANAGE_SCRIPT_FILE"; then
  echo ">>> ${0##*/} ERROR: Failed to add +x permission to $SERVICE_MANAGE_SCRIPT_FILE" >&2
  exit 2
fi
