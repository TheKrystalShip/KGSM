#!/bin/bash

if [ $# -eq 0 ]; then
  echo ">>> ERROR: Service name not supplied. Run script like this: ./${0##*/} \"SERVICE\""
  exit 1
fi

# shellcheck disable=SC1091
source /etc/environment

if [ -z "$KGSM_ROOT" ]; then
  echo ">>> ERROR: KGSM_ROOT environmental variable not set, exiting."
  exit 1
fi

SERVICE=$1

COMMON_SCRIPT="$(find "$KGSM_ROOT" -type f -name common.sh)"
BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"
MANAGE_TEMPLATE_FILE="$(find "$KGSM_ROOT" -type f -name manage.tp)"
MANAGE_SOCKET_TEMPLATE_FILE="$(find "$KGSM_ROOT" -type f -name manage.socket.tp)"

# shellcheck disable=SC1090
source "$COMMON_SCRIPT" || exit 1

# shellcheck disable=SC1090
source "$BLUEPRINT_SCRIPT" "$SERVICE" || exit 1

# If service requires socket, load manage.socket.tp instead
if [ "$SERVICE_USES_INPUT_SOCKET" != "0" ]; then
  MANAGE_TEMPLATE_FILE="$MANAGE_SOCKET_TEMPLATE_FILE"
fi

# MANAGE_TEMPLATE_FILE expects a $WORKING_DIR var
# shellcheck disable=SC2034
WORKING_DIR="$SERVICE_WORKING_DIR"

# Create manage.sh from template and put it in $SERVICE_MANAGE_SCRIPT_FILE
sudo touch "$SERVICE_MANAGE_SCRIPT_FILE"

if ! eval "cat <<EOF
$(<"$MANAGE_TEMPLATE_FILE")
EOF
" >"$SERVICE_MANAGE_SCRIPT_FILE" 2>/dev/null; then
  echo ">>> ERROR: Could not copy $MANAGE_TEMPLATE_FILE to $SERVICE_MANAGE_SCRIPT_FILE"
  exit 1
fi

if ! chmod +x "$SERVICE_MANAGE_SCRIPT_FILE"; then
  echo ">>> ERROR: Failed to add +x permission to $SERVICE_MANAGE_SCRIPT_FILE"
  exit 2
fi
