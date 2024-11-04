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
  wget -qO - https://launchermeta.mojang.com/mc/game/version_manifest.json | jq -r '{latest: .latest.release} | .[]' | tr -d '"'
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

  # shellcheck disable=SC2155
  local release_url="$(wget -qO - https://launchermeta.mojang.com/mc/game/version_manifest.json | jq -r "{versions: .versions} | .[] | .[] | select(.id == \"$version\") | {url: .url} | .[]")"
  [[ -z "$release_url" ]] && __print_error "Could not find the URL of the latest release, exiting" && return 1

  # shellcheck disable=SC2155
  local release_server_jar_url="$(wget -qO - "$release_url" | jq -r '{url: .downloads.server.url} | .[]')"
  [[ -z "$release_server_jar_url" ]] && __print_error "Could not find the URL of the JAR file" && return 1

  local local_release_jar="$dest/minecraft_server.$version.jar"

  if [ ! -f "$local_release_jar" ]; then
    wget -qO "$local_release_jar" "$release_server_jar_url"
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

  if ! mv -f "$source"/*.jar "$dest"/release.jar; then
    __print_error "mv -f $source/* $dest/" && return 1
  fi

  local eula_file=$dest/eula.txt

  if ! echo "eula=true" >"$eula_file"; then
    __print_warning "Failed to configure eula.txt file, continuing"
  fi

  return 0
}
