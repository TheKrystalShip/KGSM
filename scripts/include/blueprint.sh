#!/bin/bash

if [ $# -eq 0 ]; then
  echo ">>> ERROR: BLUEPRINT name not supplied. Run script like this: ./${0##*/} \"BLUEPRINT\"" >&2
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

if [[ "$BLUEPRINT" != *.bp ]]; then
  BLUEPRINT="${BLUEPRINT}.bp"
fi

BLUEPRINT_FILE="$(find "$KGSM_ROOT" -type f -name "$BLUEPRINT")"

if [ ! -f "$BLUEPRINT_FILE" ]; then
  echo ">>> ERROR: Could not find blueprint $BLUEPRINT_FILE, exiting" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$BLUEPRINT_FILE"

export SERVICE_BACKUPS_DIR="$SERVICE_WORKING_DIR/backups"
export SERVICE_CONFIG_DIR="$SERVICE_WORKING_DIR/config"
export SERVICE_INSTALL_DIR="$SERVICE_WORKING_DIR/install"
export SERVICE_SAVES_DIR="$SERVICE_WORKING_DIR/saves"
export SERVICE_TEMP_DIR="$SERVICE_WORKING_DIR/temp"

export SERVICE_OVERRIDES_SCRIPT_FILE="$SERVICE_WORKING_DIR/${SERVICE_NAME}.overrides.sh"
export SERVICE_MANAGE_SCRIPT_FILE="$SERVICE_WORKING_DIR/${SERVICE_NAME}.manage.sh"
export SERVICE_VERSION_FILE="$SERVICE_WORKING_DIR/${SERVICE_NAME}.version"
export SERVICE_SOCKET_FILE="$SERVICE_WORKING_DIR/${SERVICE_NAME}.in"

export SYSTEMD_DIR="/etc/systemd/system"
export SERVICE_SYSTEMD_SERVICE_FILE="$SYSTEMD_DIR/${SERVICE_NAME}.service"
export SERVICE_SYSTEMD_SOCKET_FILE="$SYSTEMD_DIR/${SERVICE_NAME}.socket"

export UFW_DIR="/etc/ufw/applications.d"
export SERVICE_UFW_FIREWALL_FILE="$UFW_DIR/kgsm-${SERVICE_NAME}"

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
