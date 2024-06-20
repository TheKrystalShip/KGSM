#!/bin/bash

function usage() {
  echo "Will download a server into \$SERVICE_TEMP_DIR
It will look for an override if it's available, otherwise it will use the
default SteamCMD download.

Usage:
    ./download.sh <blueprint>

Options:
    blueprint     Name of the blueprint file.
                  The .bp extension in the name is optional

    -h --help     Prints this message

Examples:
    ./download.sh valheim

    ./download.sh terraria
"
}

if [ $# -eq 0 ] || [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
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
VERSION=${2:-0}

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
  VERSION=$("$VERSION_SCRIPT" "$SERVICE_NAME")
fi

# Calls SteamCMD to handle the download
function func_download() {
  # shellcheck disable=SC2034
  local version=$1
  local dest=$2

  steamcmd_download "$version" "$dest"
}

# shellcheck disable=SC1090
source "$OVERRIDES_SCRIPT" "$SERVICE_NAME" || exit 1

func_download "$VERSION" "$SERVICE_TEMP_DIR"
