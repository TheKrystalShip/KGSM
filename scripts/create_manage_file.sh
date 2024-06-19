#!/bin/bash

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

# Trap CTRL-C
trap "echo "" && exit" INT

BLUEPRINT=$1

COMMON_SCRIPT="$(find "$KGSM_ROOT" -type f -name common.sh)"
BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"
MANAGE_TEMPLATE_FILE="$(find "$KGSM_ROOT" -type f -name manage.tp)"

# shellcheck disable=SC1090
source "$COMMON_SCRIPT" || exit 1

# shellcheck disable=SC1090
source "$BLUEPRINT_SCRIPT" "$BLUEPRINT" || exit 1

# MANAGE_TEMPLATE_FILE expects a $WORKING_DIR var
# shellcheck disable=SC2034
WORKING_DIR="$SERVICE_WORKING_DIR"

# Prepend "./" to $SERVICE_LAUNCH_BIN if it doesn't start with "./" or "/"
if [[ "$SERVICE_LAUNCH_BIN" != \.\/* ]] && [[ "$SERVICE_LAUNCH_BIN" != \/* ]]; then
  SERVICE_LAUNCH_BIN="./$SERVICE_LAUNCH_BIN"
fi

# Create manage.sh from template and put it in $SERVICE_MANAGE_SCRIPT_FILE
if ! eval "cat <<EOF
$(<"$MANAGE_TEMPLATE_FILE")
EOF
" >"$SERVICE_MANAGE_SCRIPT_FILE" 2>/dev/null; then
  echo ">>> ERROR: Could not copy $MANAGE_TEMPLATE_FILE to $SERVICE_MANAGE_SCRIPT_FILE" >&2
  exit 1
fi

if ! chmod +x "$SERVICE_MANAGE_SCRIPT_FILE"; then
  echo ">>> ERROR: Failed to add +x permission to $SERVICE_MANAGE_SCRIPT_FILE" >&2
  exit 2
fi
