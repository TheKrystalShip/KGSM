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

function func_get_latest_version() {
  # shellcheck disable=SC2034
  func_get_latest_version_result=$(curl -s 'https://factorio.com/api/latest-releases' | python3 -c "import sys, json; print(json.load(sys.stdin)['stable']['headless'])")
}

function func_download() {
  ############################################################################
  # INPUT:
  # - $1: New version
  ############################################################################
  # shellcheck disable=SC2034
  local version=$1
  func_download_result="$EXITSTATUS_ERROR"

  # Download new version in $SERVICE_TEMP_DIR
  local output_file="$SERVICE_TEMP_DIR/factorio_headless.tar.xz"

  if ! wget https://factorio.com/get-download/stable/headless/linux64 -O "$output_file"; then
    echo ">>> ERROR: wget https://factorio.com/get-download/stable/headless/linux64 -O $output_file"
    return
  fi

  if ! tar -xf "$output_file" --strip-components=1 -C "$SERVICE_TEMP_DIR"; then
    echo ">>> ERROR: tar -xf $output_file --strip-components=1 -C $SERVICE_TEMP_DIR"
    return
  fi

  if ! rm "$output_file"; then
    echo ">>> ERROR: rm $output_file"
    return
  fi

  # shellcheck disable=SC2034
  func_download_result="$EXITSTATUS_SUCCESS"
}
