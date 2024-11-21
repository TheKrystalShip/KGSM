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

module_common="$(find "$KGSM_ROOT" -type f -name common.sh -print -quit)"
[[ -z "$module_common" ]] && echo "${0##*/} ERROR: Could not find module common.sh" >&2 && exit 1

# shellcheck disable=SC1090
source "$module_common" || exit 1

instance_config_file=$(__load_instance "$instance")
# shellcheck disable=SC1090
source "$instance_config_file" || exit 1

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
    __print_error "Instance $instance is currently running, please shut down before attempting to create a backup" && return 1
  fi

  #shellcheck disable=SC2155
  local datetime="$(date +"%Y-%m-%dT%H:%M:%S")"
  local output="${INSTANCE_BACKUPS_DIR}/${INSTANCE_FULL_NAME}-${INSTANCE_INSTALLED_VERSION}-${datetime}.backup"

  if [[ "$COMPRESS_BACKUPS" == 1 ]]; then
    output="${output}.tar.gz"

    if ! touch "$output"; then
      __print_error "Failed to create $output" && return 1
    fi

    cd "$INSTANCE_INSTALL_DIR"

    if ! tar -czf "$output" .; then
      __print_error "Failed to compress $output" && return 1
    fi
  else
    # Create backup folder if it doesn't exit
    if [ ! -d "$output" ]; then
      if ! mkdir -p "$output"; then
        __print_error "Error creating backup folder $output" && return 1
      fi
    fi

    # Copy everything from the install directory into a backup folder
    if ! cp -r "$INSTANCE_INSTALL_DIR"/* "$output"/; then
      __print_error "Failed to create backup $output"
      rm -rf "${output:?}"
      return 1
    fi
  fi

  __emit_instance_backup_created "${instance%.ini}" "$output" "$INSTANCE_INSTALLED_VERSION"
  return 0
}

function _restore() {
  local source="$INSTANCE_BACKUPS_DIR/$1"
  local backup_version

  if [[ ! -f "$source" ]] && [[ ! -d "$source" ]]; then
    __print_error "Could not find backup $source" && return 1
  fi

  # Get version number from $source
  IFS='-' read -ra backup_name <<<"${source#"$INSTANCE_BACKUPS_DIR/"}"
  backup_version="${backup_name[2]}"
  unset IFS

  if [ -n "$(ls -A "$INSTANCE_INSTALL_DIR")" ]; then
    # $INSTANCE_INSTALL_DIR is not empty, create new backup before proceeding
    _create || __print_error "Failed to restore backup ${source#"$INSTANCE_BACKUPS_DIR/"}" && return 1
    if ! rm -rf "${INSTANCE_INSTALL_DIR:?}"/*; then
      __print_error "Failed to clear $INSTANCE_INSTALL_DIR, exiting" && return 1
    fi
  fi

  if [[ "$source" == *.gz ]]; then
    cd "$INSTANCE_INSTALL_DIR"
    if ! tar -xzf "$source" .; then
      __print_error "Failed to restore $source" && return 1
    fi
  else
    # $INSTANCE_INSTALL_DIR is empty/user confirmed continue, move the backup into it
    if ! cp -r "$source"/* "$INSTANCE_INSTALL_DIR"/; then
      __print_error "Failed to restore backup $source" && return 1
    fi
  fi

  # Updated $INSTANCE_INSTALLED_VERSION with $backup_version
  if ! sed -i "/INSTANCE_INSTALLED_VERSION=*/cINSTANCE_INSTALLED_VERSION=$backup_version" "$instance_config_file" >/dev/null; then
    __print_error "Failed to update version in $instance_config_file" && return 1
  fi

  # Update instance version file with $backup_version
  instance_version_file=${INSTANCE_WORKING_DIR}/${INSTANCE_FULL_NAME}.version
  if [[ -f "$instance_version_file" ]]; then
    if ! echo "$backup_version" >"$instance_version_file"; then
      __print_error "Failed to restore version in $instance_version_file" && return 1
    fi
  fi

  __emit_instance_backup_restored "${instance%.ini}" "$source" "$backup_version"
  return 0
}

function _list_backups() {
  local instance_backups_dir
  instance_backups_dir=$(grep "INSTANCE_BACKUPS_DIR=" <"$instance_config_file" | cut -d "=" -f2 | tr -d '"')
  [[ -z "$instance_backups_dir" ]] && __print_error "Malformed instance config file $instance_config_file, missing INSTANCE_BACKUPS_DIR" && return 1

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
    [[ -z "$1" ]] && __print_error "Missing argument <source>"
    _restore "$1"; exit $?
    ;;
  --list)
    _list_backups; exit $?
    ;;
  *)
    __print_error "Invalid argument $1" && exit 1
    ;;
  esac
  shift
done
