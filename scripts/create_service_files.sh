#!/bin/bash

# Params
if [ $# -eq 0 ]; then
  echo ">>> ERROR: Service name not supplied. Run script like this: ./${0##*/} \"SERVICE\"" >&2
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

BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"

# shellcheck disable=SC1091
source /etc/environment

# shellcheck disable=SC1090
source "$BLUEPRINT_SCRIPT" "$SERVICE" || exit 1

# These don't exist yet, just creating a path for later creation
SERVICE_FILE="$SERVICE_SERVICE_DIR/$SERVICE_NAME.service"
SOCKET_FILE="$SERVICE_SERVICE_DIR/$SERVICE_NAME.socket"

function createBaseService() {
  sudo touch "$SERVICE_FILE"

  cat >"$SERVICE_FILE" <<-EOF
[Unit]
Description=$SERVICE_NAME

[Service]
User=$USER
WorkingDirectory=$SERVICE_WORKING_DIR
ExecStart=$SERVICE_MANAGE_SCRIPT_FILE --start
ExecStop=$SERVICE_MANAGE_SCRIPT_FILE --stop
NonBlocking=true

Restart=on-failure
RestartSec=5
StartLimitBurst=1

[Install]
WantedBy=multi-user.target
EOF
}

function createBaseServiceWithSocket() {
  sudo touch "$SERVICE_FILE"

  cat >"$SERVICE_FILE" <<-EOF
[Unit]
Description=${SERVICE_NAME^} Dedicated Server
Requires=$SERVICE_NAME.socket

[Service]
User=$USER
WorkingDirectory=$SERVICE_WORKING_DIR
ExecStart=$SERVICE_MANAGE_SCRIPT_FILE --start
ExecStop=$SERVICE_MANAGE_SCRIPT_FILE --stop
NonBlocking=true

Restart=on-failure
RestartSec=5
StartLimitBurst=1

Sockets=$SERVICE_NAME.socket
StandardInput=socket
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
}

function createBaseSocket() {
  sudo touch "$SOCKET_FILE"

  cat >"$SOCKET_FILE" <<-EOF
[Unit]
Description=Socket for $SERVICE_NAME.stdin
PartOf=$SERVICE_NAME.service

[Socket]
ListenFIFO=$SERVICE_WORKING_DIR/$SERVICE_NAME.stdin
EOF
}

if [ "$SERVICE_USES_INPUT_SOCKET" != "1" ]; then
  createBaseService
else
  createBaseServiceWithSocket
  createBaseSocket
fi
