#!/bin/bash

function usage() {
  echo "Used to fetch different version information for a service.
It can be used to read the locally installed version, fetch the latest
available, compare the two to determine if an update is available and/or
save a new version for a specific blueprint.

Usage:
    ./${0##*/} [-b | --blueprint] <bp> <option>

Options:
    -b --blueprint <bp>   Name of the blueprint file, this has to be the first
                          parameter.
                          (The .bp extension in the name is optional)

    -h --help             Prints this message

    --installed           Prints the currently installed version

    --latest              Prints the latest version available

    --compare             Compares the latest version available with
                          the currently installed version. If the latest
                          available version is different than the installed
                          version then it prints it

    --save <version>      Save the given version

Exit codes:
    0: Success / New version was found, written to stdout

    1: Error / No new version found

    2: Other error

Examples:
    ./${0##*/} -b valheim --installed

    ./${0##*/} --blueprint terraria --latest

    ./${0##*/} -b 7dtd --compare

    ./${0##*/} --blueprint minecraft --save 1.20.1
"
}

# Read the argument values
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
  echo "${0##*/} WARNING: KGSM_ROOT not found, sourcing /etc/environment." >&2
  # shellcheck disable=SC1091
  source /etc/environment

  # If not found in /etc/environment
  if [ -z "$KGSM_ROOT" ]; then
    echo "${0##*/} ERROR: KGSM_ROOT not found, exiting." >&2
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

COMMON_SCRIPT="$(find "$KGSM_ROOT" -type f -name common.sh)"
BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"
STEAMCMD_SCRIPT="$(find "$KGSM_ROOT" -type f -name steamcmd.sh)"
OVERRIDES_SCRIPT="$(find "$KGSM_ROOT" -type f -name overrides.sh)"

# shellcheck disable=SC1090
source "$COMMON_SCRIPT" || exit 1

# shellcheck source=/dev/null
source "$BLUEPRINT_SCRIPT" "$BLUEPRINT" || exit 1

# shellcheck source=/dev/null
source "$STEAMCMD_SCRIPT" "$BLUEPRINT" || exit 1

function func_get_latest_version() {
  latest_version=$(steamcmd_get_latest_version)

  # Check if not empty
  if [ -n "$latest_version" ]; then
    echo -n "$latest_version"
    return 0
  else
    return 1
  fi
}

function _compare() {
  # shellcheck disable=SC2155
  local latest_version=$(func_get_latest_version)

  if [ -n "$latest_version" ]; then
    if [ "$latest_version" == "$SERVICE_INSTALLED_VERSION" ]; then
      return 1
    fi
  else
    return 1
  fi

  echo -n "$latest_version"
  return 0
}

# shellcheck disable=SC1090
source "$OVERRIDES_SCRIPT" "$BLUEPRINT"

ret=0

# Read the argument values
while [[ "$#" -gt 0 ]]; do
  case $1 in
  --compare)
    _compare || ret=$?
    shift
    ;;
  --installed)
    echo -n "$SERVICE_INSTALLED_VERSION"
    exit 0
    ;;
  --latest)
    func_get_latest_version || ret=$?
    shift
    ;;
  --save)
    shift
    echo "$1" >"$SERVICE_VERSION_FILE"
    exit 0
    ;;
  *)
    echo "${0##*/} ERROR: Invalid argument $1" >&2
    usage && exit 1
    ;;
  esac
done

exit "$ret"
