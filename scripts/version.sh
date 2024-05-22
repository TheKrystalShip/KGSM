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
  echo ">>> ERROR: Service name not supplied. Run script like this: ./${0##*/} \"SERVICE\""
  exit 1
fi

SERVICE=$1


COMMON_SCRIPT="$(find "$KGSM_ROOT" -type f -name common.sh)"
BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"
STEAMCMD_SCRIPT="$(find "$KGSM_ROOT" -type f -name steamcmd.sh)"
OVERRIDES_SCRIPT="$(find "$KGSM_ROOT" -type f -name overrides.sh)"

# shellcheck disable=SC1091
source /etc/environment

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
  exit "$EXITSTATUS_ERROR"
fi
