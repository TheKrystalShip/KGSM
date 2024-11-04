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
  wget -qO - 'https://factorio.com/api/latest-releases' | jq .stable.headless | tr -d '"'
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
  local download_url="https://factorio.com/get-download/${version}/headless/linux64"
  local dest_file="$dest/factorio_headless.tar.xz"

  # Download
  if ! wget -qO "$dest_file" "$download_url"; then
    __print_error "wget -qO $dest_file $download_url" && return 1
  fi

  # Extract
  if ! tar -xf "$dest_file" --strip-components=1 -C "$dest" 2>&- 1>&2; then
    __print_error "tar -xf $dest_file --strip-components=1 -C $dest" && return 1
  fi

  # Remove trailing file
  if ! rm "$dest_file"; then
    __print_error "rm $dest_file" && return 1
  fi

  return 0
}

function func_deploy() {
  local source=$1
  local dest=$2

  if ! cp -r "$source"/* "$dest"; then
    __print_error "Failed copy contents from $source into $dest" && return 1
  fi

  if ! rm -rf "${source:?}"/*; then
    __print_warning "Failed to clear $source"
  fi

  # Check if savefile exists, factorio needs to boot with an existing
  # save otherwise it fails to start. Create a savefile at this stage
  if [[ ! -f "$INSTANCE_SAVES_DIR/$INSTANCE_LEVEL_NAME" ]]; then
    cd "$INSTANCE_INSTALL_DIR/bin/x64" || return 1
    "$INSTANCE_LAUNCH_BIN" --create "$INSTANCE_SAVES_DIR/$INSTANCE_LEVEL_NAME" || return 1
  fi

  return 0
}
