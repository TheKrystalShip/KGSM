#!/bin/bash

################################################################################
# Script to check if a new version of a game has been released, comparing it
# to the currently running version on the server.
# Will work for all steam games and also custom games not on steam
# (provided they offer a script to check for new releases).
#
# INPUT:
# - Must provide a service name (must match the name in the DB, folder name,
#   service file name, etc.)
#
# OUTPUT:
# - Exit Code 0: New version found, written to STDOUT
# - Exit Code 1: No new version
# - Exit Code 2: Other error, check output
#
# DB table schema for reference
#┌──┬────┬───────────┬─────────────────┬──────┐
#│0 | 1  | 2         | 3               | 4    │
#├──┼────┼───────────┼─────────────────┼──────┤
#|id|name|working_dir|installed_version|app_id|
#└──┴────┴───────────┴─────────────────┴──────┘
################################################################################

# Params
if [ $# -eq 0 ]; then
    echo "ERROR: Service name not supplied"
    exit 2
fi

SERVICE=$1
export DB_FILE="/home/$USER/servers/info.db"

export EXITSTATUS_SUCCESS=0
export EXITSTATUS_ERROR=1

# Select the entire row, each service only has one row so no need to check
# for multiple rows being returned
result=$(sqlite3 "$DB_FILE" "SELECT * from services WHERE name = '$SERVICE'")

if [ -z "$result" ]; then
    echo "ERROR: Didn't get any result back from DB, exiting"
    exit 2
fi

# Result is a string with all values glued together by a | character, split
IFS='|' read -r -a COLS <<<"$result"

if [ -z "${COLS[0]}" ]; then
    echo "ERROR: Failed to parse result, exiting"
    exit 2
fi

# $COLS is now an array, all indexes match the DB schema described above.
export SERVICE_NAME="${COLS[1]}"
export SERVICE_WORKING_DIR="${COLS[2]}"
export SERVICE_INSTALLED_VERSION="${COLS[3]}"
export SERVICE_APP_ID="${COLS[4]}"

# 0 (false), 1 (true)
# shellcheck disable=SC2155
export IS_STEAM_GAME=$(
    ! [ "$SERVICE_APP_ID" != "0" ]
    echo $?
)

# Install dir
export SERVICE_INSTALL_DIR="$SERVICE_WORKING_DIR"/install
export SERVICE_TEMP_DIR="$SERVICE_WORKING_DIR"/temp
export SERVICE_BACKUPS_DIR="$SERVICE_WORKING_DIR"/backups
export SERVICE_CONFIG_DIR="$SERVICE_WORKING_DIR"/config
export SERVICE_SAVES_DIR="$SERVICE_WORKING_DIR"/saves

export SERVICE_CUSTOM_SCRIPTS_FILE="$SERVICE_WORKING_DIR/custom_scripts.sh"

export run_get_latest_version_result="$EXITSTATUS_ERROR"

function run_steam_version_check() {
    run_get_latest_version_result=$(steamcmd +login anonymous +app_info_update 1 +app_info_print "$SERVICE_APP_ID" +quit | tr '\n' ' ' | grep --color=NEVER -Po '"branches"\s*{\s*"public"\s*{\s*"buildid"\s*"\K(\d*)')
}

function run_custom_version_check() {
    if ! test -f "$SERVICE_CUSTOM_SCRIPTS_FILE"; then
        echo "ERROR: No custom_scripts file found for $SERVICE_NAME, exiting"
        exit "$EXITSTATUS_ERROR"
    fi

    # Custom file exists, source it
    # shellcheck source=/dev/null
    source "$SERVICE_CUSTOM_SCRIPTS_FILE"

    if ! type -t run_get_latest_version >/dev/null; then
        echo "Error: No custom version check function found, exiting"
        exit "$EXITSTATUS_ERROR"
    fi

    run_get_latest_version
}

if [ "$IS_STEAM_GAME" -eq '1' ]; then
    run_steam_version_check
else
    run_custom_version_check
fi

if [ "$run_get_latest_version_result" != "$SERVICE_INSTALLED_VERSION" ]; then
    echo "$run_get_latest_version_result" | tr -d '\n'
    exit "$EXITSTATUS_SUCCESS"
fi

exit "$EXITSTATUS_ERROR"
