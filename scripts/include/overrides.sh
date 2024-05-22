#!/bin/bash

# Params
if [ $# -eq 0 ]; then
  echo "ERROR: Service name not supplied"
  exit 2
fi

SERVICE=$1


COMMON_SCRIPT="$(find "$KGSM_ROOT" -type f -name common.sh)"
BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"

# shellcheck disable=SC1090
source "$COMMON_SCRIPT" || exit 1

# shellcheck disable=SC1090
source "$BLUEPRINT_SCRIPT" "$SERVICE" || exit 1

# Import custom scripts if the game has any
if [ -f "$SERVICE_OVERRIDES_SCRIPT_FILE" ]; then
  # shellcheck disable=SC1090
  source "$SERVICE_OVERRIDES_SCRIPT_FILE"
fi
