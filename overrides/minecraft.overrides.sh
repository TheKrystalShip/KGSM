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
  local mc_versions_cache="$SERVICE_TEMP_DIR/version_cache.json"

  # Create file if it doesn't exist before writing to it
  if [ ! -f "$mc_versions_cache" ]; then
    touch "$mc_versions_cache"
  fi

  # Fetch latest version manifest
  if ! curl -sS https://launchermeta.mojang.com/mc/game/version_manifest.json >"$mc_versions_cache"; then
    echo ">>> ERROR: curl -sS https://launchermeta.mojang.com/mc/game/version_manifest.json >$mc_versions_cache"
    return "$EXITSTATUS_ERROR"
  fi

  # shellcheck disable=SC2034
  result=$(cat "$mc_versions_cache" | jq -r '{latest: .latest.release} | .[]')
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
  local version=$1
  local dest=$2

  local mc_versions_cache="$dest/version_cache.json"
  local release_json="$dest/_release.json"

  # Pick URL
  # shellcheck disable=SC2155
  local release_url="$(cat "$mc_versions_cache" | jq -r "{versions: .versions} | .[] | .[] | select(.id == \"$version\") | {url: .url} | .[]")"

  if ! curl -sS "$release_url" >"$release_json"; then
    echo ">>> ERROR: curl -sS $release_url >$release_json"
    return "$EXITSTATUS_ERROR"
  fi

  # shellcheck disable=SC2155
  local release_server_jar_url="$(cat "$release_json" | jq -r '{url: .downloads.server.url} | .[]')"

  local local_release_jar="$dest/minecraft_server.$version.jar"

  if [ ! -f "$local_release_jar" ]; then
    curl -sS "$release_server_jar_url" -o "$local_release_jar"
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

  if ! mv -f "$source"/*.jar "$dest"/release.jar; then
    echo ">>> ERROR: mv -f $source/* $dest/"
    return "$EXITSTATUS_ERROR"
  fi

  local eula_file="$source"/eula.txt

  if ! echo "eula=true" >"$eula_file"; then
    echo ">>> WARNING: Failed to configure eula.txt file, continuing"
  fi

  return "$EXITSTATUS_SUCCESS"
}
