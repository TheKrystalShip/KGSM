#!/bin/bash

if [ $# -eq 0 ]; then
    echo ">>> ERROR: SERVICE name not supplied. Run script like this: ./${0##*/} \"SERVICE\""
    exit 1
fi

SERVICE_NAME=$1

declare -a DIR_ARRAY=(
    "/opt/$SERVICE_NAME"
    "/opt/$SERVICE_NAME/backups"
    "/opt/$SERVICE_NAME/config"
    "/opt/$SERVICE_NAME/install"
    "/opt/$SERVICE_NAME/saves"
    "/opt/$SERVICE_NAME/temp"
    "/opt/$SERVICE_NAME/service"
)

function init() {
    for dir in "${DIR_ARRAY[@]}"; do
        # "mkdir -p" is crucial, see https://linux.die.net/man/1/mkdir
        if ! mkdir -p "$dir"; then
            printf ">>> ERROR: Failed to create %s\n" "$dir"
            exit 1
        fi
    done
    exit 0
}

init
