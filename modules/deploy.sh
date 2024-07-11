#!/bin/bash

function usage() {
  echo "Moves the content of \$SERVICE_TEMP_DIR into \$SERVICE_INSTALL_DIR

Usage:
    ./${0##*/} [-b | --blueprint] <bp>

Options:
    -b --blueprint <bp>   Name of the blueprint file.
                          The .bp extension in the name is optional

    -h --help             Prints this message

Examples:
    ./${0##*/} -b valheim

    ./${0##*/} --blueprint terraria
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
    echo "ERROR: Invalid argument $1" >&2
    usage && exit 1
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
OVERRIDES_SCRIPT="$(find "$KGSM_ROOT" -type f -name overrides.sh)"

# shellcheck disable=SC1090
source "$BLUEPRINT_SCRIPT" "$BLUEPRINT" || exit 1

function func_deploy() {
  local source=$1
  local dest=$2

  # Check if $source is empty
  if [ -z "$(ls -A -I .gitignore "$source")" ]; then
    echo "WARNING: $source is empty, nothing to deploy. Exiting" >&2
    return 1
  fi

  # Check if $dest is empty
  if [ -n "$(ls -A -I .gitignore "$dest")" ]; then
    # $dest is not empty
    read -r -p "WARNING: $dest is not empty, continue? (y/n): " confirm && [[ $confirm == [yY] ]] || exit 1
  fi

  # Move everything from $source into $dest
  if ! mv "$source"/* "$dest"/; then
    echo "ERROR: Failed to move contents from $source into $dest" >&2
    return 1
  fi

  return 0
}

# shellcheck disable=SC1090
source "$OVERRIDES_SCRIPT" "$SERVICE_NAME" || exit 1

func_deploy "$SERVICE_TEMP_DIR" "$SERVICE_INSTALL_DIR" || exit $?

exit 0
