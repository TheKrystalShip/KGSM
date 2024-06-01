#!/bin/bash

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

# Passed as argument
# Possible values: 0, 1
AUTH_LEVEL=$1

# Used for steamcmd login
# Anonymous login by default
USERNAME="anonymous"

# Anonymous login not allowed, load username & pass
if [ "$AUTH_LEVEL" != "0" ]; then
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
  local app_id=$1
  steamcmd \
    +login "$USERNAME" \
    +app_info_update 1 \
    +app_info_print "$app_id" \
    +quit | tr '\n' ' ' | grep \
    --color=NEVER \
    -Po '"branches"\s*{\s*"public"\s*{\s*"buildid"\s*"\K(\d*)'
}

function steamcmd_download() {
  local app_id=$1
  local output_dir=$2
  steamcmd \
    +@sSteamCmdForcePlatformType linux \
    +force_install_dir "$output_dir" \
    +login "$USERNAME" \
    +app_update "$app_id" \
    -beta none \
    validate \
    +quit
}
