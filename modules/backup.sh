#!/usr/bin/env bash

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

function _create_backup() {
  local output
  output=$("$INSTANCE_MANAGE_FILE" --create-backup $debug)

  __emit_instance_backup_created "${instance%.ini}" "$output"
}

function _restore_backup() {
  local source=$1
  "$INSTANCE_MANAGE_FILE" --restore-backup "$source" $debug

  __emit_instance_backup_restored "${instance%.ini}" "$source"
}

function _list_backups() {
  "$INSTANCE_MANAGE_FILE" --list-backups $debug
}

#Read the argument values
while [ $# -gt 0 ]; do
  case "$1" in
    --create)
      _create_backup
      exit $?
      ;;
    --restore)
      shift
      [[ -z "$1" ]] && __print_error "Missing argument <source>" && exit "$EC_MISSING_ARG"
      _restore_backup "$1"
      exit $?
      ;;
    --list)
      _list_backups
      exit $?
      ;;
    *)
      __print_error "Invalid argument $1" && exit "$EC_INVALID_ARG"
      ;;
  esac
  shift
done
