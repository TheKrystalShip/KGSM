#!/bin/bash

function usage() {
  echo "Creates or restores backups.

Usage:
  $(basename "$0") [-i | --instance] <instance> OPTION

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

SELF_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check for KGSM_ROOT
if [ -z "$KGSM_ROOT" ]; then
  while [[ "$SELF_PATH" != "/" ]]; do
    [[ -f "$SELF_PATH/kgsm.sh" ]] && KGSM_ROOT="$SELF_PATH" && break
    SELF_PATH="$(dirname "$SELF_PATH")"
  done
  [[ -z "$KGSM_ROOT" ]] && echo "Error: Could not locate kgsm.sh. Ensure the directory structure is intact." && exit 1
  export KGSM_ROOT
fi

if [[ ! "$KGSM_COMMON_LOADED" ]]; then
  module_common="$(find "$KGSM_ROOT" -type f -name common.sh -print -quit)"
  [[ -z "$module_common" ]] && echo "${0##*/} ERROR: Failed to load module common.sh" >&2 && exit 1
  # shellcheck disable=SC1090
  source "$module_common" || exit 1
fi

instance_config_file=$(__load_instance "$instance")
# shellcheck disable=SC1090
source "$instance_config_file" || exit "$EC_FAILED_SOURCE"

module_instances=$(__load_module instances.sh)

function _create() {
  # Check for content inside the install directory before attempting to
  # create a backup. If empty, skip
  if [ -z "$(ls -A "$INSTANCE_INSTALL_DIR")" ]; then
    # $source is empty, nothing to back up
    __print_warning "$INSTANCE_INSTALL_DIR is empty, skipping backup" && return 0
  fi

  # Check instance running state before attempting to create backup
  if "$module_instances" --is-active "$instance" >/dev/null; then
    __print_error "Instance $instance is currently running, please shut down before attempting to create a backup" && return "$EC_GENERAL"
  fi

  #shellcheck disable=SC2155
  local datetime="$(date +"%Y-%m-%dT%H:%M:%S")"
  local output="${INSTANCE_BACKUPS_DIR}/${INSTANCE_FULL_NAME}-${INSTANCE_INSTALLED_VERSION}-${datetime}.backup"

  if [[ "$COMPRESS_BACKUPS" == 1 ]]; then
    output="${output}.tar.gz"

    if ! touch "$output"; then
      __print_error "Failed to create $output" && return "$EC_GENERAL"
    fi

    cd "$INSTANCE_INSTALL_DIR" || return "$EC_FAILED_CD"

    if ! tar -czf "$output" .; then
      __print_error "Failed to compress $output" && return "$EC_GENERAL"
    fi
  else
    # Create backup folder if it doesn't exit
    if [ ! -d "$output" ]; then
      if ! mkdir -p "$output"; then
        __print_error "Error creating backup folder $output" && return "$EC_GENERAL"
      fi
    fi

    # Copy everything from the install directory into a backup folder
    if ! cp -r "$INSTANCE_INSTALL_DIR"/* "$output"/; then
      __print_error "Failed to create backup $output"
      rm -rf "${output:?}"
      return "$EC_FAILED_CP"
    fi
  fi

  __emit_instance_backup_created "${instance%.ini}" "$output" "$INSTANCE_INSTALLED_VERSION"
  return 0
}

function _restore() {
  local source="$INSTANCE_BACKUPS_DIR/$1"
  local backup_version

  if [[ ! -f "$source" ]] && [[ ! -d "$source" ]]; then
    __print_error "Could not find backup $source" && return "$EC_FILE_NOT_FOUND"
  fi

  # Get version number from $source
  IFS='-' read -ra backup_name <<<"${source#"$INSTANCE_BACKUPS_DIR/"}"
  backup_version="${backup_name[2]}"
  unset IFS

  if [ -n "$(ls -A "$INSTANCE_INSTALL_DIR")" ]; then
    # $INSTANCE_INSTALL_DIR is not empty, create new backup before proceeding
    _create || __print_error "Failed to restore backup ${source#"$INSTANCE_BACKUPS_DIR/"}" && return $?
    if ! rm -rf "${INSTANCE_INSTALL_DIR:?}"/*; then
      __print_error "Failed to clear $INSTANCE_INSTALL_DIR, exiting" && return "$EC_FAILED_RM"
    fi
  fi

  if [[ "$source" == *.gz ]]; then
    cd "$INSTANCE_INSTALL_DIR" || return "$EC_FAILED_CD"
    if ! tar -xzf "$source" .; then
      __print_error "Failed to restore $source" && return "$EC_GENERAL"
    fi
  else
    # $INSTANCE_INSTALL_DIR is empty/user confirmed continue, move the backup into it
    if ! cp -r "$source"/* "$INSTANCE_INSTALL_DIR"/; then
      __print_error "Failed to restore backup $source" && return "$EC_FAILED_CP"
    fi
  fi

  # Updated $INSTANCE_INSTALLED_VERSION with $backup_version
  if ! sed -i "/INSTANCE_INSTALLED_VERSION=*/cINSTANCE_INSTALLED_VERSION=$backup_version" "$instance_config_file" >/dev/null; then
    __print_error "Failed to update version in $instance_config_file" && return "$EC_GENERAL"
  fi

  # Update instance version file with $backup_version
  instance_version_file=${INSTANCE_WORKING_DIR}/${INSTANCE_FULL_NAME}.version
  if [[ -f "$instance_version_file" ]]; then
    if ! echo "$backup_version" >"$instance_version_file"; then
      __print_error "Failed to restore version in $instance_version_file" && return "$EC_GENERAL"
    fi
  fi

  __emit_instance_backup_restored "${instance%.ini}" "$source" "$backup_version"
  return 0
}

function _list_backups() {
  local instance_backups_dir
  instance_backups_dir=$(grep "INSTANCE_BACKUPS_DIR=" <"$instance_config_file" | cut -d "=" -f2 | tr -d '"')
  [[ -z "$instance_backups_dir" ]] && __print_error "Malformed instance config file $instance_config_file, missing INSTANCE_BACKUPS_DIR" && return "$EC_GENERAL"

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
  --create)
    _create; exit $?
    ;;
  --restore)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <source>" && exit "$EC_MISSING_ARG"
    _restore "$1"; exit $?
    ;;
  --list)
    _list_backups; exit $?
    ;;
  *)
    __print_error "Invalid argument $1" && exit "$EC_INVALID_ARG"
    ;;
  esac
  shift
done
