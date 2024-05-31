#!/bin/bash

# Params
if [ $# -eq 0 ]; then
  echo ">>> ERROR: Service name not supplied. Run script like this: ./${0##*/} \"SERVICE\""
  exit 1
fi

# shellcheck disable=SC1091
source /etc/environment

if [ -z "$KGSM_ROOT" ]; then
  echo ">>> ERROR: KGSM_ROOT environmental variable not set, exiting."
  exit 1
fi

SERVICE=$1

BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"

# shellcheck disable=SC1090
source "$BLUEPRINT_SCRIPT" "$SERVICE" || exit 1

rm -rf "${SERVICE_WORKING_DIR:?}"
