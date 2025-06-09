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
# INSTANCE_PORTS
# INSTANCE_EXECUTABLE_FILE
# INSTANCE_EXECUTABLE_ARGUMENTS
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
function _get_latest_version() {
  wget -qO - https://launchermeta.mojang.com/mc/game/version_manifest.json \
    | jq -r '{latest: .latest.release} | .[]' \
    | tr -d '"'
}

# INPUT:
# - $1: Version
#
# OUTPUT:
# - 0: Success
# - 1: Error
function _download() {
  local version=$1
  local dest=$INSTANCE_TEMP_DIR

  # shellcheck disable=SC2155
  local release_url="$(
    wget -qO - https://launchermeta.mojang.com/mc/game/version_manifest.json \
      | jq -r "{versions: .versions} | .[] | .[] | select(.id == \"$version\") | {url: .url} | .[]"
  )"

  if [[ -z "$release_url" ]]; then
    __print_error "Could not find the URL of the latest release, exiting"
    return 1
  fi

  # shellcheck disable=SC2155
  local release_server_jar_url="$(
    wget -qO - "$release_url" \
      | jq -r '{url: .downloads.server.url} | .[]'
  )"

  if [[ -z "$release_server_jar_url" ]]; then
    __print_error "Could not find the URL of the JAR file"
    return 1
  fi

  local local_release_jar="$dest/minecraft_server.$version.jar"

  if [ ! -f "$local_release_jar" ]; then
    wget -qO "$local_release_jar" "$release_server_jar_url"
  fi

  return 0
}

# INPUT:
# - Void
#
# OUTPUT:
# - 0: Success
# - 1: Error
function _deploy() {
  local source=$INSTANCE_TEMP_DIR
  local dest=$INSTANCE_INSTALL_DIR

  if ! mv -f "$source"/*.jar "$dest"/release.jar; then
    __print_error "mv -f $source/* $dest/"
    return 1
  fi

  local eula_file=$dest/eula.txt

  if ! echo "eula=true" > "$eula_file"; then
    __print_warning "Failed to configure eula.txt file, continuing"
  fi

  return 0
}
