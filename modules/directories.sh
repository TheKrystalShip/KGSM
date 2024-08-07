#!/bin/bash

function usage() {
  echo "Scaffolds the necessary directory structure for a blueprint on
installation.
Removes the directory structure on uninstall.

Usage:
    ./${0##*/} [-b | --blueprint] <bp> <option>

Options:
    -b --blueprint <bp>   Name of the blueprint file.
                          The .bp extension in the name is optional

    -h --help             Prints this message

    --install             Generates the directory structure for
                          the specified blueprint

    --uninstall           Removes the directory structure for
                          the specified blueprint

Examples:
    ./${0##*/} -b valheim --install

    ./${0##*/} --blueprint terraria --uninstall
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

declare -a DIR_ARRAY=(
  "$SERVICE_WORKING_DIR"
  "$SERVICE_BACKUPS_DIR"
  "$SERVICE_CONFIG_DIR"
  "$SERVICE_INSTALL_DIR"
  "$SERVICE_SAVES_DIR"
  "$SERVICE_TEMP_DIR"
)

function _install() {
  # Create directory tree
  for dir in "${DIR_ARRAY[@]}"; do
    # "mkdir -p" is crucial, see https://linux.die.net/man/1/mkdir
    if ! mkdir -p "$dir"; then
      printf "ERROR: Failed to create %s\n" "$dir" >&2
      return 1
    fi
  done
  return 0
}

function _uninstall() {
  # Remove main working directory
  if ! rm -rf "$SERVICE_WORKING_DIR"; then
    echo "ERROR: Failed to remove $SERVICE_WORKING_DIR" >&2
    return 1
  fi
  return 0
}

# Read the argument values
while [ $# -gt 0 ]; do
  case "$1" in
  --install)
    _install && exit $?
    shift
    ;;
  --uninstall)
    _uninstall && exit $?
    shift
    ;;
  *)
    echo "ERROR: Invalid argument $1" >&2 && usage && exit 1
    ;;
  esac
  shift
done
