#!/bin/bash

# Params
if [ $# -eq 0 ]; then
  echo ">>> ERROR: Service name not supplied. Run script like this: ./${0##*/} \"SERVICE\""
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

PWD=$(pwd)
BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"
OVERRIDES_SCRIPT="$(find "$KGSM_ROOT" -type f -name overrides.sh)"

# shellcheck disable=SC1090
source "$BLUEPRINT_SCRIPT" "$SERVICE" || exit 1

function func_create_backup() {
  local source=$1
  local dest=$2

  # shellcheck disable=SC2155
  local datetime=$(exec date +"%Y-%m-%d%T")
  local output_dir="${dest}/${SERVICE_NAME}-${SERVICE_INSTALLED_VERSION}-${datetime}.backup"

  # Create backup folder if it doesn't exit
  if [ ! -d "$output_dir" ]; then
    if ! mkdir -p "$output_dir"; then
      printf "\tERROR: Error creating backup folder %s" "$output_dir"
      return 1
    fi
  fi

  # Check for content inside the install directory before attempting to
  # create a backup. If empty, skip
  if [ -z "$(ls -A -I .gitignore "$source")" ]; then
    # $source is empty, nothing to back up
    echo ">>> WARNING: $source is empty, skipping backup"
    remove_backup_dir "$output_dir"
    return 0
  fi

  # Move everything from the install directory into a backup folder
  if ! mv "$source"/* "$output_dir"/; then
    echo ">>> ERROR: Failed to move contents from $source into $output_dir"
    remove_backup_dir "$output_dir"
    return 1
  fi

  if ! echo "0" >"$SERVICE_VERSION_FILE"; then
    echo ">>> WARNING: Failed to reset version in $SERVICE_VERSION_FILE"
  fi

  echo "$output_dir"
  return 0
}

function remove_backup_dir() {
  local dir=$1
  if ! rm -rf "${dir:?}"; then
    echo ">>> WARNING: Failed to remove $dir"
  fi
}

# shellcheck disable=SC1090
source "$OVERRIDES_SCRIPT" "$SERVICE_NAME"

func_create_backup "$SERVICE_INSTALL_DIR" "$SERVICE_BACKUPS_DIR"
