#!/usr/bin/env bash

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

function usage() {
  echo "Manages instance creation and gathers information post-creation

Usage:
  $(basename "$0") OPTION

Options:
  -h, --help                      Prints this message

  --list [blueprint]              Prints a list of all instances.
  --list --detailed [blueprint]   Print a list with detailed information about
                                  instances.
  --list --json [blueprint]       Prints a JSON formatted list of instances
  --list --json --detailed        Print a list with detailed information of
      [blueprint]                 instances.
                                  Optionally a blueprint name can be provided
                                  to show only instances of that blueprint.
  --status <instance>             Return a detailed running status.
  --save <instance>               Issue the save command to the instance.
  --input <command>               Issue a command to the instance if it has an
                                  interactive console. Displays the last 10
                                  lines of the instance log after issuing the
                                  command.
  --create <blueprint>
    --install-dir <install_dir>   Creates a new instance for the given blueprint
                                  and returns the name of the instance config
                                  file.
                                  <blueprint> The blueprint file to create an
                                  instance from.
                                  <install_dir> Directory where the instance
                                  will be created.
    --id <identifier>             Optional: Specify an instance identifier
                                  instead of using an auto-generated one.
  --remove <instance>             Remove an instance's configuration
  --info <instance>               Print a detailed description of an instance
  --info <instance> --json        Print a detailed description of an instance in
                                  JSON format.

Examples:
  $(basename "$0") --create factorio.bp --id factorio-01 --install-dir /opt
  $(basename "$0") --status factorio-01
  $(basename "$0") --list --detailed factorio.bp
"
}

debug=
# shellcheck disable=SC2199
if [[ $@ =~ "--debug" ]]; then
  debug="--debug"
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

[[ $# -eq 0 ]] && usage && exit 1

# Read the argument values
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -h | --help)
      usage && exit 0
      ;;
    *)
      break
      ;;
  esac
done

SELF_PATH="$(dirname "$(readlink -f "$0")")"

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

function __create_container_instance() {

  # Temp file with some instance information needed to create the rest
  # of the instance files
  local temp_file_with_data="$1"
  local blueprint_abs_path="$2"

  # The docker-compose.yml file will contain placeholders that need to be
  # replaced with their corresponding values.
  # Some of these could be paths, ports, names, etc.
  # We need to treat the blueprint file as a template, load it, render it
  # and then saved the rendered file to the instances directory.

  echo "$blueprint_abs_path"
}
