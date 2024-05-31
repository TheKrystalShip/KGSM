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
SOURCE_DIR=$2

BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"
OVERRIDES_SCRIPT="$(find "$KGSM_ROOT" -type f -name overrides.sh)"

# shellcheck disable=SC1090
source "$BLUEPRINT_SCRIPT" "$SERVICE" || exit 1

function func_restore_backup() {
  local source=$1
  local backup_version=""

  # Get version number from $source
  IFS='-' read -ra backup_name <<<"$source"
  backup_version="${backup_name[1]}"
  unset IFS

  if [ -n "$(ls -A -I .gitignore "$SERVICE_INSTALL_DIR")" ]; then
    # $SERVICE_INSTALL_DIR is not empty
    read -r -p ">>> WARNING: $SERVICE_INSTALL_DIR is not empty, continue? (y/n): " confirm && [[ $confirm == [yY] ]] || exit 1
  fi

  # $SERVICE_INSTALL_DIR is empty/user confirmed continue, move the backup into it
  if ! mv "$SERVICE_BACKUPS_DIR/$source"/* "$SERVICE_INSTALL_DIR"/; then
    echo ">>> ERROR: Failed to move contents from $source into $SERVICE_INSTALL_DIR"
    return
  fi

  # Updated $SERVICE_VERSION_FILE with $backup_version
  if ! echo "$backup_version" >"$SERVICE_VERSION_FILE"; then
    echo ">>> WARNING: Failed to update version in $SERVICE_VERSION_FILE"
  fi

  # Remove empty backup directory
  if ! rm -rf "${SERVICE_BACKUPS_DIR:?}/${source:?}"; then
    echo ">>> WARNING: Failed to remove $source"
  fi
}

# shellcheck disable=SC1090
source "$OVERRIDES_SCRIPT" "$SERVICE_NAME" || exit 1

func_restore_backup "$SOURCE_DIR"
