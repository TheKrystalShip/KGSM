#!/bin/bash

function usage() {
  echo "Runs the uninstall process for a given blueprint.
This will remove the systemd *.service & *.socket files, disable the UFW rule
and remove any remaining directories and files on the system.

Usage:
    ./uninstall.sh <blueprint>

Options:
    blueprint     Name of the blueprint file.
                  The .bp extension in the name is optional

    -h --help     Prints this message

Examples:
    ./uninstall.sh valheim

    ./uninstall.sh terraria
"
}

if [ $# -eq 0 ]; then
  usage && exit 1
fi

#Read the argument values
while [ $# -gt 0 ]; do
  case "$1" in
  -h | --help)
    usage && exit 0
    shift
    ;;
  *)
    shift
    ;;
  esac
  shift
done

# Check for KGSM_ROOT env variable
if [ -z "$KGSM_ROOT" ]; then
  echo "WARNING: KGSM_ROOT environmental variable not found, sourcing /etc/environment." >&2
  # shellcheck disable=SC1091
  source /etc/environment

  # If not found in /etc/environment
  if [ -z "$KGSM_ROOT" ]; then
    echo ">>> ERROR: KGSM_ROOT environmental variable not found, exiting." >&2
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

BLUEPRINT=$1

COMMON_SCRIPT="$(find "$KGSM_ROOT" -type f -name common.sh)"
BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"
DIRECTORY_SCRIPT="$(find "$KGSM_ROOT" -type f -name directory.sh)"
SYSTEMD_SCRIPT="$(find "$KGSM_ROOT" -type f -name systemd.sh)"
FIREWALL_SCRIPT="$(find "$KGSM_ROOT" -type f -name firewall.sh)"

# shellcheck disable=SC1090
source "$COMMON_SCRIPT" || exit 1

# Check if blueprint ends with .bp extension. If not, add it
if [[ "$BLUEPRINT" != *.bp ]]; then
  BLUEPRINT="${BLUEPRINT}.bp"
fi

# shellcheck disable=SC1090
source "$BLUEPRINT_SCRIPT" "$BLUEPRINT" || exit 1

"$DIRECTORY_SCRIPT" "$SERVICE_NAME" --uninstall || exit 1
sudo "$SYSTEMD_SCRIPT" "$SERVICE_NAME" --uninstall || exit 1
sudo "$FIREWALL_SCRIPT" "$SERVICE_NAME" --uninstall || exit 1
# "$CREATE_MANAGE_FILE_SCRIPT" "$SERVICE_NAME" || exit 1
# "$CREATE_OVERRIDES_FILE_SCRIPT" "$SERVICE_NAME" || exit 1
