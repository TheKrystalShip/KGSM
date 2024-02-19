#!/bin/bash

################################################################################
# Script used for updating a game server.
# Steps:
#   1. Check if new version is available
#   2. Download new version in temporary folder
#   3. Create backup of running version
#   4. Deploy newly downloaded version
#   5. Restore service state
#   6. Update version number in DB
#
# INPUT:
# - Must provide a game name (must match the name in the DB, folder name,
#   service file name, etc.)
#
# OUTPUT:
# - Exit Code 0: Update successful
# - Exit Code 1-n: Error, check output
#
# DB table schema for reference
#┌──┬────┬───────────┬─────────────────┬──────┐
#│0 |1   |2          |3                |4     │
#├──┼────┼───────────┼─────────────────┼──────┤
#|id|name|working_dir|installed_version|app_id|
#└──┴────┴───────────┴─────────────────┴──────┘
################################################################################

################################################################################
# > Global vars
################################################################################

export EXITSTATUS_SUCCESS=0
export EXITSTATUS_ERROR=1
SEPARATOR="================================================================================"

################################################################################
# > Init checks
################################################################################

if [ -z "$USER" ]; then
  func_exit_error ">>> ERROR: \$USER var not set, cannot run script without it. Exiting"
fi

# Params
if [ $# == 0 ]; then
  func_exit_error ">>> ERROR: Game name not supplied. Run script like this: ./${0##*/} \"GAME\""
fi

# Force an install regardless if the latest version is already installed
FORCE_INSTALL=0
if [ -n "$2" ] && [ "$2" == "--force" ]; then
  FORCE_INSTALL=1
fi

SERVICE_NAME=$1
export DB_FILE="/home/$USER/servers/info.db"

# Select the entire row, each service only has one row so no need to check
# for multiple rows being returned
result=$(sqlite3 "$DB_FILE" "SELECT * from services WHERE name = '${SERVICE_NAME//\'/\'\'}';")

if [ -z "$result" ]; then
  func_exit_error ">>> ERROR: Didn't get any result back from DB, exiting"
fi

# Result is a string with all values glued together by a | character, split
IFS='|' read -r -a COLS <<<"$result"

if [ -z "${COLS[0]}" ]; then
  func_exit_error ">>> ERROR: Failed to parse result, exiting"
fi

################################################################################
# > Service specific vars
################################################################################

export SERVICE_NAME="${COLS[1]}"
export SERVICE_WORKING_DIR="${COLS[2]}"
export SERVICE_INSTALLED_VERSION="${COLS[3]}"
export SERVICE_APP_ID="${COLS[4]}"

# 0 (false), 1 (true)
# shellcheck disable=SC2155
export IS_STEAM_GAME=$(
  ! [ "$SERVICE_APP_ID" != "0" ]
  echo $?
)

export BASE_DIR=/home/"$USER"/servers
export GLOBAL_SCRIPTS_DIR="$BASE_DIR"/scripts
export GLOBAL_VERSION_CHECK_FILE="$GLOBAL_SCRIPTS_DIR"/version_check.sh

# Install dir
export SERVICE_INSTALL_DIR="$SERVICE_WORKING_DIR"/install
if [ ! -d "$SERVICE_INSTALL_DIR" ]; then
  mkdir -p "$SERVICE_INSTALL_DIR"
fi

# Temp dir
export SERVICE_TEMP_DIR="$SERVICE_WORKING_DIR"/temp
if [ ! -d "$SERVICE_TEMP_DIR" ]; then
  mkdir -p "$SERVICE_TEMP_DIR"
fi

# Backup dir
export SERVICE_BACKUPS_DIR="$SERVICE_WORKING_DIR"/backups
if [ ! -d "$SERVICE_BACKUPS_DIR" ]; then
  mkdir -p "$SERVICE_BACKUPS_DIR"
fi

# Config dir
export SERVICE_CONFIG_DIR="$SERVICE_WORKING_DIR"/config
if [ ! -d "$SERVICE_CONFIG_DIR" ]; then
  mkdir -p "$SERVICE_CONFIG_DIR"
fi

# Saves dir
export SERVICE_SAVES_DIR="$SERVICE_WORKING_DIR"/saves
if [ ! -d "$SERVICE_SAVES_DIR" ]; then
  mkdir -p "$SERVICE_SAVES_DIR"
fi

export SERVICE_CUSTOM_SCRIPTS_FILE="$SERVICE_WORKING_DIR/custom_scripts.sh"

################################################################################
# > Function return vars
################################################################################

export func_get_latest_version_result="$EXITSTATUS_ERROR"
export func_download_result="$EXITSTATUS_ERROR"
export func_get_service_status_result="inactive" # active / inactive
export func_create_backup_result="$EXITSTATUS_ERROR"
export func_deploy_result="$EXITSTATUS_ERROR"
export func_restore_service_state_result="$EXITSTATUS_ERROR"
export func_update_version_result="$EXITSTATUS_ERROR"

################################################################################
# > Functions
################################################################################

function func_main() {

  # shellcheck disable=SC1091
  source "/etc/environment"

  func_print_title "> Update process started for $SERVICE_NAME <"

  sleep 1

  ############################################################################
  #### Check for new version
  ############################################################################

  func_print_title "> 1/7 Version check"
  printf "\n\tChecking for latest version...\n"
  func_get_latest_version "$SERVICE_NAME"

  if [ "$func_get_latest_version_result" == "$EXITSTATUS_ERROR" ]; then
    func_exit_error ">>> ERROR: No new version found, exiting.\n"
  fi

  printf "\tInstalled version:\t%s\n" "$SERVICE_INSTALLED_VERSION"
  printf "\tNew version found:\t%s\n" "$func_get_latest_version_result"

  if [ "$func_get_latest_version_result" == "$EXITSTATUS_ERROR" ] || [ -z "$func_get_latest_version_result" ]; then
    func_exit_error ">>> ERROR: new version number is empty, exiting"
  fi

  sleep 1

  if [ "$SERVICE_INSTALLED_VERSION" == "$func_get_latest_version_result" ]; then
    printf "\tWARNING: latest version already installed\n"
    printf "\tContinuing would overwrite existing install\n"

    if [ $FORCE_INSTALL -ne 1 ]; then
      if ! func_confirm "Continue? [Y/n]"; then
        func_exit_error
      fi
    else
      printf "\tForced installation was specified, continuing\n\n"
      sleep 1
    fi
  fi

  ############################################################################
  #### Download new version
  ############################################################################

  # Download new version in temp folder

  func_print_title "> 2/7 Download"
  printf "\n\tDownloading version %s\n\n" "$func_get_latest_version_result"

  func_download "$func_get_latest_version_result"

  if [ "$func_download_result" == "$EXITSTATUS_ERROR" ]; then
    func_exit_error ">>> ERROR: Failed to download new version, exiting.\n"
  fi

  printf "\n\tDownload completed\n\n"
  sleep 1

  ############################################################################
  #### Check if service is currently running and shut it down if needed
  ############################################################################

  func_print_title "> 3/7 Service status"
  printf "\n\tChecking current service status\n\n"

  func_get_service_status "$SERVICE_NAME"

  if [ "$func_get_service_status_result" = "active" ]; then
    printf "\n\tWARNING: Service currently running, shutting down first...\n"

    local service_shutdown_exit_code="$EXITSTATUS_ERROR"
    service_shutdown_exit_code=$(exec "$GLOBAL_SCRIPTS_DIR/stop.sh" "$SERVICE_NAME")

    if [ "$service_shutdown_exit_code" == "$EXITSTATUS_ERROR" ]; then
      func_exit_error ">>> ERROR: Failed to shutdown service, exiting"
    else
      printf "\n\tService shutdown complete, continuing\n\n"
    fi
  else
    printf "\n\tService status %s, continuing\n\n" "$func_get_service_status_result"
  fi

  sleep 1

  ############################################################################
  #### Backup existing install if it exists
  ############################################################################

  func_print_title "> 4/7 Backup"

  if [ -z "$(ls -A "$SERVICE_INSTALL_DIR")" ]; then
    # Dir is empty
    printf "\n\tNo installation found, skipping backup step\n\n"
    sleep 1
  else
    # Dir is not empty, backup exiting release
    printf "\n\tCreating backup of current version\n\n"
    sleep 1
    func_create_backup "$SERVICE_INSTALL_DIR"

    if [ "$func_create_backup_result" == "$EXITSTATUS_ERROR" ]; then
      func_exit_error ">>> ERROR: Failed to create backup, exiting"
    fi

    printf "\n\tBackup complete in folder: %s\n\n" "$func_create_backup_result"
    sleep 1
  fi

  ############################################################################
  #### Deploy newly downloaded version
  ############################################################################

  func_print_title "> 5/7 Deployment"
  printf "\n\tDeploying %s...\n\n" "$func_get_latest_version_result"
  sleep 1

  func_deploy

  if [ "$func_deploy_result" == "$EXITSTATUS_ERROR" ]; then
    func_exit_error ">>> ERROR: Failed to deploy $func_get_latest_version_result, exiting" "$func_get_latest_version_result"
  fi

  printf "\n\tDeployment complete.\n\n"
  sleep 1

  ############################################################################
  #### Restore service state if needed
  ############################################################################

  func_print_title "> 6/7 Service restore"

  if [ "$func_get_service_status_result" = "active" ]; then
    echo $SEPARATOR
    printf "\n\tStarting the service back up\n\n"
    sleep 1

    func_restore_service_state "$SERVICE_NAME"
    if [ "$func_restore_service_state_result" == "$EXITSTATUS_ERROR" ]; then
      func_exit_error ">>> ERROR: Failed to restore service to running state, exiting"
    fi

    printf "\n\tService started successfully\n\n"
    sleep 1
  else
    printf "\n\tService was %s, skipping restore step\n\n" "$func_get_service_status_result"
    sleep 1
  fi

  sleep 1

  ############################################################################
  #### Save the new installed version number
  ############################################################################

  func_print_title "> 7/7 Updating version record"
  sleep 1

  printf "\n\t Saving new version %s\n\n" "$func_get_latest_version_result"
  func_update_version "$func_get_latest_version_result"

  if [ "$func_update_version_result" == "$EXITSTATUS_ERROR" ]; then
    printf ">>> ERROR: Failed to update version number in DB, however the update has been deployed"
  fi

  func_print_title "> Update finished <"
  exit "$EXITSTATUS_SUCCESS"
}

function func_get_latest_version() {
  func_get_latest_version_result=$(steamcmd +login "$STEAM_USERNAME" "$STEAM_PASSWORD" +app_info_update 1 +app_info_print "$SERVICE_APP_ID" +quit | tr '\n' ' ' | grep --color=NEVER -Po '"branches"\s*{\s*"public"\s*{\s*"buildid"\s*"\K(\d*)')
}

function func_download() {
  local version=$1
  func_download_result="$EXITSTATUS_ERROR"

  steamcmd +@sSteamCmdForcePlatformType linux +force_install_dir "$SERVICE_TEMP_DIR" +login "$STEAM_USERNAME" "$STEAM_PASSWORD" +app_update "$SERVICE_APP_ID" -beta none validate +quit
  func_download_result=$?
}

# # Debugging, skip downloading
# function func_download() {
#     func_download_result="$EXITSTATUS_SUCCESS"
# }

function func_get_service_status() {
  # Possible output: "active" / "inactive"
  func_get_service_status_result=$(exec "$GLOBAL_SCRIPTS_DIR/is-active.sh" "$SERVICE_NAME")
}

function func_create_backup() {
  # shellcheck disable=SC2155
  local datetime=$(exec date +"%Y-%m-%d%T")
  local output_dir="${SERVICE_BACKUPS_DIR}/${SERVICE_NAME}-${SERVICE_INSTALLED_VERSION}-${datetime}.backup"

  # Create backup folder if it doesn't exit
  if [ ! -d "$output_dir" ]; then
    if ! mkdir -p "$output_dir"; then
      printf "\tERROR: Error creating backup folder %s" "$output_dir"
      return
    fi
  fi

  if ! mv -v "$SERVICE_INSTALL_DIR"/* "$output_dir"/; then
    echo ">>> ERROR: Failed to move contents from $SERVICE_INSTALL_DIR into $output_dir"
    return
  fi

  func_create_backup_result="$output_dir"
}

function func_deploy() {
  # Move everything from $SERVICE_TEMP_DIR into $SERVICE_INSTALL_DIR
  if ! mv -v "$SERVICE_TEMP_DIR"/* "$SERVICE_INSTALL_DIR"/; then
    echo ">>> ERROR: Failed to move contents from $SERVICE_TEMP_DIR into $SERVICE_INSTALL_DIR"
    return
  fi

  func_deploy_result="$EXITSTATUS_SUCCESS"
}

function func_restore_service_state() {
  func_restore_service_state_result=$(exec "$GLOBAL_SCRIPTS_DIR/start.sh" "$SERVICE_NAME")
}

function func_update_version() {
  # Save new version number in DB
  local version=$1
  local sql_script="UPDATE services \
                      SET installed_version = '${version}' \
                      WHERE name = '${SERVICE_NAME}';"

  sqlite3 "$DB_FILE" "$sql_script"
  func_update_version_result=$?
}

function func_exit_error() {
  printf "\t%s\n" "${*:- Update process cancelled}"
  exit "$EXITSTATUS_ERROR"
}

function func_confirm() {
  # call with a prompt string or use a default
  read -r -p "${1:-Are you sure? [Y/n]} " response
  case "$response" in
  [nN][oO] | [nN])
    false
    ;;
  *)
    true
    ;;
  esac
}

function func_print_title() {
  echo "$SEPARATOR"
  echo "$1"
  echo "$SEPARATOR"
}

# Trap CTRL-C
trap func_exit_error INT

# Check if the game is from steam or not, check for a custom_scripts.sh
# file and if it exists, source it
if [ "$IS_STEAM_GAME" == "$EXITSTATUS_SUCCESS" ]; then
  # Dealing with a non-steam game, source the custom scripts
  printf "Non-Steam game detected, importing custom scripts file\n"

  if ! test -f "$SERVICE_CUSTOM_SCRIPTS_FILE"; then
    func_exit_error ">>> ERROR: Could not locate custom_scripts.sh file for $SERVICE_NAME, exiting"
  fi

  # shellcheck source=/dev/null
  source "$SERVICE_CUSTOM_SCRIPTS_FILE"
fi

# Start the script
func_main "$@"
