#!/bin/bash

function usage() {
  echo "Creates or restores backups.

Usage:
  $(basename "$0") [-i | --instance <instance>] OPTION

Options:
  -h, --help                  Prints this message
  -i, --instance <instance>   Full name of the instance, equivalent of
                              INSTANCE_FULL_NAME from the instance config file
                              The .ini extension is not required
    --list                    Print a list of all backups of the instance
    --create                  Creates a new backup for the specified instance
    --restore <source>        Restore a specific backup.
                              <source> must be the name of the backup to restore

Examples:
  $(basename "$0") -i valheim-9d52mZ.ini --create
  $(basename "$0") --instance valheim-9d52mZ --restore valheim-14349389-2024-05-17T12:40:24.backup
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
  -i | --instance)
    shift
    [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument <instance>" >&2 && exit 1
    instance=$1
    ;;
  *)
    break
    ;;
  esac
  shift
done

# Check for KGSM_ROOT env variable
if [ -z "$KGSM_ROOT" ]; then
  echo "WARNING: KGSM_ROOT not found, sourcing /etc/environment." >&2
  # shellcheck disable=SC1091
  source /etc/environment
  [[ -z "$KGSM_ROOT" ]] && echo "${0##*/} ERROR: KGSM_ROOT not found, exiting." >&2 && exit 1
  echo "INFO: KGSM_ROOT found in /etc/environment, consider rebooting the system" >&2
  if ! declare -p KGSM_ROOT | grep -q 'declare -x'; then export KGSM_ROOT; fi
fi

# Read configuration file
if [ -z "$KGSM_CONFIG_LOADED" ]; then
  CONFIG_FILE="$(find "$KGSM_ROOT" -type f -name config.ini)"
  [[ -z "$CONFIG_FILE" ]] && echo "${0##*/} ERROR: Could not find config.ini file" >&2 && exit 1
  while IFS= read -r line || [ -n "$line" ]; do
    # Ignore comment lines and empty lines
    if [[ "$line" =~ ^#.*$ ]] || [[ -z "$line" ]]; then continue; fi
    export "${line?}"
  done <"$CONFIG_FILE"
  export KGSM_CONFIG_LOADED=1
fi

# Trap CTRL-C
trap "echo "" && exit" INT

module_common=$(find "$KGSM_ROOT" -type f -name common.sh)
[[ -z "$module_common" ]] && echo "${0##*/} ERROR: Could not find module common.sh" >&2 && exit 1

# shellcheck disable=SC1090
source "$module_common" || exit 1

instance_config_file=$(__load_instance "$instance")
# shellcheck disable=SC1090
source "$instance_config_file" || exit 1

function _create() {
  # Check for content inside the install directory before attempting to
  # create a backup. If empty, skip
  if [ -z "$(ls -A "$INSTANCE_INSTALL_DIR")" ]; then
    # $source is empty, nothing to back up
    echo "WARNING: $INSTANCE_INSTALL_DIR is empty, skipping backup" >&2 && return 0
  fi

  # shellcheck disable=SC2155
  local datetime="$(date +"%Y-%m-%dT%H:%M:%S")"
  local output_dir="${INSTANCE_BACKUPS_DIR}/${INSTANCE_FULL_NAME}-${INSTANCE_INSTALLED_VERSION}-${datetime}.backup"

  # Create backup folder if it doesn't exit
  if [ ! -d "$output_dir" ]; then
    if ! mkdir -p "$output_dir"; then
      echo "${0##*/} ERROR: Error creating backup folder $output_dir" >&2 && return 1
    fi
  fi

  # Move everything from the install directory into a backup folder
  if ! mv "$INSTANCE_INSTALL_DIR"/* "$output_dir"/; then
    echo "${0##*/} ERROR: Failed to move contents from $INSTANCE_INSTALL_DIR into $output_dir" >&2
    rm -rf "${output_dir:?}"
    return 1
  fi

  if ! sed -i "/INSTANCE_INSTALLED_VERSION=*/cINSTANCE_INSTALLED_VERSION=0" "$instance_config_file" >/dev/null; then
    echo "WARNING: Failed to reset version in $instance_config_file" >&2
  fi

  return 0
}

function _restore() {
  local source=$1
  local backup_version

  # Get version number from $source
  IFS='-' read -ra backup_name <<<"$source"
  backup_version="${backup_name[2]}"
  unset IFS

  if [ -n "$(ls -A -I .gitignore "$INSTANCE_INSTALL_DIR")" ]; then
    # $INSTANCE_INSTALL_DIR is not empty
    read -r -p "WARNING: $INSTANCE_INSTALL_DIR is not empty, continue? (y/n): " confirm && [[ $confirm == [yY] ]] || exit 1
  fi

  # $INSTANCE_INSTALL_DIR is empty/user confirmed continue, move the backup into it
  if ! mv "$INSTANCE_BACKUPS_DIR/$source"/* "$INSTANCE_INSTALL_DIR"/; then
    echo "${0##*/} ERROR: Failed to move contents from $source into $INSTANCE_INSTALL_DIR" >&2 && return 1
  fi

  # Updated $INSTANCE_INSTALLED_VERSION with $backup_version
  if ! sed -i "/INSTANCE_INSTALLED_VERSION=*/cINSTANCE_INSTALLED_VERSION=$backup_version" "$instance_config_file" >/dev/null; then
    echo "ERROR: Failed to update version in $instance_config_file" >&2 && return 1
  fi

  # Update instance version file with $backup_version
  instance_version_file=${INSTANCE_WORKING_DIR}/${INSTANCE_FULL_NAME}.version
  if [[ -f "$instance_version_file" ]]; then
    if ! echo "$backup_version" >"$instance_version_file"; then
      echo "${0##*/} ERROR: Failed to restore version in $instance_version_file" >&2 && return 1
    fi
  fi

  # Remove empty backup directory
  if ! rm -rf "${INSTANCE_BACKUPS_DIR:?}/${source:?}"; then
    echo "ERROR: Failed to remove $source" >&2 && return 1
  fi

  return 0
}

function _list_backups() {
  local instance_backups_dir
  instance_backups_dir=$(grep "INSTANCE_BACKUPS_DIR=" <"$instance_config_file" | cut -d "=" -f2 | tr -d '"')
  [[ -z "$instance_backups_dir" ]] && echo "${0##*/} ERROR: Malformed instance config file $instance_config_file, missing INSTANCE_BACKUPS_DIR" >&2 && return 1

  shopt -s extglob nullglob

  # Create array
  backups_array=("$instance_backups_dir"/*)
  # remove leading $instance_backups_dir:
  backups_array=("${backups_array[@]#"$instance_backups_dir/"}")

  echo "${backups_array[@]}"
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
    [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument <source>" >&2
    _restore "$1" && exit $?
    ;;
  --list)
    _list_backups && exit $?
    ;;
  *)
    echo "${0##*/} ERROR: Invalid argument $1" >&2 && exit 1
    ;;
  esac
  shift
done
