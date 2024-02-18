#!/bin/bash

################################################################################
# Main file: /home/$USER/servers/update.sh
#
# These are the functions available in the main script that can be overwritten.
# Each function should write it's output to the corresponding var
#
# run_get_latest_version        => run_get_latest_version_result
# run_download                  => run_download_result
# run_get_service_status        => run_get_service_status_result
# run_create_backup             => run_create_backup_result
# run_deploy                    => run_deploy_result
# run_restore_service_state     => run_restore_service_state_result
# run_update_version            => run_update_version_result
#
# Available global vars:
#
# EXITSTATUS_SUCCESS
# EXITSTATUS_ERROR
# GLOBAL_SCRIPTS_DIR
# GLOBAL_VERSION_CHECK_FILE
# BASE_DIR
# DB_FILE
# IS_STEAM_GAME
# SERVICE_NAME
# SERVICE_WORKING_DIR
# SERVICE_INSTALLED_VERSION
# SERVICE_APP_ID
# SERVICE_INSTALL_DIR
# SERVICE_TEMP_DIR
# SERVICE_BACKUPS_DIR
# SERVICE_CONFIG_DIR
# SERVICE_SAVES_DIR
################################################################################

run_get_latest_version() {
    # Fetch latest version
    local newest_version_full_name=$(curl -s 'https://terraria.org/api/get/dedicated-servers-names' | python3 -c "import sys, json; print(json.load(sys.stdin)[0])")
    # Expected: terraria-server-1449.zip
    IFS='-' read -r -a new_version_unformatted <<<"$newest_version_full_name "
    local temp=${new_version_unformatted[2]}
    # Expected: 1449.zip

    IFS='.' read -r -a version_number <<<"$temp"
    local newest_version=${version_number[0]}
    # Expected: 1449

    run_get_latest_version_result="$newest_version"
}

run_download() {
    ############################################################################
    # INPUT:
    # - $1: Version
    ############################################################################
    local version=$1
    run_download_result="$EXITSTATUS_ERROR"

    # Download zip file in $SERVICE_TEMP_DIR
    if ! wget -P "$SERVICE_TEMP_DIR" "https://terraria.org/api/download/pc-dedicated-server/terraria-server-${version}.zip"; then
        echo ">>> ERROR: wget https://terraria.org/api/download/pc-dedicated-server/terraria-server-${version}.zip"
        return
    fi

    # Extract zipped contents in the same $SERVICE_TEMP_DIR
    if ! unzip "$SERVICE_TEMP_DIR"/"terraria-server-${version}.zip" -d "$SERVICE_TEMP_DIR"; then
        echo ">>> ERROR: unzip terraria-server-${version}.zip -d $SERVICE_TEMP_DIR"
        return
    fi

    # Remove zip file
    if ! rm "$SERVICE_TEMP_DIR"/"terraria-server-${version}.zip"; then
        echo ">>> ERROR: 'rm terraria-server-${version}.zip'"
        return
    fi

    # Terraria extracts with the version name as the base folder, we don't want that
    if ! mv -v "$SERVICE_TEMP_DIR"/"$version"/* "$SERVICE_TEMP_DIR"/; then
        echo ">>> ERROR: mv -v $SERVICE_TEMP_DIR/$version/* $SERVICE_TEMP_DIR/"
        return
    fi

    # Remove trailing empty folder
    if ! rm -rf "${SERVICE_TEMP_DIR:?}"/"$version"; then
        echo ">>> ERROR: rm -rf $SERVICE_TEMP_DIR/$version"
        return
    fi

    run_download_result="$EXITSTATUS_SUCCESS"
}

function run_deploy() {

    # Terraria server comes in 3 subfolders for Windows, Mac & Linux
    if ! mv -v "$SERVICE_TEMP_DIR"/Linux/* "$SERVICE_INSTALL_DIR"/; then
        echo ">>> ERROR: mv -v $SERVICE_TEMP_DIR/Linux/* $SERVICE_INSTALL_DIR/"
        return
    fi

    if ! chmod +x "$SERVICE_INSTALL_DIR"/TerrariaServer*; then
        echo ">>> ERROR: chmod +x $SERVICE_INSTALL_DIR/TerrariaServer*"
        return
    fi

    # Remove everything else left behind in $SERVICE_TEMP_DIR
    if ! rm -rf "${SERVICE_TEMP_DIR:?}"/*; then
        echo ">>> ERROR: rm -rf ${SERVICE_TEMP_DIR:?}/*"
        return
    fi

    # Config file must be in the same dir as executable, copy it
    if ! cp "$SERVICE_CONFIG_DIR"/* "$SERVICE_INSTALL_DIR"/; then
        echo ">>> ERROR: cp $SERVICE_CONFIG_DIR/* $SERVICE_INSTALL_DIR/"
        return
    fi

    run_deploy_result=$EXITSTATUS_SUCCESS
}
