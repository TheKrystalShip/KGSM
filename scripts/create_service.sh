#!/bin/bash

if [ $# -eq 0 ]; then
    help
    exit 1
fi

# if [[ $EUID -ne 0 ]]; then
#     echo "This script must be run as root"
#     exit 1
# fi

SERVICE_NAME=""
SERVICE_PORT=0
REQUIRES_INPUT_SOCKET=0

function help() {
    printf "Launch script with: --name NAME --port PORT [--input-socket]\n"
    printf "\n"
    printf "\t--name NAME\t\tThe name of the service, preferably in lowercase with no empty spaces\n"
    printf "\n"
    printf "\t--port PORT\t\tThe port the service will use\n"
    printf "\n"
    printf "\t[--input-socket]\tOptional: Add this flag if the service uses a socket file for stdin\n"
    printf "\n"
    printf "\t--help\t\t\tPrints this message\n"
}

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

function init() {
    printf "Name: %s\n" "$SERVICE_NAME"
    printf "Port: %d\n" "$SERVICE_PORT"

    if [ $REQUIRES_INPUT_SOCKET -eq 1 ]; then
        createBaseServiceWithSocket
        createBaseSocket
    else
        createBaseService
    fi

    printf "Created service files:\n"
    printf "\t%s\n" "$SERVICE_FILE"

    if [ $REQUIRES_INPUT_SOCKET -eq 1 ]; then
        printf "\t%s\n" "$SOCKET_FILE"
    fi

    printf "\n"
}

#Read the argument values
while [ $# -gt 0 ]; do
    case "$1" in
    --help)
        help
        exit 0
        ;;
    --name)
        SERVICE_NAME="$2"
        shift
        ;;
    --port)
        SERVICE_PORT="$2"
        shift
        ;;
    --input-socket)
        REQUIRES_INPUT_SOCKET=1
        shift
        ;;
    *)
        shift
        ;;
    esac
    shift
done

BASE_DIR="/opt/$SERVICE_NAME/service"

SERVICE_FILE="$BASE_DIR/$SERVICE_NAME.service"
SOCKET_FILE="$BASE_DIR/$SERVICE_NAME.socket"

init
