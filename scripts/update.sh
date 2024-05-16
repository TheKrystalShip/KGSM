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
################################################################################

# Params
if [ $# == 0 ]; then
  func_exit_error ">>> ERROR: Service name not supplied. Run script like this: ./${0##*/} \"SERVICE\""
fi

SERVICE=$1

# shellcheck disable=SC1091
source "/etc/environment"

# shellcheck disable=SC1091
source /opt/scripts/service_vars.sh "$SERVICE"

# shellcheck disable=SC1091
source /opt/scripts/steamcmd.sh "$SERVICE_STEAM_AUTH_LEVEL"

################################################################################
# > Functions
################################################################################

function func_exit_error() {
  printf "\t%s\n" "${*:- Update process cancelled}"
  exit "$EXITSTATUS_ERROR"
}

# Trap CTRL-C
trap func_exit_error INT

function func_print_title() {
  echo "================================================================================"
  echo "> $1"
  echo "================================================================================"
}

function func_main() {

  func_print_title "Update process started for $SERVICE_NAME <"
  sleep 1

  ############################################################################
  #### Check for new version
  ############################################################################

  func_print_title "1/7 Version check"
  printf "\n\tChecking for latest version...\n"
  sleep 1

  # shellcheck disable=SC2155
  local latest_version=$(/opt/scripts/version.sh "$SERVICE_NAME")

  printf "\tInstalled version:\t%s\n" "$SERVICE_INSTALLED_VERSION"

  if [ "$latest_version" == "$EXITSTATUS_ERROR" ]; then
    func_exit_error ">>> ERROR: No new version found, exiting.\n"
  fi

  if [ -z "$latest_version" ]; then
    func_exit_error ">>> ERROR: new version number is empty, exiting"
  fi

  printf "\tLatest version available:\t%s\n" "$latest_version"

  if [ "$SERVICE_INSTALLED_VERSION" == "$latest_version" ]; then
    printf "\tWARNING: latest version already installed. Continuing would overwrite existing install\n"
    read -r -p "Continue? (Y/n): " confirm && [[ $confirm != [nN] ]] || exit "$EXITSTATUS_ERROR"
  fi

  ############################################################################
  #### Download new version
  ############################################################################

  func_print_title "2/7 Download"
  printf "\n\tDownloading version %s\n\n" "$latest_version"

  if ! /opt/scripts/download.sh "$SERVICE_NAME"; then
    func_exit_error ">>> ERROR: Failed to download new version, exiting.\n"
  fi

  printf "\n\tDownload completed\n\n"
  sleep 1

  ############################################################################
  #### Check if service is currently running and shut it down if needed
  ############################################################################

  func_print_title "3/7 Service status"
  printf "\n\tChecking current service status\n\n"
  sleep 1

  # Possible output: "active" / "inactive" / "failed"
  # shellcheck disable=SC2155
  local service_status=$(systemctl is-active "$SERVICE_NAME")

  if [ "$service_status" = "active" ]; then
    printf "\n\tWARNING: Service currently running, shutting down first...\n"

    if ! systemctl stop "$SERVICE_NAME"; then
      func_exit_error ">>> ERROR: Failed to shutdown service, exiting"
    else
      printf "\n\tService shutdown complete, continuing\n\n"
    fi
  else
    printf "\n\tService status %s, continuing\n\n" "$service_status"
  fi

  sleep 1

  ############################################################################
  #### Backup existing install if it exists
  ############################################################################

  func_print_title "4/7 Backup"
  printf "\n\tCreating backup of current version\n\n"
  sleep 1

  if ! /opt/scripts/create_backup.sh "$SERVICE_NAME"; then
    func_exit_error ">>> ERROR: Failed to create backup, exiting"
  fi

  printf "\n\tBackup complete\n\n"
  sleep 1

  ############################################################################
  #### Deploy newly downloaded version
  ############################################################################

  func_print_title "5/7 Deployment"
  printf "\n\tDeploying %s...\n\n" "$latest_version"
  sleep 1

  if ! /opt/scripts/deploy.sh "$SERVICE_NAME"; then
    func_exit_error ">>> ERROR: Failed to deploy $latest_version, exiting" "$latest_version"
  fi

  printf "\n\tDeployment complete.\n\n"
  sleep 1

  ############################################################################
  #### Restore service state if needed
  ############################################################################

  func_print_title "6/7 Service restore"

  if [ "$service_status" = "active" ]; then
    printf "\n\tStarting the service back up\n\n"
    sleep 1

    # shellcheck disable=SC2155
    local restore_service_state_result=$(systemctl start "$SERVICE_NAME")

    if [ "$restore_service_state_result" == "$EXITSTATUS_ERROR" ]; then
      func_exit_error ">>> ERROR: Failed to restore service to running state, exiting"
    fi

    printf "\n\tService started successfully\n\n"
    sleep 1
  else
    printf "\n\tService was %s, skipping restore step\n\n" "$service_status"
    sleep 1
  fi

  ############################################################################
  #### Save the new installed version number
  ############################################################################

  func_print_title "7/7 Updating version record"
  printf "\n\t Saving new version %s\n\n" "$latest_version"
  sleep 1

  # Save new version to DB
  db_set_version "$SERVICE_NAME" "$latest_version"

  func_print_title "Update finished"
  exit "$EXITSTATUS_SUCCESS"
}

func_main "$@"
