#!/bin/bash

################################################################################
# Script to check if a new version of a game has been released, comparing it
# to the currently running version on the server.
#
# INPUT: Service name
#
# OUTPUT:
# - Exit Code 0: New version found, written to STDOUT
# - Exit Code 1: No new version
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

# shellcheck disable=SC1091
source /opt/scripts/includes/service_vars.sh "$SERVICE"

# shellcheck disable=SC2155
latest_version=$(/opt/scripts/version.sh "$SERVICE")

if [ "$latest_version" == "$SERVICE_INSTALLED_VERSION" ]; then
  exit "$EXITSTATUS_ERROR"
fi

echo "$latest_version" | tr -d '\n'
