#!/bin/bash

function usage() {
  echo "Copies (if it exists) a \$SERVICE_NAME.overrides.sh file into
\$SERVICE_WORKING_DIR that will be used to override some functions when
called from different scripts.
More information about the specific functions
can be found under \$TEMPLATES_SOURCE_DIR/overrides.tp

Usage:
    ./create_override_file.sh <blueprint>

Options:
    blueprint     Name of the blueprint file.
                  The .bp extension in the name is optional

    -h --help     Prints this message

Examples:
    ./create_override_file.sh valheim

    ./create_override_file.sh terraria
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

BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"

# shellcheck disable=SC1090
source "$BLUEPRINT_SCRIPT" "$BLUEPRINT" || exit 1

OVERRIDES_FILE="$(find "$KGSM_ROOT" -type f -name "$SERVICE_NAME".overrides.sh)"

# If overrides file exists, copy it
if [ -f "$OVERRIDES_FILE" ]; then
  # Make copy
  if ! cp -f "$OVERRIDES_FILE" "$SERVICE_OVERRIDES_SCRIPT_FILE"; then
    echo ">>> ${0##*/} ERROR: Could not copy $OVERRIDES_FILE to $SERVICE_OVERRIDES_SCRIPT_FILE" >&2
    exit 1
  fi

  # Give +x permission
  if ! chmod +x "$SERVICE_OVERRIDES_SCRIPT_FILE"; then
    echo ">>> ${0##*/} ERROR: Failed to add +x permission to $SERVICE_OVERRIDES_SCRIPT_FILE" >&2
    exit 2
  fi
fi
