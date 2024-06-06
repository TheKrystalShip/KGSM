#!/bin/bash

# Params
if [ $# -eq 0 ]; then
  echo ">>> ERROR: Blueprint name not supplied. Run script like this: ./${0##*/} \"BLUEPRINT\"" >&2
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

BLUEPRINT=$1

BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"

# shellcheck disable=SC1090
source "$BLUEPRINT_SCRIPT" "$BLUEPRINT" || exit 1

# Used for steamcmd login
# Anonymous login by default
USERNAME="anonymous"

# Anonymous login not allowed, load username & pass
if [ "$SERVICE_STEAM_AUTH_LEVEL" != "0" ]; then
  if [ -z "$STEAM_USERNAME" ]; then
    echo ">>> ERROR: STEAM_USERNAME environmental variable not found, exiting" >&2
    exit 1
  fi
  if [ -z "$STEAM_PASSWORD" ]; then
    echo ">>> ERROR: STEAM_PASSWORD environmental variable not found, exiting" >&2
    exit 1
  fi

  USERNAME="$STEAM_USERNAME $STEAM_PASSWORD"
fi

function steamcmd_get_latest_version() {
  steamcmd \
    +login "$USERNAME" \
    +app_info_update 1 \
    +app_info_print "$SERVICE_APP_ID" \
    +quit | tr '\n' ' ' | grep \
    --color=NEVER \
    -Po '"branches"\s*{\s*"public"\s*{\s*"buildid"\s*"\K(\d*)'
}

function steamcmd_download() {
  local version=$1
  local dest=$2

  steamcmd \
    +@sSteamCmdForcePlatformType linux \
    +force_install_dir "$dest" \
    +login "$USERNAME" \
    +app_update "$SERVICE_APP_ID" \
    -beta none \
    validate \
    +quit
}
