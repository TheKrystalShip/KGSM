#!/bin/bash

################################################################################
# Script to check if a new version of a game has been released, comparing it
# to the currently running version on the server.
#
# INPUT: Service name
#
# OUTPUT:
# - Exit Code 0: New version found, written to STDOUT
# - Exit Code 1: No new version
# - Exit Code X: Other error, check output
################################################################################

# Params
if [ $# -eq 0 ]; then
  echo ">>> ERROR: Service name not supplied. Run script like this: ./${0##*/} \"SERVICE\""
  exit 1
fi

if [ -z "$KGSM_ROOT" ] && [ -z "$KGSM_ROOT_FOUND" ]; then
  echo "WARNING: KGSM_ROOT environmental variable not found, sourcing /etc/environment." >&2
  # shellcheck disable=SC1091
  source /etc/environment

  if [ -z "$KGSM_ROOT" ]; then
    echo ">>> ERROR: KGSM_ROOT environmental variable not found, exiting." >&2
    exit 1
  else
    if [ -z "$KGSM_ROOT_FOUND" ]; then
      echo "INFO: KGSM_ROOT found in /etc/environment, consider rebooting the system" >&2
      export KGSM_ROOT_FOUND=1
    fi
  fi
fi

SERVICE=$1

COMMON_SCRIPT="$(find "$KGSM_ROOT" -type f -name common.sh)"
BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"
VERSION_SCRIPT="$(find "$KGSM_ROOT" -type f -name version.sh)"

# shellcheck disable=SC1091
source /etc/environment

# shellcheck disable=SC1090
source "$COMMON_SCRIPT" || exit 1

# shellcheck disable=SC1090
source "$BLUEPRINT_SCRIPT" "$SERVICE" || exit 1

# shellcheck disable=SC2155
latest_version=$("$VERSION_SCRIPT" "$SERVICE")

if [ "$latest_version" == "$SERVICE_INSTALLED_VERSION" ]; then
  exit 1
fi

echo "$latest_version" | tr -d '\n'
