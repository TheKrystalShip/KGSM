#!/bin/bash

if [ $# -eq 0 ]; then
  echo ">>> ERROR: SERVICE name not supplied. Run script like this: ./${0##*/} \"SERVICE\""
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

# shellcheck disable=SC1090
source "$BLUEPRINT_SCRIPT" "$SERVICE" || exit 1

declare -a DIR_ARRAY=(
  "$SERVICE_WORKING_DIR"
  "$SERVICE_BACKUPS_DIR"
  "$SERVICE_CONFIG_DIR"
  "$SERVICE_INSTALL_DIR"
  "$SERVICE_SAVES_DIR"
  "$SERVICE_SERVICE_DIR"
  "$SERVICE_TEMP_DIR"
)

for dir in "${DIR_ARRAY[@]}"; do
  # "mkdir -p" is crucial, see https://linux.die.net/man/1/mkdir
  if ! sudo mkdir -p "$dir"; then
    printf ">>> ERROR: Failed to create %s\n" "$dir" >&2
    exit 1
  fi
done
