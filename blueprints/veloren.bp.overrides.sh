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
# SERVICE_TEMP_DIR
#
# SERVICE_OVERRIDES_SCRIPT_FILE
# SERVICE_MANAGE_SCRIPT_FILE
################################################################################

# INPUT:
# - void
#
# OUTPUT:
# - void: Success (echo "$new_version")
# - 1: Error
function func_get_latest_version() {
  # TODO: Veloren doesn't have an API to check for new version releases,
  # gonna have to do some manual work.
  # This will download once for a clean install
  echo "weekly"
}

# INPUT:
# - $1: Version
# - $2: Destination directory, absolute path
#
# OUTPUT:
# - 0: Success
# - 1: Error
function func_download() {
  # https://download.veloren.net/latest/linux/x86_64/weekly
  local version=$1
  local dest=$2

  # Download zip file in $dest
  if ! wget -P "$dest" "https://download.veloren.net/latest/linux/x86_64/weekly"; then
    echo ">>> ${0##*/} ERROR: wget -P $dest https://download.veloren.net/latest/linux/x86_64/weekly" >&2
    return 1
  fi

  # Extract zipped contents in the same $dest
  if ! unzip "$dest"/weekly -d "$dest"; then
    echo ">>> ${0##*/} ERROR: unzip $dest/weekly -d $dest" >&2
    return 1
  fi

  # Remove zip file
  if ! rm "$dest"/weekly; then
    echo ">>> ${0##*/} ERROR: rm $dest/weekly" >&2
    return 1
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
# function func_deploy() {
#   local source=$1
#   local dest=$2
#   return 0
# }
