#!/bin/bash

################################################################################
# Uncomment and use any of the following functions, they will be called from
# other scripts at various stages of the install/update/backup/setup process.
################################################################################
#
# Brief description of each:
#
# func_get_latest_version       Should always return the latest available
#                               version, or EXITSTATUS_ERROR in case there's
#                               any problem fetching the latest version nr.
#
# func_download                 In charge of downloading all the required files
#                               for the service, extract any zips, move, copy,
#                               rename, remove, etc. It should leave the
#                               SERVICE_TEMP_DIR with a fully working setup that
#                               can be called and executed as if it was a full
#                               install.
#
# func_deploy                   Will move everything from the SERVICE_TEMP_DIR
#                               into SERVICE_INSTALL_DIR, do any more cleanup
#                               that couldn't be done by func_download.
#
# func_create_backup            The default implementation will simply move all
#                               content from SERVICE_INSTALL_DIR into a new
#                               directory created under SERVICE_BACKUPS_DIR.
#                               The naming of the new directory is not used for
#                               any sort of automation, so it can be set to
#                               anything, but it should be descriptive enough
#                               to understand when the backup was made and what
#                               it contains.
#
# func_restore_backup           Responsible for restoring an existing backup
#                               back into a functioning state, and moved into
#                               SERVICE_INSTALL_DIR ready to use.
#
# func_setup                    Will set up any system config needed in order to
#                               run the service, like systemd files, firewall
#                               rules or anything else that's needed.
#
################################################################################
#
# Available global vars:
#
# EXITSTATUS_SUCCESS
# EXITSTATUS_ERROR
#
# SERVICE_NAME
# SERVICE_WORKING_DIR
# SERVICE_INSTALLED_VERSION
# SERVICE_APP_ID
# SERVICE_STEAM_AUTH_LEVEL
# IS_STEAM_GAME # 0 (false), 1 (true)
# SERVICE_BACKUPS_DIR
# SERVICE_CONFIG_DIR
# SERVICE_INSTALL_DIR
# SERVICE_SAVES_DIR
# SERVICE_SERVICE_DIR
# SERVICE_TEMP_DIR
#
# SERVICE_OVERRIDES_SCRIPT_FILE
# SERVICE_MANAGE_SCRIPT_FILE
################################################################################

# INPUT:
# - void
#
# OUTPUT:
# - 0: Success (echo "$new_version")
# - 1: Error
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

# INPUT:
# - $1: Version
# - $2: Destination directory, absolute path
#
# OUTPUT:
# - 0: Success
# - 1: Error
function func_download() {
  local version=$1
  local dest=$2

  # If no version is given, get the latest
  if [ -z "$version" ]; then
    version=$(func_get_latest_version)
  fi

  # Download zip file in $dest
  if ! wget -P "$dest" "https://terraria.org/api/download/pc-dedicated-server/terraria-server-${version}.zip"; then
    echo ">>> ERROR: wget https://terraria.org/api/download/pc-dedicated-server/terraria-server-${version}.zip"
    return "$EXITSTATUS_ERROR"
  fi

  # Extract zipped contents in the same $dest
  if ! unzip "$dest"/"terraria-server-${version}.zip" -d "$dest"; then
    echo ">>> ERROR: unzip terraria-server-${version}.zip -d $dest"
    return "$EXITSTATUS_ERROR"
  fi

  # Remove zip file
  if ! rm "$dest"/"terraria-server-${version}.zip"; then
    echo ">>> ERROR: 'rm terraria-server-${version}.zip'"
    return "$EXITSTATUS_ERROR"
  fi

  # Terraria extracts with the version name as the base folder, we don't want that
  if ! mv -v "$dest"/"$version"/* "$dest"/; then
    echo ">>> ERROR: mv -v $dest/$version/* $dest/"
    return "$EXITSTATUS_ERROR"
  fi

  # Remove trailing empty folder
  if ! rm -rf "${dest:?}"/"$version"; then
    echo ">>> ERROR: rm -rf $dest/$version"
    return "$EXITSTATUS_ERROR"
  fi

  # Terraria server comes in 3 subfolders for Windows, Mac & Linux
  # Only want the contents of the Linux folder, so move all of that outside
  if ! mv -v "$dest"/Linux/* "$dest"/; then
    echo ">>> ERROR: mv -v $dest/Linux/* $$dest/"
    return "$EXITSTATUS_ERROR"
  fi

  # Remove the Windows dir
  if ! rm -rf "${dest:?}"/Windows; then
    echo ">>> ERROR: rm -rf ${dest:?}/Windows"
    return "$EXITSTATUS_ERROR"
  fi

  # Remove the Mac dir
  if ! rm -rf "${dest:?}"/Mac; then
    echo ">>> ERROR: rm -rf ${dest:?}/Mac"
    return "$EXITSTATUS_ERROR"
  fi

  # Remove the empty Linux dir
  if ! rm -rf "${dest:?}"/Linux; then
    echo ">>> ERROR: rm -rf ${dest:?}/Linux"
    return "$EXITSTATUS_ERROR"
  fi

  return "$EXITSTATUS_SUCCESS"
}

# INPUT:
# - $1: Source directory, absolute path
# - $2: Destination directory, absolute path
#
# OUTPUT:
# - 0: Success
# - 1: Error
function func_deploy() {
  local source=$1
  local dest=$2

  # Just move everything from the source dir to dest
  if ! mv -v "$source"/* "$dest"/; then
    echo ">>> ERROR: mv -v $source/* $dest/"
    return "$EXITSTATUS_ERROR"
  fi

  if ! chmod +x "$dest"/TerrariaServer*; then
    echo ">>> ERROR: chmod +x $dest/TerrariaServer*"
    return "$EXITSTATUS_ERROR"
  fi

  # Remove everything else left behind in $source
  if ! rm -rf "${source:?}"/*; then
    echo ">>> ERROR: rm -rf ${source:?}/*"
    return "$EXITSTATUS_ERROR"
  fi

  # Config file must be in the same dir as executable, copy it
  if ! cp "$SERVICE_CONFIG_DIR"/* "$dest"/; then
    echo ">>> ERROR: cp $SERVICE_CONFIG_DIR/* $dest/"
    return "$EXITSTATUS_ERROR"
  fi

  return "$EXITSTATUS_SUCCESS"
}
