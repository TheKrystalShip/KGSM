#!/bin/bash

################################################################################
# Main file: /opt/scripts/update.sh
#
# These are the functions available in the main script that can be overwritten.
# Each function should write it's output to the corresponding var
#
# func_get_latest_version        => func_get_latest_version_result
# func_download                  => func_download_result
# func_get_service_status        => func_get_service_status_result
# func_create_backup             => func_create_backup_result
# func_deploy                    => func_deploy_result
# func_restore_service_state     => func_restore_service_state_result
# func_update_version            => func_update_version_result
#
# Available global vars:
#
# EXITSTATUS_SUCCESS
# EXITSTATUS_ERROR
# GLOBAL_SCRIPTS_DIR
# GLOBAL_VERSION_CHECK_FILE
# BASE_DIR
# DB_FILE
# IS_STEAM_GAME
# SERVICE_NAME
# SERVICE_WORKING_DIR
# SERVICE_INSTALLED_VERSION
# SERVICE_APP_ID
# SERVICE_INSTALL_DIR
# SERVICE_TEMP_DIR
# SERVICE_BACKUPS_DIR
# SERVICE_CONFIG_DIR
# SERVICE_SAVES_DIR
################################################################################

function func_get_latest_version() {
  local mc_versions_cache="$SERVICE_TEMP_DIR/version_cache.json"

  # Create file if it doesn't exist before writing to it
  if [ ! -f "$mc_versions_cache" ]; then
    touch "$mc_versions_cache"
  fi

  # Fetch latest version manifest
  if ! curl -sS https://launchermeta.mojang.com/mc/game/version_manifest.json >"$mc_versions_cache"; then
    echo ">>> ERROR: curl -sS https://launchermeta.mojang.com/mc/game/version_manifest.json >$mc_versions_cache"
    return
  fi

  # shellcheck disable=SC2034
  func_get_latest_version_result=$(cat "$mc_versions_cache" | jq -r '{latest: .latest.release} | .[]')
}

function func_download() {
  ############################################################################
  # INPUT:
  # - $1: Version
  ############################################################################
  # Download new version in $SERVICE_TEMP_DIR
  local version=$1

  local mc_versions_cache="$SERVICE_TEMP_DIR/version_cache.json"
  local release_json="$SERVICE_TEMP_DIR/_release.json"

  # Pick URL
  # shellcheck disable=SC2155
  local release_url="$(cat "$mc_versions_cache" | jq -r "{versions: .versions} | .[] | .[] | select(.id == \"$version\") | {url: .url} | .[]")"
  # echo "Release URL: $release_url"

  if ! curl -sS "$release_url" >"$release_json"; then
    echo ">>> ERROR: curl -sS $release_url >$release_json"
    return
  fi

  # shellcheck disable=SC2155
  local release_server_jar_url="$(cat "$release_json" | jq -r '{url: .downloads.server.url} | .[]')"

  # echo "Release .jar URL:  $release_server_jar_url"

  local local_release_jar="$SERVICE_TEMP_DIR/minecraft_server.$version.jar"

  if [ ! -f "$local_release_jar" ]; then
    curl -sS "$release_server_jar_url" -o "$local_release_jar"
  fi
  # echo "Release .jar:  $local_release_jar"

  # shellcheck disable=SC2034
  func_download_result="$EXITSTATUS_SUCCESS"
}

function func_deploy() {
  # Deploy new version from $SERVICE_TEMP_DIR into $SERVICE_INSTALL_DIR

  if ! mv -f -v "$SERVICE_TEMP_DIR"/*.jar "$SERVICE_INSTALL_DIR"/release.jar; then
    echo ">>> ERROR: mv -f -v $SERVICE_TEMP_DIR/* $SERVICE_INSTALL_DIR/"
    return
  fi

  local eula_file="$SERVICE_TEMP_DIR"/eula.txt

  if ! echo "eula=true">"$eula_file"; then
    echo ">>> WARNING: Failed to configure eula.txt file, continuing"
  fi

  # shellcheck disable=SC2034
  func_deploy_result="$EXITSTATUS_SUCCESS"
}
