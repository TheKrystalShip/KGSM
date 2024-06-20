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
# func_setup                    Will set up any system config needed in order to
#                               run the service, like systemd files, firewall
#                               rules or anything else that's needed.
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
# - 0: Success (echo "$new_version")
# - 1: Error
function func_get_latest_version() {
  # shellcheck disable=SC2034
  result=$(curl -s 'https://factorio.com/api/latest-releases' | python3 -c "import sys, json; print(json.load(sys.stdin)['stable']['headless'])")
  echo "$result"
}

# INPUT:
# - $1: Version
# - $2: Destination directory, absolute path
#
# OUTPUT:
# - 0: Success
# - 1: Error
function func_download() {
  # shellcheck disable=SC2034
  local version=$1
  local dest=$2

  # Download new version in $dest
  local output_file="$dest/factorio_headless.tar.xz"

  # Download
  if ! wget https://factorio.com/get-download/stable/headless/linux64 -O "$output_file"; then
    echo ">>> ${0##*/} ERROR: wget https://factorio.com/get-download/stable/headless/linux64 -O $output_file"
    return
  fi

  # Extract
  if ! tar -xf "$output_file" --strip-components=1 -C "$dest"; then
    echo ">>> ${0##*/} ERROR: tar -xf $output_file --strip-components=1 -C $dest"
    return
  fi

  # Remove trailing file
  if ! rm "$output_file"; then
    echo ">>> ${0##*/} ERROR: rm $output_file"
    return
  fi

  # shellcheck disable=SC2034
  return 0
}
