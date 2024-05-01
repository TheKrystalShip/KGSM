#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Launch script with: --name NAME"
    exit 1
fi

SERVICE_NAME="unset"
BASE_DIR="/home/cristian/servers"
MANAGE_SCRIPT_EXAMPLE_PATH="/home/cristian/servers/scripts/manage.sh.example"

function init() {
    if ! mkdir "$BACKUP_DIR"; then
        printf ">>> ERROR: Failed to create %s" "$BACKUP_DIR"
        exit 1
    fi

    if ! mkdir "$CONFIG_DIR"; then
        printf ">>> ERROR: Failed to create %s" "$CONFIG_DIR"
        exit 2
    fi

    if ! mkdir "$INSTALL_DIR"; then
        printf ">>> ERROR: Failed to create %s" "$INSTALL_DIR"
        exit 3
    fi

    if ! mkdir "$SAVES_DIR"; then
        printf ">>> ERROR: Failed to create %s" "$SAVES_DIR"
        exit 4
    fi

    if ! mkdir "$TEMP_DIR"; then
        printf ">>> ERROR: Failed to create %s" "$TEMP_DIR"
        exit 5
    fi

    if ! mkdir "$SERVICE_DIR"; then
        printf ">>> ERROR: Failed to create %s" "$SERVICE_DIR"
        exit 5
    fi

    if ! cp "$MANAGE_SCRIPT_EXAMPLE_PATH" "$MANAGE_SCRIPT_PATH"; then
        printf ">>> ERROR: Failed to copy %s to %s" "$MANAGE_SCRIPT_EXAMPLE_PATH" "$MANAGE_SCRIPT_PATH"
        exit 6
    fi

    exit 0
}

#Read the argument values
while [ $# -gt 0 ]; do
    case "$1" in
    --name)
        SERVICE_NAME="$2"
        shift
        ;;
    *)
        shift
        ;;
    esac
    shift
done

BACKUP_DIR="$BASE_DIR/$SERVICE_NAME/backups"
CONFIG_DIR="$BASE_DIR/$SERVICE_NAME/config"
INSTALL_DIR="$BASE_DIR/$SERVICE_NAME/install"
SAVES_DIR="$BASE_DIR/$SERVICE_NAME/saves"
TEMP_DIR="$BASE_DIR/$SERVICE_NAME/temp"
SERVICE_DIR="$BASE_DIR/$SERVICE_NAME/service"
MANAGE_SCRIPT_PATH="$BASE_DIR/$SERVICE_NAME"/manage.sh

init
