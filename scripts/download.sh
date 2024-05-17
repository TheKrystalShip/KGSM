#!/bin/bash

# Params
if [ $# -eq 0 ]; then
  echo ">>> ERROR: Service name not supplied. Run script like this: ./${0##*/} \"SERVICE\""
  exit 1
fi

SERVICE=$1
VERSION=${2:-0}

# shellcheck disable=SC1091
source /etc/environment

# shellcheck disable=SC1091
source /opt/scripts/service_vars.sh "$SERVICE"

# shellcheck disable=SC1091
source /opt/scripts/steamcmd.sh "$SERVICE_STEAM_AUTH_LEVEL"

# If no version is passed, just fetch the latest
if [ "$VERSION" -eq 0 ]; then
  VERSION=$(/opt/scripts/version.sh "$SERVICE_NAME")
fi

# Calls SteamCMD to handle the download
function func_download() {
  # shellcheck disable=SC2034
  local version=$1
  local dest=$2

  steamcmd_download "$SERVICE_APP_ID" "$dest"
}

# shellcheck disable=SC1091
source /opt/scripts/overrides.sh "$SERVICE_NAME"

func_download "$VERSION" "$SERVICE_TEMP_DIR"
