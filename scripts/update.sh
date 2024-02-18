#!/bin/bash

################################################################################
# Script used for updating a game server.
# Steps:
#   1. Check if new version is available
#   2. Download new version in temporary folder
#   3. Create backup of running version
#   4. Deploy newly downloaded version
#   5. Restore service state
#   6. Update version number in DB
#
# INPUT:
# - Must provide a game name (must match the name in the DB, folder name,
#   service file name, etc.)
#
# OUTPUT:
# - Exit Code 0: Update successful
# - Exit Code 1-n: Error, check output
#
# DB table schema for reference
#┌──┬────┬───────────┬─────────────────┬──────┐
#│0 |1   |2          |3                |4     │
#├──┼────┼───────────┼─────────────────┼──────┤
#|id|name|working_dir|installed_version|app_id|
#└──┴────┴───────────┴─────────────────┴──────┘
################################################################################

################################################################################
# > Global vars
################################################################################

export EXITSTATUS_SUCCESS=0
export EXITSTATUS_ERROR=1

################################################################################
# > Init checks
################################################################################

if [ -z "$USER" ]; then
    echo ">>> ERROR: \$USER var not set, cannot run script without it. Exiting"
    exit "$EXITSTATUS_ERROR"
fi

# Params
if [ $# -eq 0 ]; then
    echo ">>> ERROR: Game name not supplied. Run script like this: ./${0##*/} \"GAME\""
    exit "$EXITSTATUS_ERROR"
fi

SERVICE_NAME=$1
export DB_FILE="/home/$USER/servers/info.db"

# Select the entire row, each service only has one row so no need to check
# for multiple rows being returned
result=$(sqlite3 "$DB_FILE" "SELECT * from services WHERE name = '${SERVICE_NAME//\'/\'\'}';")

if [ -z "$result" ]; then
    echo ">>> ERROR: Didn't get any result back from DB, exiting"
    exit "$EXITSTATUS_ERROR"
fi

# Result is a string with all values glued together by a | character, split
IFS='|' read -r -a COLS <<<"$result"

if [ -z "${COLS[0]}" ]; then
    echo ">>> ERROR: Failed to parse result, exiting"
    exit "$EXITSTATUS_ERROR"
fi

################################################################################
# > Service specific vars
################################################################################

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

export BASE_DIR=/home/"$USER"/servers
export GLOBAL_SCRIPTS_DIR="$BASE_DIR"/scripts
export GLOBAL_VERSION_CHECK_FILE="$BASE_DIR"/version_check.sh

# Install dir
export SERVICE_INSTALL_DIR="$SERVICE_WORKING_DIR"/install
if [ ! -d "$SERVICE_INSTALL_DIR" ]; then
    mkdir -p "$SERVICE_INSTALL_DIR"
fi

# Temp dir
export SERVICE_TEMP_DIR="$SERVICE_WORKING_DIR"/temp
if [ ! -d "$SERVICE_TEMP_DIR" ]; then
    mkdir -p "$SERVICE_TEMP_DIR"
fi

# Backup dir
export SERVICE_BACKUPS_DIR="$SERVICE_WORKING_DIR"/backups
if [ ! -d "$SERVICE_BACKUPS_DIR" ]; then
    mkdir -p "$SERVICE_BACKUPS_DIR"
fi

# Config dir
export SERVICE_CONFIG_DIR="$SERVICE_WORKING_DIR"/config
if [ ! -d "$SERVICE_CONFIG_DIR" ]; then
    mkdir -p "$SERVICE_CONFIG_DIR"
fi

# Saves dir
export SERVICE_SAVES_DIR="$SERVICE_WORKING_DIR"/saves
if [ ! -d "$SERVICE_SAVES_DIR" ]; then
    mkdir -p "$SERVICE_SAVES_DIR"
fi

export SERVICE_CUSTOM_SCRIPTS_FILE="$SERVICE_WORKING_DIR/custom_scripts.sh"

################################################################################
# > Function return vars
################################################################################

export run_get_latest_version_result="$EXITSTATUS_ERROR"
export run_download_result="$EXITSTATUS_ERROR"
export run_get_service_status_result="inactive" # active / inactive
export run_create_backup_result="$EXITSTATUS_ERROR"
export run_deploy_result="$EXITSTATUS_ERROR"
export run_restore_service_state_result="$EXITSTATUS_ERROR"
export run_update_version_result="$EXITSTATUS_ERROR"

################################################################################
# > Functions
################################################################################

function init() {

    # shellcheck disable=SC1091
    source "/etc/environment"

    echo "Update process started for $SERVICE_NAME."
    sleep 1

    ############################################################################
    #### Check for new version
    ############################################################################

    echo "1- Checking for new version..."
    run_get_latest_version "$SERVICE_NAME"

    if [ "$run_get_latest_version_result" -eq "$EXITSTATUS_ERROR" ]; then
        printf "\t>>> ERROR: No new version found, exiting.\n"
        exit "$EXITSTATUS_ERROR"
    fi

    printf "\tNew version found: %s\n" "$run_get_latest_version_result"
    sleep 1

    ############################################################################
    #### Download new version
    ############################################################################

    # Download new version in temp folder
    echo "2- Downloading version $run_get_latest_version_result..."

    run_download "$run_get_latest_version_result"

    if [ "$run_download_result" -eq "$EXITSTATUS_ERROR" ]; then
        printf "\t>>> ERROR: Failed to download new version, exiting.\n"
        exit "$EXITSTATUS_ERROR"
    fi

    printf "\tDownload completed\n"
    sleep 1

    ############################################################################
    #### Check if service is currently running and shut it down if needed
    ############################################################################

    echo "3- Checking service running status"
    run_get_service_status "$SERVICE_NAME"

    if [ "$run_get_service_status_result" = "active" ]; then
        printf "\tWARNING: Service currently running, shutting down first...\n"

        local service_shutdown_exit_code="$EXITSTATUS_ERROR"
        service_shutdown_exit_code=$(exec "$GLOBAL_SCRIPTS_DIR/stop.sh" "$SERVICE_NAME")

        if [ "$service_shutdown_exit_code" -eq "$EXITSTATUS_ERROR" ]; then
            printf "\t>>> ERROR: Failed to shutdown service, exiting\n"
            exit "$EXITSTATUS_ERROR"
        else
            printf "\tService shutdown complete, continuing\n"
        fi
    else
        printf "\tService status %s, continuing\n" "$run_get_service_status_result"
    fi

    sleep 1

    ############################################################################
    #### Backup existing install if it exists
    ############################################################################

    if [ -z "$(ls -A "$SERVICE_INSTALL_DIR")" ]; then
        # Dir is empty
        echo "4- No installation found, skipping backup step"
    else
        # Dir is not empty, backup exiting release
        echo "4- Creating backup of current version..."
        run_create_backup "$SERVICE_INSTALL_DIR"

        if [ "$run_create_backup_result" -eq "$EXITSTATUS_ERROR" ]; then
            printf "\t>>> ERROR: Failed to create backup, exiting.\n"
            exit "$EXITSTATUS_ERROR"
        fi

        printf "\tBackup complete in folder: %s\n" "$run_create_backup_result"
    fi

    sleep 1

    ############################################################################
    #### Deploy newly downloaded version
    ############################################################################

    echo "5- Deploying $run_get_latest_version_result..."

    run_deploy

    if [ "$run_deploy_result" -eq "$EXITSTATUS_ERROR" ]; then
        printf "\t>>> ERROR: Failed to deploy %s, exiting.\n" "$run_get_latest_version_result"
        exit "$EXITSTATUS_ERROR"
    fi

    printf "\tDeployment complete.\n"
    sleep 1

    ############################################################################
    #### Restore service state if needed
    ############################################################################

    if [ "$run_get_service_status_result" = "active" ]; then
        echo "5.5- Starting the service back up"

        run_restore_service_state "$SERVICE_NAME"
        if [ "$run_restore_service_state_result" -eq "$EXITSTATUS_ERROR" ]; then
            printf "\t>>> ERROR: Failed to restore service to running state, exiting.\n"
            exit "$EXITSTATUS_ERROR"
        fi

        printf "\tService started successfully\n"
    fi

    sleep 1

    ############################################################################
    #### Save the new installed version number
    ############################################################################

    run_update_version "$run_get_latest_version_result"

    if [ "$run_update_version_result" -eq "$EXITSTATUS_ERROR" ]; then
        printf "\t>>> ERROR: Failed to update version number in DB, however the update has been deployed\n"
    fi

    echo "6- Update finished, exiting"
    exit "$EXITSTATUS_SUCCESS"
}

function run_get_latest_version() {
    local service=$1
    local latest_version_available="$EXITSTATUS_ERROR"

    latest_version_available=$(exec "$GLOBAL_VERSION_CHECK_FILE" "$service")

    # $EXITSTATUS_ERROR if there's no new version.
    if [ "$latest_version_available" -eq "$EXITSTATUS_ERROR" ]; then
        run_get_latest_version_result="$EXITSTATUS_ERROR"
    else
        # New version number will be saved
        run_get_latest_version_result="$latest_version_available"
    fi
}

# function run_download() {
#     local version=$1
#     run_download_result="$EXITSTATUS_ERROR"

#     steamcmd +@sSteamCmdForcePlatformType linux +force_install_dir "$SERVICE_TEMP_DIR" +login "$STEAM_USERNAME" "$STEAM_PASSWORD" +app_update "$SERVICE_APP_ID" -beta none validate +quit
#     run_download_result=$?
# }

# Debugging, skip downloading
function run_download() {
    run_download_result="$EXITSTATUS_SUCCESS"
}

function run_get_service_status() {
    # Possible output: "active" / "inactive"
    run_get_service_status_result=$(exec "$GLOBAL_SCRIPTS_DIR/is-active.sh" "$SERVICE_NAME")
}

function run_create_backup() {
    # shellcheck disable=SC2155
    local datetime=$(exec date +"%Y-%m-%d%T")
    local output_dir="${SERVICE_BACKUPS_DIR}/${SERVICE_NAME}-${SERVICE_INSTALLED_VERSION}-${datetime}.backup"

    # Create backup folder if it doesn't exit
    if [ ! -d "$output_dir" ]; then
        if ! mkdir -p "$output_dir"; then
            printf "\tERROR: Error creating backup folder %s" "$output_dir"
            return
        fi
    fi

    if ! mv -v "$SERVICE_INSTALL_DIR"/* "$output_dir"/; then
        echo ">>> ERROR: Failed to move contents from $SERVICE_INSTALL_DIR into $output_dir"
        return
    fi

    run_create_backup_result="$output_dir"
}

function run_deploy() {
    # Ensure 'latest' folder actually exists
    if [ ! -d "$SERVICE_INSTALL_DIR" ]; then
        if ! mkdir -p "$SERVICE_INSTALL_DIR"; then
            echo ">>> ERROR: Error creating $SERVICE_INSTALL_DIR folder"
            return
        fi
    fi

    # Move everything from $SERVICE_TEMP_DIR into $SERVICE_INSTALL_DIR
    if ! mv -v "$SERVICE_TEMP_DIR"/* "$SERVICE_INSTALL_DIR"/; then
        echo ">>> ERROR: Failed to move contents from $SERVICE_TEMP_DIR into $SERVICE_INSTALL_DIR"
        return
    fi

    run_deploy_result="$EXITSTATUS_SUCCESS"
}

function run_restore_service_state() {
    run_restore_service_state_result=$(exec "$GLOBAL_SCRIPTS_DIR/start.sh" "$SERVICE_NAME")
}

function run_update_version() {
    # Save new version number in DB
    local version=$1
    local sql_script="UPDATE services \
                      SET installed_version = '${version}' \
                      WHERE name = '${SERVICE_NAME}';"

    sqlite3 "$DB_FILE" "$sql_script"
    run_update_version_result=$?
}

function run_ctrl_c() {
    # shellcheck disable=SC2317
    echo "*** Update process cancelled ***"
}

# Trap CTRL-C
trap run_ctrl_c INT

# Check if the game is from steam or not, check for a custom_scripts.sh
# file and if it exists, source it
if [ "$IS_STEAM_GAME" -eq "$EXITSTATUS_SUCCESS" ]; then
    # Dealing with a non-steam game, source the custom scripts
    printf "Non-Steam game detected, importing custom scripts file\n"

    if ! test -f "$SERVICE_CUSTOM_SCRIPTS_FILE"; then
        printf "\t>>> ERROR: Could not locate custom_scripts.sh file for %s, exiting.\n" "$SERVICE_NAME"
        exit "$EXITSTATUS_ERROR"
    fi

    # shellcheck source=/dev/null
    source "$SERVICE_CUSTOM_SCRIPTS_FILE"
fi

# Start the script
init
