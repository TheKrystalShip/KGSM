#!/bin/bash

################################################################################
# Gets the latest available version of a game
#
# INPUT: Service name
#
# OUTPUT:
# - Exit Code 0: New version found, written to STDOUT
# - Exit Code 1: Error: Empty response was returned
# - Exit Code X: Other error, check output
################################################################################

# Params
if [ $# -eq 0 ]; then
  echo ">>> ERROR: Service name not supplied. Run script like this: ./${0##*/} \"SERVICE\"" >&2
  exit 1
fi

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

SERVICE=$1

COMMON_SCRIPT="$(find "$KGSM_ROOT" -type f -name common.sh)"
BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"
STEAMCMD_SCRIPT="$(find "$KGSM_ROOT" -type f -name steamcmd.sh)"
OVERRIDES_SCRIPT="$(find "$KGSM_ROOT" -type f -name overrides.sh)"

# shellcheck disable=SC1090
source "$COMMON_SCRIPT" || exit 1

# CRITICAL: This imports all the required vars
# $SERVICE is given as an argument to the script
# shellcheck source=/dev/null
source "$BLUEPRINT_SCRIPT" "$SERVICE" || exit 1

# $SERVICE_STEAM_AUTH_LEVEL comes from service_vars.sh
# shellcheck disable=SC1090
source "$STEAMCMD_SCRIPT" "$SERVICE_STEAM_AUTH_LEVEL" || exit 1

function func_get_latest_version() {
  steamcmd_get_latest_version "$SERVICE_APP_ID"
}

# shellcheck disable=SC1090
source "$OVERRIDES_SCRIPT" "$SERVICE" || exit 1

func_get_latest_version

# Check if not empty
if [ -n "$latest_version" ]; then
  echo "$latest_version" | tr -d '\n'
else
  exit 1
fi
