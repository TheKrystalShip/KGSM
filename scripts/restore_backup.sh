#!/bin/bash

# Params
if [ $# -eq 0 ]; then
  echo ">>> ERROR: Service name not supplied. Run script like this: ./${0##*/} \"SERVICE\" \"SOURCE\""
  exit 1
fi
if [ $# -eq 1 ]; then
  echo ">>> ERROR: Source directory not supplied. Run script like this: ./${0##*/} \"SERVICE\" \"SOURCE\""
  exit 1
fi

SERVICE=$1
SOURCE_DIR=$2

# shellcheck disable=SC1091
source /opt/scripts/service_vars.sh "$SERVICE"

function func_restore_backup() {
  local source=$1

  if [ -n "$(ls -A -I .gitignore "$SERVICE_INSTALL_DIR")" ]; then
    # $SERVICE_INSTALL_DIR is not empty
    read -r -p ">>> WARNING: $SERVICE_INSTALL_DIR is not empty, continue? (y/n): " confirm && [[ $confirm == [yY] ]] || exit 1
  fi

  # $SERVICE_INSTALL_DIR is empty/user confirmed continue, move the backup into it
  if ! mv -v "$SERVICE_BACKUPS_DIR/$source"/* "$SERVICE_INSTALL_DIR"/; then
    echo ">>> ERROR: Failed to move contents from $source into $SERVICE_INSTALL_DIR"
    return
  fi

  # Remove empty backup directory
  if ! rm -rf "${source:?}"; then
    echo ">>> WARNING: Failed to remove $source"
  fi
}

# shellcheck disable=SC1091
source /opt/scripts/overrides.sh "$SERVICE_NAME"

func_restore_backup "$SOURCE_DIR"
