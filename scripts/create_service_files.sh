#!/bin/bash

# Params
if [ $# -eq 0 ]; then
    echo ">>> ERROR: Service name not supplied. Run script like this: ./${0##*/} \"SERVICE\""
    exit 1
fi

SERVICE=$1

# shellcheck disable=SC1091
source /opt/scripts/service_vars.sh "$SERVICE"

BASE_DIR="/opt/$SERVICE_NAME/service"

SERVICE_FILE="$BASE_DIR/$SERVICE_NAME.service"
SOCKET_FILE="$BASE_DIR/$SERVICE_NAME.socket"

function createBaseService() {
    printf "Creating %s...\n" "$SERVICE_FILE"

    cat >"$SERVICE_FILE" <<-EOF
[Unit]
Description=${SERVICE_NAME^} Dedicated Server

[Service]
User=$USER
WorkingDirectory=/opt/$SERVICE_NAME
ExecStart=/opt/$SERVICE_NAME/manage.sh --start
ExecStop=/opt/$SERVICE_NAME/manage.sh --stop
NonBlocking=true

Restart=on-failure
RestartSec=5
StartLimitBurst=1

[Install]
WantedBy=multi-user.target
EOF
}

function createBaseServiceWithSocket() {
    printf "Creating %s...\n" "$SERVICE_FILE"

    cat >"$SERVICE_FILE" <<-EOF
[Unit]
Description=${SERVICE_NAME^} Dedicated Server
Requires=$SERVICE_NAME.socket

[Service]
User=$USER
WorkingDirectory=/opt/$SERVICE_NAME
ExecStart=/opt/$SERVICE_NAME/manage.sh --start
ExecStop=/opt/$SERVICE_NAME/manage.sh --stop
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
    printf "Creating %s...\n" "$SOCKET_FILE"

    cat >"$SOCKET_FILE" <<-EOF
[Unit]
Description=Socket for $SERVICE_NAME.stdin
PartOf=$SERVICE_NAME.service

[Socket]
ListenFIFO=/opt/$SERVICE_NAME/$SERVICE_NAME.stdin
EOF
}

createBaseService
