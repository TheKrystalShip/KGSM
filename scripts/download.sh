#!/bin/bash

# Params
if [ $# -eq 0 ]; then
  echo ">>> ERROR: Service name not supplied. Run script like this: ./${0##*/} \"SERVICE\""
  exit 1
fi

SERVICE=$1

# shellcheck disable=SC1091
source /etc/environment

# shellcheck disable=SC1091
source /opt/scripts/service_vars.sh "$SERVICE"

# shellcheck disable=SC1091
source /opt/scripts/steamcmd.sh "$SERVICE_STEAM_AUTH_LEVEL"

# Calls SteamCMD to handle the download
function func_download() {
  steamcmd_download "$SERVICE_APP_ID" "$SERVICE_TEMP_DIR"
}

# shellcheck disable=SC1091
source /opt/scripts/overrides.sh "$SERVICE"

func_download
