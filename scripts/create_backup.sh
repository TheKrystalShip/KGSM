#!/bin/bash

if [ $# -eq 0 ]; then
  echo "ERROR: Service name not supplied"
  exit 1
fi

# shellcheck disable=SC1091
source /opt/scripts/service_vars.sh "$1"

function func_create_backup() {
  # shellcheck disable=SC2155
  local datetime=$(exec date +"%Y-%m-%d%T")
  local output_dir="${SERVICE_BACKUPS_DIR}/${SERVICE_NAME}-${SERVICE_INSTALLED_VERSION}-${datetime}.backup"

  # Create backup folder if it doesn't exit
  if [ ! -d "$output_dir" ]; then
    if ! mkdir -p "$output_dir"; then
      printf "\tERROR: Error creating backup folder %s" "$output_dir"
      return
    fi
  fi

  if ! mv -v "$SERVICE_INSTALL_DIR"/* "$output_dir"/; then
    echo ">>> ERROR: Failed to move contents from $SERVICE_INSTALL_DIR into $output_dir"
    return
  fi

  # shellcheck disable=SC2034
  func_create_backup_result="$output_dir"
  echo "$func_create_backup_result"
}

func_create_backup
