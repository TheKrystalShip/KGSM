#!/usr/bin/env bash

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

function usage() {
  echo "Used to fetch various version informations.

Usage:
  $(basename "$0") [-i | --instance <instance>] OPTION

Options:
  -h, --help                  Prints this message
  -i, --instance <instance>   Full name of the instance, equivalent of
                              INSTANCE_FULL_NAME from the instance config file
                              The .ini extension is not required
    --installed               Prints the currently installed version
    --latest                  Prints the latest version available
    --compare                 Compares the latest version available with
                              the currently installed version. If the latest
                              available version is different than the installed
                              version then it prints the latest version
    --save <version>          Save the given version

Exit codes:
  0: Success / New version was found, written to stdout
  1: Error / No new version found
  2: Other error

Examples:
  $(basename "$0") -i valheim-3596 --installed
  $(basename "$0") --instance terraria-4759.ini --latest
  $(basename "$0") -i 7dtd-379158.ini --compare
  $(basename "$0") --instance minecraft-1945 --save 1.20.1
"
}

debug=
# shellcheck disable=SC2199
if [[ $@ =~ "--debug" ]]; then
  debug=" --debug"
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

instance_config_file=$(__load_instance "$instance")
# shellcheck disable=SC1090
source "$instance_config_file" || exit $EC_FAILED_SOURCE

# Read the argument values
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --compare)
      "$INSTANCE_MANAGE_FILE" --version --compare $debug
      ;;
    --installed)
      "$INSTANCE_MANAGE_FILE" --version --installed $debug
      ;;
    --latest)
      "$INSTANCE_MANAGE_FILE" --version --latest $debug
      ;;
    --save)
      shift
      if [[ -z "$1" ]]; then
        __print_error "Missing argument <version>"
        exit $EC_MISSING_ARG
      fi

      "$INSTANCE_MANAGE_FILE" --version --save "$1" $debug
      ;;
    *)
      __print_error "Invalid argument $1"
      exit $EC_INVALID_ARG
      ;;
  esac
  shift
done

exit $?
