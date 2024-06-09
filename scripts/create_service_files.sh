#!/bin/bash

# Params
if [ $# -eq 0 ]; then
  echo ">>> ERROR: Blueprint name not supplied. Run script like this: ./${0##*/} \"BLUEPRINT\"" >&2
  exit 1
fi

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

BLUEPRINT=$1

BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"

# shellcheck disable=SC1090
source "$BLUEPRINT_SCRIPT" "$BLUEPRINT" || exit 1

SERVICE_TEMPLATE_FILE="$(find "$KGSM_ROOT" -type f -name service.tp)"
SOCKET_TEMPLATE_FILE="$(find "$KGSM_ROOT" -type f -name socket.tp)"

# These don't exist yet, just creating a path for later creation
SERVICE_OUTPUT_FILE="$SERVICE_SERVICE_DIR/$SERVICE_NAME.service"
SOCKET_OUTPUT_FILE="$SERVICE_SERVICE_DIR/$SERVICE_NAME.socket"

if ! eval "cat <<EOF
$(<"$SERVICE_TEMPLATE_FILE")
EOF
" >"$SERVICE_OUTPUT_FILE" 2>/dev/null; then
  echo ">>> ERROR: Could not copy $SERVICE_TEMPLATE_FILE to $SERVICE_OUTPUT_FILE" >&2
  exit 1
fi

if ! eval "cat <<EOF
$(<"$SOCKET_TEMPLATE_FILE")
EOF
" >"$SOCKET_OUTPUT_FILE" 2>/dev/null; then
  echo ">>> ERROR: Could not copy $SOCKET_TEMPLATE_FILE to $SOCKET_OUTPUT_FILE" >&2
  exit 1
fi
