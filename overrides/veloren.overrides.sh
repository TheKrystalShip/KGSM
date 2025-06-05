#!/usr/bin/env bash

################################################################################
# Uncomment and use any of the following functions, they will be used to
# override the default function when generating a instance's management file
################################################################################
#
# Brief description of each:
#
# INPUT:
# - void
#
# OUTPUT:
# - echo "$version": Success
# - exit 1: Error
# _get_latest_version           Should always return the latest available
#                               version, or 1 in case there's any problem.
#
# INPUT:
# - $1: Version
#
# OUTPUT:
# - exit 0: Success
# - exit 1: Error
# _download                     In charge of downloading all the required files
#                               for the service, extract any zips, move, copy,
#                               rename, remove, etc. It should leave the $2
#                               with a fully working setup that can be called
#                               and executed as if it was a full install.
#
# INPUT:
# - void
#
# OUTPUT:
# - exit 0: Success
# - exit 1: Error
# _deploy                       Will move everything from $1 into $2 and do any
#                               cleanup that couldn't be done by func_download.
#
################################################################################
#
# Available global vars:
#
# INSTANCE_ID
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
# - void: Success (echo "$new_version")
# - 1: Error
function _get_latest_version() {
  # TODO: Veloren doesn't have an API to check for new version releases,
  # gonna have to do some manual work.
  # This will download once for a clean install
  echo "weekly"
}

# INPUT:
# - $1: Version
#
# OUTPUT:
# - 0: Success
# - 1: Error
function _download() {
  # https://download.veloren.net/latest/linux/x86_64/weekly
  local version=$1
  local dest=$INSTANCE_TEMP_DIR

  local download_url="https://download.veloren.net/latest/linux/x86_64/weekly"

  # Download zip file in $dest
  if ! wget -P "$dest" "$download_url"; then
    __print_error "wget -P $dest $download_url"
    return 1
  fi

  # Extract zipped contents in the same $dest
  if ! unzip "$dest"/weekly -d "$dest"; then
    __print_error "unzip $dest/weekly -d $dest"
    return 1
  fi

  # Remove zip file
  if ! rm "$dest"/weekly; then
    __print_error "rm $dest/weekly"
    return 1
  fi

  return 0
}

# INPUT:
# - Void
#
# OUTPUT:
# - 0: Success
# - 1: Error
# function _deploy() {
#   local source=$1
#   local dest=$2
#   return 0
# }
