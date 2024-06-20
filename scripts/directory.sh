#!/bin/bash

function usage() {
  echo "Scaffolds the necessary directory structure for a blueprint on
installation.
Removes the directory structure on uninstall.

Usage:
    ./directory.sh <blueprint> <option>

Options:
    blueprint     Name of the blueprint file.
                  The .bp extension in the name is optional

    -h --help     Prints this message

    --install     Generates the directory structure for
                  the specified blueprint

    --uninstall   Removes the directory structure for
                  the specified blueprint

Examples:
    ./directory.sh valheim --install

    ./directory.sh terraria --uninstall
"
}

# Params
if [ $# -le 1 ]; then
  usage && exit 1
fi

# Check for KGSM_ROOT env variable
if [ -z "$KGSM_ROOT" ]; then
  echo "${0##*/} WARNING: KGSM_ROOT environmental variable not found, sourcing /etc/environment." >&2
  # shellcheck disable=SC1091
  source /etc/environment

  # If not found in /etc/environment
  if [ -z "$KGSM_ROOT" ]; then
    echo ">>> ${0##*/} ERROR: KGSM_ROOT environmental variable not found, exiting." >&2
    exit 1
  else
    echo "${0##*/} INFO: KGSM_ROOT found in /etc/environment, consider rebooting the system" >&2

    # Check if KGSM_ROOT is exported
    if ! declare -p KGSM_ROOT | grep -q 'declare -x'; then
      export KGSM_ROOT
    fi
  fi
fi

# Trap CTRL-C
trap "echo "" && exit" INT

BLUEPRINT=$1

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
      printf ">>> ${0##*/} ERROR: Failed to create %s\n" "$dir" >&2
      exit 1
    fi
  done
}

function _uninstall() {
  # Remove main working directory
  if ! rm -rf "$SERVICE_WORKING_DIR"; then
    echo ">>> ${0##*/} ERROR: Failed to remove $SERVICE_WORKING_DIR" >&2
    exit 1
  fi
}

#Read the argument values
while [ $# -gt 0 ]; do
  case "$2" in
  -h | --help)
    usage && exit 1
    shift
    ;;
  --install)
    _install
    shift
    ;;
  --uninstall)
    _uninstall
    shift
    ;;
  *)
    shift
    ;;
  esac
  shift
done
