#!/bin/bash

################################################################################
# Main file: /opt/scripts/update.sh
#
# These are the functions available in the main script that can be overwritten.
# Each function should write it's output to the corresponding var
#
# func_get_latest_version
# func_download
# func_create_backup
# func_deploy
#
# Available global vars:
#
# EXITSTATUS_SUCCESS
# EXITSTATUS_ERROR
# GLOBAL_SCRIPTS_DIR
# GLOBAL_VERSION_CHECK_FILE
# BASE_DIR
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
  # Fetch latest version
  # shellcheck disable=SC2155
  local newest_version_full_name=$(curl -s 'https://terraria.org/api/get/dedicated-servers-names' | python3 -c "import sys, json; print(json.load(sys.stdin)[0])")
  # Expected: terraria-server-1449.zip
  IFS='-' read -r -a new_version_unformatted <<<"$newest_version_full_name "
  local temp=${new_version_unformatted[2]}
  # Expected: 1449.zip

  IFS='.' read -r -a version_number <<<"$temp"
  local newest_version=${version_number[0]}
  # Expected: 1449

  echo "$newest_version"
}

############################################################################
# INPUT:
# - $1: Version
############################################################################
function func_download() {
  local version=$1

  # If no version is given, get the latest
  if [ -z "$version" ]; then
    version=$(func_get_latest_version)
  fi

  # Download zip file in $SERVICE_TEMP_DIR
  if ! wget -P "$SERVICE_TEMP_DIR" "https://terraria.org/api/download/pc-dedicated-server/terraria-server-${version}.zip"; then
    echo ">>> ERROR: wget https://terraria.org/api/download/pc-dedicated-server/terraria-server-${version}.zip"
    return "$EXITSTATUS_ERROR"
  fi

  # Extract zipped contents in the same $SERVICE_TEMP_DIR
  if ! unzip "$SERVICE_TEMP_DIR"/"terraria-server-${version}.zip" -d "$SERVICE_TEMP_DIR"; then
    echo ">>> ERROR: unzip terraria-server-${version}.zip -d $SERVICE_TEMP_DIR"
    return "$EXITSTATUS_ERROR"
  fi

  # Remove zip file
  if ! rm "$SERVICE_TEMP_DIR"/"terraria-server-${version}.zip"; then
    echo ">>> ERROR: 'rm terraria-server-${version}.zip'"
    return "$EXITSTATUS_ERROR"
  fi

  # Terraria extracts with the version name as the base folder, we don't want that
  if ! mv -v "$SERVICE_TEMP_DIR"/"$version"/* "$SERVICE_TEMP_DIR"/; then
    echo ">>> ERROR: mv -v $SERVICE_TEMP_DIR/$version/* $SERVICE_TEMP_DIR/"
    return "$EXITSTATUS_ERROR"
  fi

  # Remove trailing empty folder
  if ! rm -rf "${SERVICE_TEMP_DIR:?}"/"$version"; then
    echo ">>> ERROR: rm -rf $SERVICE_TEMP_DIR/$version"
    return "$EXITSTATUS_ERROR"
  fi

  # Terraria server comes in 3 subfolders for Windows, Mac & Linux
  # Only want the contents of the Linux folder, so move all of that outside
  if ! mv -v "$SERVICE_TEMP_DIR"/Linux/* "$SERVICE_TEMP_DIR"/; then
    echo ">>> ERROR: mv -v $SERVICE_TEMP_DIR/Linux/* $SERVICE_INSTALL_DIR/"
    return "$EXITSTATUS_ERROR"
  fi

  # Remove the Windows dir
  if ! rm -rf "${SERVICE_TEMP_DIR:?}"/Windows; then
    echo ">>> ERROR: rm -rf ${SERVICE_TEMP_DIR:?}/Windows"
    return "$EXITSTATUS_ERROR"
  fi

  # Remove the Mac dir
  if ! rm -rf "${SERVICE_TEMP_DIR:?}"/Mac; then
    echo ">>> ERROR: rm -rf ${SERVICE_TEMP_DIR:?}/Mac"
    return "$EXITSTATUS_ERROR"
  fi

  # Remove the empty Linux dir
  if ! rm -rf "${SERVICE_TEMP_DIR:?}"/Linux; then
    echo ">>> ERROR: rm -rf ${SERVICE_TEMP_DIR:?}/Linux"
    return "$EXITSTATUS_ERROR"
  fi

  return "$EXITSTATUS_SUCCESS"
}

function func_deploy() {
  # Just move everything from the SERVICE_TEMP_DIR dir to SERVICE_INSTALL_DIR
  if ! mv -v "$SERVICE_TEMP_DIR"/* "$SERVICE_INSTALL_DIR"/; then
    echo ">>> ERROR: mv -v $SERVICE_TEMP_DIR/* $SERVICE_INSTALL_DIR/"
    return "$EXITSTATUS_ERROR"
  fi

  if ! chmod +x "$SERVICE_INSTALL_DIR"/TerrariaServer*; then
    echo ">>> ERROR: chmod +x $SERVICE_INSTALL_DIR/TerrariaServer*"
    return "$EXITSTATUS_ERROR"
  fi

  # Remove everything else left behind in $SERVICE_TEMP_DIR
  if ! rm -rf "${SERVICE_TEMP_DIR:?}"/*; then
    echo ">>> ERROR: rm -rf ${SERVICE_TEMP_DIR:?}/*"
    return "$EXITSTATUS_ERROR"
  fi

  # Config file must be in the same dir as executable, copy it
  if ! cp "$SERVICE_CONFIG_DIR"/* "$SERVICE_INSTALL_DIR"/; then
    echo ">>> ERROR: cp $SERVICE_CONFIG_DIR/* $SERVICE_INSTALL_DIR/"
    return "$EXITSTATUS_ERROR"
  fi

  return "$EXITSTATUS_SUCCESS"
}
