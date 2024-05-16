#!/bin/bash

# Params
if [ $# -eq 0 ]; then
  echo ">>> ERROR: Service name not supplied. Run script like this: ./${0##*/} \"SERVICE\""
  exit 1
fi

SERVICE=$1

# shellcheck disable=SC1091
source /opt/scripts/service_vars.sh "$SERVICE"

function func_create_backup() {
  # shellcheck disable=SC2155
  local datetime=$(exec date +"%Y-%m-%d%T")
  local output_dir="${SERVICE_BACKUPS_DIR}/${SERVICE_NAME}-${SERVICE_INSTALLED_VERSION}-${datetime}.backup"

  # Create backup folder if it doesn't exit
  if [ ! -d "$output_dir" ]; then
    if ! mkdir -p "$output_dir"; then
      printf "\tERROR: Error creating backup folder %s" "$output_dir"
      return "$EXITSTATUS_ERROR"
    fi
  fi

  # Check for content inside the install directory before attempting to
  # create a backup. If empty, skip
  if [ -z "$(ls -A -I .gitignore "$SERVICE_INSTALL_DIR")" ]; then
    # $SERVICE_INSTALL_DIR is empty, nothing to back up
    echo ">>> WARNING: $SERVICE_INSTALL_DIR is empty, skipping backup"
    remove_backup_dir "$output_dir"
    return 2
  fi

  # Move everything from the install directory into a backup folder
  if ! mv -v "$SERVICE_INSTALL_DIR"/* "$output_dir"/; then
    echo ">>> ERROR: Failed to move contents from $SERVICE_INSTALL_DIR into $output_dir"
    remove_backup_dir "$output_dir"
    return "$EXITSTATUS_ERROR"
  fi

  echo "$output_dir"
  return "$EXITSTATUS_SUCCESS"
}

function remove_backup_dir() {
  local dir=$1
  if ! rm -rf "${dir:?}"; then
    echo ">>> WARNING: Failed to remove $dir"
  fi
}

# shellcheck disable=SC1091
source /opt/scripts/overrides.sh "$SERVICE_NAME"

func_create_backup
