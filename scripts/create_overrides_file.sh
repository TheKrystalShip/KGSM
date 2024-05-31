#!/bin/bash

if [ $# -eq 0 ]; then
  echo ">>> ERROR: Service name not supplied. Run script like this: ./${0##*/} \"SERVICE\"" >&2
  exit 1
fi

if [ -z "$KGSM_ROOT" ] && [ -z "$KGSM_ROOT_FOUND" ]; then
  echo "WARNING: KGSM_ROOT environmental variable not found, sourcing /etc/environment." >&2
  # shellcheck disable=SC1091
  source /etc/environment

  if [ -z "$KGSM_ROOT" ]; then
    echo ">>> ERROR: KGSM_ROOT environmental variable not found, exiting." >&2
    exit 1
  else
    if [ -z "$KGSM_ROOT_FOUND" ]; then
      echo "INFO: KGSM_ROOT found in /etc/environment, consider rebooting the system" >&2
      export KGSM_ROOT_FOUND=1
    fi
  fi
fi

SERVICE=$1

BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"
OVERRIDES_FILE="$(find "$KGSM_ROOT" -type f -name "${SERVICE}".overrides.sh)"

# shellcheck disable=SC1090
source "$BLUEPRINT_SCRIPT" "$SERVICE" || exit 1

# If overrides file exists, copy it
if [ -f "$OVERRIDES_FILE" ]; then
  # Make copy
  if ! sudo cp -f "$OVERRIDES_FILE" "$SERVICE_OVERRIDES_SCRIPT_FILE"; then
    echo ">>> ERROR: Could not copy $OVERRIDES_FILE to $SERVICE_OVERRIDES_SCRIPT_FILE" >&2
    exit 1
  fi

  # Give +x permission
  if ! sudo chmod +x "$SERVICE_OVERRIDES_SCRIPT_FILE"; then
    echo ">>> ERROR: Failed to add +x permission to $SERVICE_OVERRIDES_SCRIPT_FILE" >&2
    exit 2
  fi
fi
