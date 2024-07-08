#!/bin/bash

function usage() {
  echo "Will download a server into \$SERVICE_TEMP_DIR
It will look for an override if it's available, otherwise it will use the
default SteamCMD download.

Usage:
    ./${0##*/} [-b | --blueprint] <bp> [-v | --version] <v>

Options:
    -b --blueprint <bp>   Name of the blueprint file.
                          The .bp extension in the name is optional

    -v --version <v>      Optional: Version number to download.
                          This feature is not currently used

    -h --help             Prints this message

Examples:
    ./${0##*/} -b valheim

    ./${0##*/} --blueprint terraria -v 1449
"
}

set -eo pipefail

# shellcheck disable=SC2199
if [[ $@ =~ "--debug" ]]; then
  export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
  set -x
fi

if [ "$#" -eq 0 ]; then usage && exit 1; fi

VERSION=0

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
  -v | --version)
    shift
    VERSION=$1
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
STEAMCMD_SCRIPT="$(find "$KGSM_ROOT" -type f -name steamcmd.sh)"
OVERRIDES_SCRIPT="$(find "$KGSM_ROOT" -type f -name overrides.sh)"
VERSION_SCRIPT="$(find "$KGSM_ROOT" -type f -name version.sh)"

# shellcheck disable=SC1090
source "$BLUEPRINT_SCRIPT" "$BLUEPRINT" || exit 1

# shellcheck disable=SC1090
source "$STEAMCMD_SCRIPT" "$BLUEPRINT" || exit 1

# If no version is passed, just fetch the latest
if [ "$VERSION" -eq 0 ]; then
  VERSION=$("$VERSION_SCRIPT" -b "$SERVICE_NAME" --latest)
fi

# Calls SteamCMD to handle the download
function func_download() {
  # shellcheck disable=SC2034
  local version=$1
  local dest=$2

  steamcmd_download "$version" "$dest"
  return $?
}

# shellcheck disable=SC1090
source "$OVERRIDES_SCRIPT" "$SERVICE_NAME" || exit 1

func_download "$VERSION" "$SERVICE_TEMP_DIR" && exit $?
