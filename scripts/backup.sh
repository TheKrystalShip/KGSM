#!/bin/bash

# Params
if [ $# -eq 0 ]; then
  echo ">>> ERROR: Blueprint name not supplied." >&2
  echo "Run script like this: ./${0##*/} \"BLUEPRINT\" [--create | --restore]" >&2
  exit 1
fi

# Check for KGSM_ROOT env variable
if [ -z "$KGSM_ROOT" ]; then
  echo "WARNING: KGSM_ROOT environmental variable not found, sourcing /etc/environment." >&2
  # shellcheck disable=SC1091
  source /etc/environment

  # If not found in /etc/environment
  if [ -z "$KGSM_ROOT" ]; then
    echo ">>> ERROR: KGSM_ROOT environmental variable not found, exiting." >&2
    exit 1
  else
    echo "INFO: KGSM_ROOT found in /etc/environment, consider rebooting the system" >&2

    # Check if KGSM_ROOT is exported
    if ! declare -p KGSM_ROOT | grep -q 'declare -x'; then
      export KGSM_ROOT
    fi
  fi
fi

# Trap CTRL-C
trap exit INT

BLUEPRINT=$1

BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"

# shellcheck disable=SC1090
source "$BLUEPRINT_SCRIPT" "$BLUEPRINT" || exit 1

function _create() {
  local source="$SERVICE_INSTALL_DIR"
  local dest="$SERVICE_BACKUPS_DIR"

  # shellcheck disable=SC2155
  local datetime=$(exec date +"%Y-%m-%d%T")
  local output_dir="${dest}/${SERVICE_NAME}-${SERVICE_INSTALLED_VERSION}-${datetime}.backup"

  # Create backup folder if it doesn't exit
  if [ ! -d "$output_dir" ]; then
    if ! mkdir -p "$output_dir"; then
      printf "\tERROR: Error creating backup folder %s" "$output_dir" >&2
      return 1
    fi
  fi

  # Check for content inside the install directory before attempting to
  # create a backup. If empty, skip
  if [ -z "$(ls -A -I .gitignore "$source")" ]; then
    # $source is empty, nothing to back up
    echo ">>> WARNING: $source is empty, skipping backup"
    rm -rf "${output_dir:?}"
    return 0
  fi

  # Move everything from the install directory into a backup folder
  if ! mv "$source"/* "$output_dir"/; then
    echo ">>> ERROR: Failed to move contents from $source into $output_dir" >&2
    rm -rf "${output_dir:?}"
    return 1
  fi

  if ! echo "" >"$SERVICE_VERSION_FILE"; then
    echo ">>> WARNING: Failed to reset version in $SERVICE_VERSION_FILE"
  fi

  echo "$output_dir"
  return 0
}

function _restore() {
  local source=${1:-}
  local backup_version=""

  # If no backup source is passed as param, prompt user to select one
  if [ -z "$source" ]; then
    shopt -s extglob nullglob

    # Create array
    backups_array=("$SERVICE_BACKUPS_DIR"/*)
    # remove leading $SERVICE_BACKUPS_DIR:
    backups_array=("${backups_array[@]#"$SERVICE_BACKUPS_DIR/"}")

    if ((${#backups_array[@]} < 1)); then
      echo "No backups found. Exiting." >&2
      return 0
    fi

    echo "KGSM - Restore backup - v$VERSION"
    PS3="Choose a backup to restore: "

    select backup in "${backups_array[@]}"; do
      if [[ -z $backup ]]; then
        echo "Didn't understand \"$REPLY\" " >&2
        REPLY=
      else
        source="$backup"
        break
      fi
    done
  fi

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
    echo ">>> ERROR: Failed to move contents from $source into $SERVICE_INSTALL_DIR" >&2
    return 1
  fi

  # Updated $SERVICE_VERSION_FILE with $backup_version
  if ! echo "$backup_version" >"$SERVICE_VERSION_FILE"; then
    echo ">>> WARNING: Failed to update version in $SERVICE_VERSION_FILE" >&2
    return 1
  fi

  # Remove empty backup directory
  if ! rm -rf "${SERVICE_BACKUPS_DIR:?}/${source:?}"; then
    echo ">>> WARNING: Failed to remove $source" >&2
    return 1
  fi

  return 0
}

#Read the argument values
while [ $# -gt 0 ]; do
  case "$2" in
  --create)
    _create
    shift
    ;;
  --restore)
    _restore "$3"
    shift
    ;;
  *)
    shift
    ;;
  esac
  shift
done
