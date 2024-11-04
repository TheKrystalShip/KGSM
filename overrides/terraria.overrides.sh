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

  local download_url="https://terraria.org/api/download/pc-dedicated-server/terraria-server-${version}.zip"
  local dest_file="${dest}/terraria-server-${version}.zip"

  # Download zip file in $dest
  if ! wget -qO "$dest_file" "$download_url"; then
    __print_error "wget -qO $dest_file $download_url" && return 1
  fi

  # Extract zipped contents in the same $dest
  if ! unzip -q "$dest_file" -d "$dest"; then
    __print_error "unzip -q $dest_file -d $dest" && return 1
  fi

  # Remove zip file
  if ! rm "$dest_file"; then
    __print_error "rm $dest_file" && return 1
  fi

  # Terraria extracts with the version name as the base folder, we don't want that
  if ! mv "$dest"/"$version"/* "$dest"/; then
    __print_error "mv $dest/$version/* $dest/" && return 1
  fi

  # Remove trailing empty folder
  if ! rm -rf "${dest:?}"/"$version"; then
    __print_error "rm -rf $dest/$version" && return 1
  fi

  # Terraria server comes in 3 subfolders for Windows, Mac & Linux
  # Only want the contents of the Linux folder, so move all of that outside
  if ! mv "$dest"/Linux/* "$dest"/; then
    __print_error "mv $dest/Linux/* $dest/" && return 1
  fi

  # Remove the Windows dir
  if ! rm -rf "${dest:?}"/Windows; then
    __print_error "rm -rf ${dest:?}/Windows" && return 1
  fi

  # Remove the Mac dir
  if ! rm -rf "${dest:?}"/Mac; then
    __print_error "rm -rf ${dest:?}/Mac" && return 1
  fi

  # Remove the empty Linux dir
  if ! rm -rf "${dest:?}"/Linux; then
    __print_error "rm -rf ${dest:?}/Linux" && return 1
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
    __print_error "mv $source/* $dest/" && return 1
  fi

  if ! chmod +x "$dest"/TerrariaServer*; then
    __print_error "chmod +x $dest/TerrariaServer*" && return 1
  fi

  # Remove everything else left behind in $source
  if ! rm -rf "${source:?}"/*; then
    __print_error "rm -rf ${source:?}/*" && return 1
  fi

  return 0
}
