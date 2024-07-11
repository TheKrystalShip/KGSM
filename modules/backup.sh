#!/bin/bash

function usage() {
  echo "Creates or restores backups

Usage:
    ./${0##*/} [-b | --blueprint] <bp> <option>

Options:
    -b --blueprint <bp>   Name of the blueprint file.
                          The .bp extension in the name is optional

    -h --help             Prints this message

    --create              Creates a new backup for the specified blueprint

    --restore <source>    Restore a specific backup.
                          <source> must be the name of the backup to restore

Examples:
    ./${0##*/} -b valheim --create

    ./${0##*/} --blueprint terraria --restore

    ./${0##*/} -b 7dtd --restore 7dtd-12966454-2024-05-2011:07:50.backup
"
}

set -eo pipefail

# shellcheck disable=SC2199
if [[ $@ =~ "--debug" ]]; then
  export PS4='+(\033[0;33m${BASH_SOURCE}:${LINENO}\033[0m): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
  set -x
  for a; do
    shift
    case $a in
    --debug) continue ;;
    *) set -- "$@" "$a" ;;
    esac
  done
fi

if [ "$#" -eq 0 ]; then usage && exit 1; fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
  -h | --help)
    usage && exit 0
    ;;
  -b | --blueprint)
    shift
    BLUEPRINT=$1
    shift
    ;;
  *)
    break
    ;;
  esac
done

# Check for KGSM_ROOT env variable
if [ -z "$KGSM_ROOT" ]; then
  echo "WARNING: KGSM_ROOT not found, sourcing /etc/environment." >&2
  # shellcheck disable=SC1091
  source /etc/environment

  # If not found in /etc/environment
  if [ -z "$KGSM_ROOT" ]; then
    echo "ERROR: KGSM_ROOT not found, exiting." >&2
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
trap "echo "" && exit" INT

BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"

# shellcheck disable=SC1090
source "$BLUEPRINT_SCRIPT" "$BLUEPRINT" || exit 1

function _create() {
  local source="$SERVICE_INSTALL_DIR"
  local dest="$SERVICE_BACKUPS_DIR"

  # Check for content inside the install directory before attempting to
  # create a backup. If empty, skip
  if [ -z "$(ls -A -I .gitignore "$source")" ]; then
    # $source is empty, nothing to back up
    echo "WARNING: $source is empty, skipping backup" >&2
    return 0
  fi

  # shellcheck disable=SC2155
  local datetime=$(exec date +"%Y-%m-%d%T")
  local output_dir="${dest}/${SERVICE_NAME}-${SERVICE_INSTALLED_VERSION}-${datetime}.backup"

  # Create backup folder if it doesn't exit
  if [ ! -d "$output_dir" ]; then
    if ! mkdir -p "$output_dir"; then
      echo "ERROR: Error creating backup folder $output_dir" >&2
      return 1
    fi
  fi

  # Move everything from the install directory into a backup folder
  if ! mv "$source"/* "$output_dir"/; then
    echo "ERROR: Failed to move contents from $source into $output_dir" >&2
    rm -rf "${output_dir:?}"
    return 1
  fi

  if ! echo "0" >"$SERVICE_VERSION_FILE"; then
    echo "WARNING: Failed to reset version in $SERVICE_VERSION_FILE" >&2
  fi

  return 0
}

function _restore() {
  local source=$1
  local backup_version=""

  # Get version number from $source
  IFS='-' read -ra backup_name <<<"$source"
  backup_version="${backup_name[1]}"
  unset IFS

  if [ -n "$(ls -A -I .gitignore "$SERVICE_INSTALL_DIR")" ]; then
    # $SERVICE_INSTALL_DIR is not empty
    read -r -p "WARNING: $SERVICE_INSTALL_DIR is not empty, continue? (y/n): " confirm && [[ $confirm == [yY] ]] || exit 1
  fi

  # $SERVICE_INSTALL_DIR is empty/user confirmed continue, move the backup into it
  if ! mv "$SERVICE_BACKUPS_DIR/$source"/* "$SERVICE_INSTALL_DIR"/; then
    echo "ERROR: Failed to move contents from $source into $SERVICE_INSTALL_DIR" >&2
    return 1
  fi

  # Updated $SERVICE_VERSION_FILE with $backup_version
  if ! echo "$backup_version" >"$SERVICE_VERSION_FILE"; then
    echo "WARNING: Failed to update version in $SERVICE_VERSION_FILE" >&2
    return 1
  fi

  # Remove empty backup directory
  if ! rm -rf "${SERVICE_BACKUPS_DIR:?}/${source:?}"; then
    echo "WARNING: Failed to remove $source" >&2
    return 1
  fi

  return 0
}

#Read the argument values
while [ $# -gt 0 ]; do
  case "$1" in
  -h | --help)
    usage && exit 0
    ;;
  --create)
    _create && exit $?
    ;;
  --restore)
    shift
    [[ -z "$1" ]] && echo "ERROR: Missing argument <source>" >&2
    _restore "$1" && exit $?
    ;;
  *)
    echo "ERROR: Invalid argument $1" >&2
    usage && exit 1
    ;;
  esac
  shift
done
