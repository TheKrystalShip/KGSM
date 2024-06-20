#!/bin/bash

function usage() {
  echo "Used to fetch different version information for a service.
It can be used to read the locally installed version, fetch the latest available
and/or compare the two to determine if an update is available.

Usage:
    ./version.sh <blueprint> <option>

Options:
    blueprint     Name of the blueprint file.
                  The .bp extension in the name is optional

    -h --help     Prints this message

    --installed   Prints the currently installed version

    --latest      Prints the latest version available

    --compare     Compares the latest version available with
                  the currently installed version. If the latest
                  available version is different than the installed
                  version then it prints it

Exit codes:
    0: Success / New version was found, written to stdout

    1: Error / No new version found

    2: Other error

Examples:
    ./version.sh valheim --installed

    ./version.sh terraria --latest

    ./version.sh 7dtd --compare
"
}

if [ $# -eq 0 ] || [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  usage && exit 2
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

COMPARE_WITH_INSTALLED_VERSION=0
PRINT_INSTALLED_VERSION=0
GET_LATEST_VERSION=0

#Read the argument values
while [[ "$#" -gt 0 ]]; do
  case $2 in
  --compare)
    COMPARE_WITH_INSTALLED_VERSION=1
    shift
    ;;
  --installed)
    PRINT_INSTALLED_VERSION=1
    shift
    ;;
  --latest)
    GET_LATEST_VERSION=1
    shift
    ;;
  *)
    shift
    ;;
  esac
  shift
done

COMMON_SCRIPT="$(find "$KGSM_ROOT" -type f -name common.sh)"
BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"
STEAMCMD_SCRIPT="$(find "$KGSM_ROOT" -type f -name steamcmd.sh)"
OVERRIDES_SCRIPT="$(find "$KGSM_ROOT" -type f -name overrides.sh)"

# shellcheck disable=SC1090
source "$COMMON_SCRIPT" || exit 1

# shellcheck source=/dev/null
source "$BLUEPRINT_SCRIPT" "$BLUEPRINT" || exit 1

# shellcheck disable=SC1090
source "$STEAMCMD_SCRIPT" "$BLUEPRINT" || exit 1

function func_get_latest_version() {
  steamcmd_get_latest_version
}

# shellcheck disable=SC1090
source "$OVERRIDES_SCRIPT" "$BLUEPRINT" || exit 1

if [ "$PRINT_INSTALLED_VERSION" -eq 1 ]; then
  echo -n "$SERVICE_INSTALLED_VERSION"
  exit 0
fi

if [ "$COMPARE_WITH_INSTALLED_VERSION" -eq 1 ]; then
  latest_version=$(func_get_latest_version)

  # Check if not empty
  if [ -n "$latest_version" ]; then
    if [ "$latest_version" == "$SERVICE_INSTALLED_VERSION" ]; then
      exit 1
    fi
  else
    exit 1
  fi

  echo -n "$latest_version"
fi

if [ "$GET_LATEST_VERSION" -eq 1 ]; then
  latest_version=$(func_get_latest_version)

  # Check if not empty
  if [ -n "$latest_version" ]; then
    echo -n "$latest_version"
  else
    exit 1
  fi
fi
