#!/bin/bash

# Params
if [ $# -eq 0 ]; then
  echo "ERROR: Service name not supplied" >&2
  exit 1
fi

# Check for KGSM_ROOT env variable
if [ -z "$KGSM_ROOT" ]; then
  echo "WARNING: KGSM_ROOT not found, sourcing /etc/environment." >&2
  # shellcheck disable=SC1091
  source /etc/environment

  # If not found in /etc/environment
  if [ -z "$KGSM_ROOT" ]; then
    echo "ERROR: KGSM_ROOT not found, exiting." >&2
    exit 1
  else
    echo "INFO: KGSM_ROOT found in /etc/environment, consider rebooting the system" >&2

    # Check if KGSM_ROOT is exported
    if ! declare -p KGSM_ROOT | grep -q 'declare -x'; then
      export KGSM_ROOT
    fi
  fi
fi

BLUEPRINT=$1

COMMON_SCRIPT="$(find "$KGSM_ROOT" -type f -name common.sh)"
BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"

# shellcheck disable=SC1090
source "$COMMON_SCRIPT" || exit 1

# shellcheck disable=SC1090
source "$BLUEPRINT_SCRIPT" "$BLUEPRINT" || exit 1

# Import custom scripts if the game has any
if [ -f "$SERVICE_OVERRIDES_SCRIPT_FILE" ]; then
  # shellcheck disable=SC1090
  source "$SERVICE_OVERRIDES_SCRIPT_FILE"
fi
