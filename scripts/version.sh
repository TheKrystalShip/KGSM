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

# shellcheck disable=SC1091
source /etc/environment

# CRITICAL: This imports all the required vars
# $SERVICE is given as an argument to the script
# shellcheck source=/dev/null
source /opt/scripts/includes/service_vars.sh "$SERVICE"

# $SERVICE_STEAM_AUTH_LEVEL comes from service_vars.sh
# shellcheck disable=SC1091
source /opt/scripts/includes/steamcmd.sh "$SERVICE_STEAM_AUTH_LEVEL"

function func_get_latest_version() {
  steamcmd_get_latest_version "$SERVICE_APP_ID"
}

# shellcheck disable=SC1091
source /opt/scripts/includes/overrides.sh "$SERVICE"

func_get_latest_version

# Check if not empty
if [ -n "$latest_version" ]; then
  echo "$latest_version" | tr -d '\n'
else
  exit "$EXITSTATUS_ERROR"
fi
