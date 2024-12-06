#!/bin/bash

function usage() {
  echo "Runs the deployment process

Usage:
  $(basename "$0") [-i | --instance <instance>] OPTION

Options:
  -h, --help                  Prints this message
  -i, --instance <instance>   Full name of the instance, equivalent of
                              INSTANCE_FULL_NAME from the instance config file
                              The .ini extension is not required

Examples:
  $(basename "$0") -i valheim-9d52mZ.ini
  $(basename "$0") --instance valheim-9d52mZ
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
    echo "${0##*/} ERROR: Invalid argument $1" >&2 && exit 1
    ;;
  esac
  shift
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check for KGSM_ROOT
if [ -z "$KGSM_ROOT" ]; then
  # Search for the kgsm.sh file to dynamically set KGSM_ROOT
  KGSM_ROOT=$(find "$SCRIPT_DIR" -maxdepth 2 -name 'kgsm.sh' -exec dirname {} \;)
  [[ -z "$KGSM_ROOT" ]] && echo "Error: Could not locate kgsm.sh. Ensure the directory structure is intact." && exit 1
  export KGSM_ROOT
fi

module_common="$(find "$KGSM_ROOT" -type f -name common.sh -print -quit)"
[[ -z "$module_common" ]] && echo "${0##*/} ERROR: Failed to load module common.sh" >&2 && exit 1

# shellcheck disable=SC1090
source "$module_common" || exit 1

# shellcheck disable=SC1090
source "$(__load_instance "$instance")" || exit "$EC_FAILED_SOURCE"

module_overrides=$(__load_module overrides.sh)

function func_deploy() {
  local source=$1
  local dest=$2

  # Check if $source is empty
  if [ -z "$(ls -A -I .gitignore "$source")" ]; then
    __print_warning "$source is empty, nothing to deploy. Exiting" && return "$EC_FAILED_DEPLOY"
  fi

  # Copy everything from $source into $dest
  if ! cp -rf "$source"/* "$dest"; then
    __print_error "Failed to copy contents from $source into $dest" && return "$EC_FAILED_CP"
  fi

  if ! rm -rf "${source:?}"/*; then
    __print_error "Failed to clear $source" && return "$EC_FAILED_RM"
  fi

  return 0
}

# shellcheck disable=SC1090
source "$module_overrides" "$instance" || exit "$EC_FAILED_SOURCE"

__emit_instance_deploy_started "${instance%.ini}"

func_deploy "$INSTANCE_TEMP_DIR" "$INSTANCE_INSTALL_DIR" || exit $?

__emit_instance_deploy_finished "${instance%.ini}"

__emit_instance_deployed "${instance%.ini}"

exit 0
