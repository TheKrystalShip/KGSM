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
################################################################################
#
# Available global vars:
#
# INSTANCE_ID
# INSTANCE_NAME
# INSTANCE_FULL_NAME
# INSTANCE_WORKING_DIR
# INSTANCE_INSTALL_DIR
# INSTANCE_SAVES_DIR
# INSTANCE_TEMP_DIR
# INSTANCE_BACKUPS_DIR
# INSTANCE_LOGS_DIR
# INSTANCE_INSTALL_DATETIME
# INSTANCE_BLUEPRINT_FILE
# INSTANCE_LEVEL_NAME
# INSTANCE_PORT
# INSTANCE_LAUNCH_BIN
# INSTANCE_LAUNCH_ARGS
# INSTANCE_LIFECYCLE_MANAGER
# INSTANCE_MANAGE_FILE
# INSTANCE_INSTALLED_VERSION
#
# (Optional) INSTANCE_STOP_COMMAND
# (Optional) INSTANCE_SAVE_COMMAND
# (Optional) INSTANCE_PID_FILE
# (Optional) INSTANCE_OVERRIDES_FILE
# (Optional) INSTANCE_UFW_FILE
# (Optional) INSTANCE_SYSTEMD_SERVICE_FILE
# (Optional) INSTANCE_SYSTEMD_SOCKET_FILE
################################################################################

# INPUT:
# - void
#
# OUTPUT:
# - 0: Success (echo "$new_version")
# - 1: Error
function func_get_latest_version() {
  wget -qO - 'https://terraria.org/api/get/dedicated-servers-names' | jq .[0] | cut -d '-' -f3 | cut -d '.' -f1
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
  if ! wget -qO "$dest/terraria-server-${version}.zip" "https://terraria.org/api/download/pc-dedicated-server/terraria-server-${version}.zip"; then
    echo "${0##*/} ERROR: wget https://terraria.org/api/download/pc-dedicated-server/terraria-server-${version}.zip" >&2 && return 1
  fi

  # Extract zipped contents in the same $dest
  if ! unzip -q "$dest/terraria-server-${version}.zip" -d "$dest"; then
    echo "${0##*/} ERROR: unzip terraria-server-${version}.zip -d $dest" >&2 && return 1
  fi

  # Remove zip file
  if ! rm "$dest"/"terraria-server-${version}.zip"; then
    echo "${0##*/} ERROR: 'rm terraria-server-${version}.zip'" >&2 && return 1
  fi

  # Terraria extracts with the version name as the base folder, we don't want that
  if ! mv "$dest"/"$version"/* "$dest"/; then
    echo "${0##*/} ERROR: mv $dest/$version/* $dest/" >&2 && return 1
  fi

  # Remove trailing empty folder
  if ! rm -rf "${dest:?}"/"$version"; then
    echo "${0##*/} ERROR: rm -rf $dest/$version" >&2 && return 1
  fi

  # Terraria server comes in 3 subfolders for Windows, Mac & Linux
  # Only want the contents of the Linux folder, so move all of that outside
  if ! mv "$dest"/Linux/* "$dest"/; then
    echo "${0##*/} ERROR: mv $dest/Linux/* $$dest/" >&2 && return 1
  fi

  # Remove the Windows dir
  if ! rm -rf "${dest:?}"/Windows; then
    echo "${0##*/} ERROR: rm -rf ${dest:?}/Windows" >&2 && return 1
  fi

  # Remove the Mac dir
  if ! rm -rf "${dest:?}"/Mac; then
    echo "${0##*/} ERROR: rm -rf ${dest:?}/Mac" >&2 && return 1
  fi

  # Remove the empty Linux dir
  if ! rm -rf "${dest:?}"/Linux; then
    echo "${0##*/} ERROR: rm -rf ${dest:?}/Linux" >&2 && return 1
  fi

  return 0
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
  if ! mv "$source"/* "$dest"/; then
    echo "${0##*/} ERROR: mv $source/* $dest/" >&2 && return 1
  fi

  if ! chmod +x "$dest"/TerrariaServer*; then
    echo "${0##*/} ERROR: chmod +x $dest/TerrariaServer*" >&2 && return 1
  fi

  # Remove everything else left behind in $source
  if ! rm -rf "${source:?}"/*; then
    echo "${0##*/} ERROR: rm -rf ${source:?}/*" >&2 && return 1
  fi

  return 0
}
