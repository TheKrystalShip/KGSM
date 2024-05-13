#!/bin/bash

################################################################################
# Main file: /opt/scripts/update.sh
#
# These are the functions available in the main script that can be overwritten.
# Each function should write it's output to the corresponding var
#
# func_get_latest_version        => func_get_latest_version_result
# func_download                  => func_download_result
# func_get_service_status        => func_get_service_status_result
# func_create_backup             => func_create_backup_result
# func_deploy                    => func_deploy_result
# func_restore_service_state     => func_restore_service_state_result
# func_update_version            => func_update_version_result
#
# Available global vars:
#
# EXITSTATUS_SUCCESS
# EXITSTATUS_ERROR
# DB_FILE
# SERVICE_NAME
# SERVICE_WORKING_DIR
# SERVICE_INSTALLED_VERSION
# SERVICE_APP_ID
# IS_STEAM_GAME
# BASE_DIR
# GLOBAL_SCRIPTS_DIR
# GLOBAL_VERSION_CHECK_FILE
# SERVICE_LATEST_DIR
# SERVICE_TEMP_DIR
# SERVICE_BACKUPS_FOLDER
################################################################################

function func_get_latest_version() {
  # Get new version
  new_version="asdasdasd"

  if [ -n "$new_version" ]; then
    func_get_latest_version_result="$new_version"
  else
    func_get_latest_version_result="$EXITSTATUS_ERROR"
  fi
}

function func_download() {
  ############################################################################
  # INPUT:
  # - $1: Version
  ############################################################################
  # https://download.veloren.net/latest/linux/x86_64/weekly
  local version=$1
  func_download_result="$EXITSTATUS_ERROR"

  # Download new version in $SERVICE_TEMP_DIR

  # Download zip file in $SERVICE_TEMP_DIR
  if ! wget -P "$SERVICE_TEMP_DIR" "https://download.veloren.net/latest/linux/x86_64/weekly"; then
    echo ">>> ERROR: wget https://download.veloren.net/latest/linux/x86_64/weekly"
    return
  fi

  # Extract zipped contents in the same $SERVICE_TEMP_DIR
  if ! unzip "$SERVICE_TEMP_DIR"/weekly -d "$SERVICE_TEMP_DIR"; then
    echo ">>> ERROR: unzip weekly -d $SERVICE_TEMP_DIR"
    return
  fi

  # Remove zip file
  if ! rm "$SERVICE_TEMP_DIR"/weekly; then
    echo ">>> ERROR: 'rm weekly'"
    return
  fi

  func_download_result="$EXITSTATUS_SUCCESS"
}
