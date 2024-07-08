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
# - 0: Success (echo "$new_version")
# - 1: Error
function func_get_latest_version() {
  local mc_versions_cache="$SERVICE_TEMP_DIR/version_cache.json"

  # Create file if it doesn't exist before writing to it
  if [ ! -f "$mc_versions_cache" ]; then
    touch "$mc_versions_cache"
  fi

  # Fetch latest version manifest
  if ! wget -qO "$mc_versions_cache" https://launchermeta.mojang.com/mc/game/version_manifest.json; then
    echo "${0##*/} ERROR: wget -qO $mc_versions_cache https://launchermeta.mojang.com/mc/game/version_manifest.json" >&2
    return 1
  fi

  # shellcheck disable=SC2034
  result=$(jq -r '{latest: .latest.release} | .[]' <"$mc_versions_cache" | tr -d '"')
  echo -n "$result"
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
  local release_url="$(jq <"$mc_versions_cache" -r "{versions: .versions} | .[] | .[] | select(.id == \"$version\") | {url: .url} | .[]")"

  if [ -z "$release_url" ]; then
    echo "${0##*/} ERROR: Could not find the URL of the latest release, exiting" >&2
    return 1
  fi

  if ! wget -qO "$release_json" "$release_url"; then
    echo "${0##*/} ERROR: wget -qO $release_json $release_url" >&2
    return 1
  fi

  # shellcheck disable=SC2155
  local release_server_jar_url="$(jq <"$release_json" -r '{url: .downloads.server.url} | .[]')"

  if [ -z "$release_server_jar_url" ]; then
    echo "${0##*/} ERROR: Could not find the URL of the JAR file" >&2
    return 1
  fi

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
    echo "${0##*/} ERROR: mv -f $source/* $dest/"
    return 1
  fi

  local eula_file="$source"/eula.txt

  if ! echo "eula=true" >"$eula_file"; then
    echo "${0##*/} WARNING: Failed to configure eula.txt file, continuing"
  fi

  return 0
}
