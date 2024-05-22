#!/bin/bash

if [ $# -eq 0 ]; then
  echo ">>> ERROR: SERVICE name not supplied. Run script like this: ./${0##*/} \"SERVICE\""
  exit 1
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
  if ! mkdir -p "$dir"; then
    printf ">>> ERROR: Failed to create %s\n" "$dir"
    exit 1
  fi
done
