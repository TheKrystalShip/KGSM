#!/usr/bin/env bash

function usage() {
  echo "Scaffolds the necessary directory structure.

Usage:
  $(basename "$0") [-i | --instance <instance>] OPTION

Options:
  -h, --help                  Prints this message
  -i, --instance <instance>   instance_name from the instance config file.
                              The .ini extension is not required
    --create                  Generates the directory structure
    --remove                  Removes the directory structure

Examples:
  $(basename "$0") -i valheim-h1up6V --create
  $(basename "$0") --instance valheim-h1up6V --remove
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
  module_common="$(find "$KGSM_ROOT/modules" -type f -name common.sh -print -quit)"
  [[ -z "$module_common" ]] && echo "${0##*/} ERROR: Failed to load module common.sh" >&2 && exit 1
  # shellcheck disable=SC1090
  source "$module_common" || exit 1
fi

instance_config_file=$(__find_instance_config "$instance")
# shellcheck disable=SC1090
source "$instance_config_file" || exit "$EC_FAILED_SOURCE"

# Check if instance_working_dir is set
if [[ -z "$instance_working_dir" ]]; then
  __print_error "instance_working_dir is not set in the instance config file $instance_config_file"
  exit $EC_INVALID_CONFIG
fi

# Ensure instance_working_dir is an absolute path
if [[ ! "$instance_working_dir" = /* ]]; then
  __print_error "instance_working_dir must be an absolute path, got: $instance_working_dir"
  exit $EC_INVALID_CONFIG
fi

declare -A DIR_ARRAY=(
  ["instance_working_dir"]="$instance_working_dir"
  ["instance_backups_dir"]="${instance_working_dir}/backups"
  ["instance_install_dir"]="${instance_working_dir}/install"
  ["instance_saves_dir"]="${instance_working_dir}/saves"
  ["instance_temp_dir"]="${instance_working_dir}/temp"
  ["instance_logs_dir"]="${instance_working_dir}/logs"
)

function _create() {

  # shellcheck disable=SC2154
  __print_info "Creating directories for instance ${instance_name}"

  for dir_key in "${!DIR_ARRAY[@]}"; do

    local dir_value="${DIR_ARRAY[$dir_key]}"

    __create_dir "$dir_value"

    __add_or_update_config "$instance_config_file" "$dir_key" \""$dir_value"\" "instance_working_dir" || {
      __print_error "Failed to add or update $dir_key in $instance_config_file"
      return $?
    }
  done

  __emit_instance_directories_created "${instance%.ini}"

  __print_success "Directories created successfully for instance ${instance_name}"

  return 0
}

function _remove() {
  # Remove main working directory
  # This will also remove all subdirectories
  if ! rm -rf "${instance_working_dir?}"; then
    __print_error "Failed to remove $instance_working_dir"
    return $EC_FAILED_RM
  fi

  __emit_instance_directories_removed "${instance%.ini}"

  return 0
}

# Read the argument values
while [ $# -gt 0 ]; do
  case "$1" in
  --create)
    _create
    exit $?
    ;;
  --remove)
    _remove
    exit $?
    ;;
  *)
    __print_error "Invalid argument $1"
    exit $EC_INVALID_ARG
    ;;
  esac
  shift
done
