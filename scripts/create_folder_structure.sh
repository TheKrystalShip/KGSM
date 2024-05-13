#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Launch script with: --name NAME"
    exit 1
fi

SERVICE_NAME="unset"
BASE_DIR=/opt
MANAGE_SCRIPT_EXAMPLE_PATH=/opt/scripts/manage.sh.example

function init() {
    for dir in $DIR_ARRAY; do
        if ! mkdir "$dir"; then
            printf ">>> ERROR: Failed to create %s" "$dir"
        exit 1
    fi
    done

    # Copy the manage.sh script
    if ! cp "$MANAGE_SCRIPT_EXAMPLE_PATH" "$MANAGE_SCRIPT_PATH"; then
        printf ">>> ERROR: Failed to copy %s to %s" "$MANAGE_SCRIPT_EXAMPLE_PATH" "$MANAGE_SCRIPT_PATH"
        exit 1
    fi

    # Ensure the manage.sh script file has execution permissions
    if ! chmod +x "$MANAGE_SCRIPT_PATH"; then
        printf ">>> ERROR: Failed to assign +x permissions to %s file" "$MANAGE_SCRIPT_PATH"
        exit 1
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

DIR_ARRAY=("$BACKUP_DIR" "$CONFIG_DIR" "$INSTALL_DIR" "$SAVES_DIR" "$TEMP_DIR" "$SERVICE_DIR")

init
