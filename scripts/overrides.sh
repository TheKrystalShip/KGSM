#!/bin/bash

# Params
if [ $# -eq 0 ]; then
  echo "ERROR: Service name not supplied"
  exit 2
fi

SERVICE=$1

# shellcheck disable=SC1091
source /opt/scripts/service_vars.sh "$SERVICE"

# Import custom scripts if the game has any
if [ "$IS_STEAM_GAME" == "0" ]; then
  if ! test -f "$SERVICE_OVERRIDES_SCRIPT_FILE"; then
    echo ">>> ERROR: Could not locate overrides.sh file for $SERVICE_NAME, exiting"
    exit 1
  fi

  # shellcheck disable=SC1090
  source "$SERVICE_OVERRIDES_SCRIPT_FILE"
fi
