#!/bin/bash

################################################################################
# Creates all common SERVICE vars
#
# INPUT:
# - Service name
#
# OUTPUT:
# - DB_FILE
# - SERVICE_NAME
# - SERVICE_WORKING_DIR
# - SERVICE_INSTALLED_VERSION
# - SERVICE_APP_ID
# - IS_STEAM_GAME
# - SERVICE_BACKUPS_DIR
# - SERVICE_CONFIG_DIR
# - SERVICE_INSTALL_DIR
# - SERVICE_SAVES_DIR
# - SERVICE_SERVICE_DIR
# - SERVICE_TEMP_DIR
# - SERVICE_CUSTOM_SCRIPTS_FILE
#
# DB table schema for reference
#┌──┬────┬───────────┬─────────────────┬──────┐
#│0 | 1  | 2         | 3               | 4    │
#├──┼────┼───────────┼─────────────────┼──────┤
#|id|name|working_dir|installed_version|app_id|
#└──┴────┴───────────┴─────────────────┴──────┘
################################################################################

SERVICE=$1

# shellcheck disable=SC1091
source /opt/scripts/db.sh

# Select the entire row, each service only has one row so no need to check
# for multiple rows being returned
result=$(db_get_all_by_name "$SERVICE")

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
export SERVICE_BACKUPS_DIR="$SERVICE_WORKING_DIR"/backups
export SERVICE_CONFIG_DIR="$SERVICE_WORKING_DIR"/config
export SERVICE_INSTALL_DIR="$SERVICE_WORKING_DIR"/install
export SERVICE_SAVES_DIR="$SERVICE_WORKING_DIR"/saves
export SERVICE_SERVICE_DIR="$SERVICE_WORKING_DIR"/service
export SERVICE_TEMP_DIR="$SERVICE_WORKING_DIR"/temp

export SERVICE_CUSTOM_SCRIPTS_FILE="$SERVICE_WORKING_DIR/custom_scripts.sh"
