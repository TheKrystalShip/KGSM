#!/bin/bash

function usage() {
  echo "Scaffolds the necessary directory structure.

Usage:
  $(basename "$0") [-i | --instance <instance>] OPTION

Options:
  -h, --help                  Prints this message
  -i, --instance <instance>   Full name of the instance, equivalent of
                              INSTANCE_FULL_NAME from the instance config file
                              The .ini extension is not required
    --create                  Generates the directory structure
    --remove                  Removes the directory structure

Examples:
  $(basename "$0") -i valheim-h1up6V --create
  $(basename "$0") --instance valheim-h1up6V.ini --remove
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
  CONFIG_FILE="$(find "$KGSM_ROOT" -type f -name config.ini -print -quit)"
  [[ -z "$CONFIG_FILE" ]] && echo "${0##*/} ERROR: Failed to load config.ini file" >&2 && exit 1
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

declare -A DIR_ARRAY=(
  ["INSTANCE_WORKING_DIR"]=$INSTANCE_WORKING_DIR
  ["INSTANCE_BACKUPS_DIR"]=$INSTANCE_WORKING_DIR/backups
  ["INSTANCE_INSTALL_DIR"]=$INSTANCE_WORKING_DIR/install
  ["INSTANCE_SAVES_DIR"]=$INSTANCE_WORKING_DIR/saves
  ["INSTANCE_TEMP_DIR"]=$INSTANCE_WORKING_DIR/temp
  ["INSTANCE_LOGS_DIR"]=$INSTANCE_WORKING_DIR/logs
)

function _create() {
  for dir in "${!DIR_ARRAY[@]}"; do
    if ! mkdir -p "${DIR_ARRAY[$dir]}"; then __print_error "Failed to create $dir" && return 1; fi
    if grep -q "^$dir" <"$instance_config_file"; then
      # If it exists, modify in-place
      sed -i "/$dir=*/c$dir=${DIR_ARRAY[$dir]}" "$instance_config_file" >/dev/null
    else
      # If it doesn't exist, append after INSTANCE_WORKING_DIR
      # IMPORTANT: Needs to be appended after INSTANCE_WORKING_DIR in order for
      # INSTANCE_LAUNCH_ARGS to be able to pick them up, the order matters.
      # Do not append to EOF
      sed -i -e '/INSTANCE_WORKING_DIR=/a\' -e "$dir=${DIR_ARRAY[$dir]}" "$instance_config_file" >/dev/null
    fi
  done

  return 0
}

function _remove() {
  # Remove main working directory
  if ! rm -rf "${INSTANCE_WORKING_DIR?}"; then
    __print_error "Failed to remove $INSTANCE_WORKING_DIR" && return 1
  fi

  return 0
}

# Read the argument values
while [ $# -gt 0 ]; do
  case "$1" in
  --create)
    _create; exit $?
    ;;
  --remove)
    _remove; exit $?
    ;;
  *)
    __print_error "Invalid argument $1" && exit 1
    ;;
  esac
  shift
done
