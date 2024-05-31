#!/bin/bash

if [ $# -eq 0 ]; then
  echo ">>> ERROR: BLUEPRINT name not supplied. Run script like this: ./${0##*/} \"BLUEPRINT\""
  exit 1
fi

BLUEPRINT=$1

if [[ "$BLUEPRINT" != *.bp ]]; then
  BLUEPRINT="${BLUEPRINT}.bp"
fi

PWD=$(pwd)
BLUEPRINT_FILE="$(find "$KGSM_ROOT" -type f -name "$BLUEPRINT")"

if [ ! -f "$BLUEPRINT_FILE" ]; then
  echo ">>> ERROR: Could not find $BLUEPRINT_FILE, exiting"
  exit 1
fi

# shellcheck disable=SC1090
source "$BLUEPRINT_FILE"

export SERVICE_BACKUPS_DIR="$SERVICE_WORKING_DIR/backups"
export SERVICE_CONFIG_DIR="$SERVICE_WORKING_DIR/config"
export SERVICE_INSTALL_DIR="$SERVICE_WORKING_DIR/install"
export SERVICE_SAVES_DIR="$SERVICE_WORKING_DIR/saves"
export SERVICE_SERVICE_DIR="$SERVICE_WORKING_DIR/service"
export SERVICE_TEMP_DIR="$SERVICE_WORKING_DIR/temp"

export SERVICE_OVERRIDES_SCRIPT_FILE="$SERVICE_WORKING_DIR/${SERVICE_NAME}.overrides.sh"
export SERVICE_MANAGE_SCRIPT_FILE="$SERVICE_WORKING_DIR/manage.sh"
export SERVICE_VERSION_FILE="$SERVICE_WORKING_DIR/.version"

export SERVICE_NAME
export SERVICE_WORKING_DIR

export SERVICE_INSTALLED_VERSION="0"
if [ -f "$SERVICE_VERSION_FILE" ]; then
  SERVICE_INSTALLED_VERSION=$(cat "$SERVICE_VERSION_FILE")
fi

export SERVICE_APP_ID
export SERVICE_STEAM_AUTH_LEVEL

# shellcheck disable=SC2155
export IS_STEAM_GAME=$(
  ! [ "$SERVICE_APP_ID" != "0" ]
  echo $?
)