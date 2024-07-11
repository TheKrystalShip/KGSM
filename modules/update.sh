#!/bin/bash

function usage() {
  echo "Runs a full update process for a game server.
It goes through multiple steps:
  Step 1: Check if there's a new version available

  Step 2: Run the download process, either through SteamCMD or through an
          override if one exists.

  Step 3: It checks if the service might already be running and will shut it
          down before proceeding

  Step 4: Will create a full backup of the existing installation

  Step 5: Deploys the newly downloaded version

  Step 6: Restores the service if it was running during Step 3

  Step 7: Saves the new version

After Step 7 a message will be displayed indicating the update was a success
and it will exit with code 0

Usage:
    ./${0##*/} [-b | --blueprint] <bp>

Options:
    -b --blueprint <bp>   Name of the blueprint file, this has to be the first
                          parameter.
                          (The .bp extension in the name is optional)

Examples:
    ./${0##*/} -b valheim

    ./${0##*/} --blueprint terraria
"
}

set -eo pipefail

# shellcheck disable=SC2199
if [[ $@ =~ "--debug" ]]; then
  export PS4='+(\033[0;33m${BASH_SOURCE}:${LINENO}\033[0m): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
  set -x
  for a; do
    shift
    case $a in
    --debug) continue ;;
    *) set -- "$@" "$a" ;;
    esac
  done
fi

if [ "$#" -eq 0 ]; then usage && exit 1; fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
  -h | --help)
    usage && exit 0
    ;;
  -b | --blueprint)
    BLUEPRINT=$2
    shift
    ;;
  *)
    echo "ERROR: Invalid argument $1" >&2
    usage && exit 1
    ;;
  esac
  shift
done

# Check for KGSM_ROOT env variable
if [ -z "$KGSM_ROOT" ]; then
  echo "WARNING: KGSM_ROOT not found, sourcing /etc/environment." >&2
  # shellcheck disable=SC1091
  source /etc/environment

  # If not found in /etc/environment
  if [ -z "$KGSM_ROOT" ]; then
    echo "ERROR: KGSM_ROOT not found, exiting." >&2
    exit 1
  else
    echo "INFO: KGSM_ROOT found in /etc/environment, consider rebooting the system" >&2

    # Check if KGSM_ROOT is exported
    if ! declare -p KGSM_ROOT | grep -q 'declare -x'; then
      export KGSM_ROOT
    fi
  fi
fi

BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"
STEAMCMD_SCRIPT="$(find "$KGSM_ROOT" -type f -name steamcmd.sh)"
VERSION_SCRIPT_FILE="$(find "$KGSM_ROOT" -type f -name version.sh)"
DOWNLOAD_SCRIPT_FILE="$(find "$KGSM_ROOT" -type f -name download.sh)"
BACKUP_SCRIPT_FILE="$(find "$KGSM_ROOT" -type f -name backup.sh)"
DEPLOY_SCRIPT_FILE="$(find "$KGSM_ROOT" -type f -name deploy.sh)"

# shellcheck disable=SC1090
source "$BLUEPRINT_SCRIPT" "$BLUEPRINT" || exit 1

# shellcheck disable=SC1090
source "$STEAMCMD_SCRIPT" "$BLUEPRINT" || exit 1

################################################################################
# > Functions
################################################################################

function func_exit_error() {
  printf "\t%s\n" "${*:- Update process cancelled}" >&2
  exit 1
}

# Trap CTRL-C
trap func_exit_error INT

function func_print_title() {
  {
    echo "================================================================================"
    echo "> $1"
    echo "================================================================================"
  } >&2
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
  local latest_version=$("$VERSION_SCRIPT_FILE" -b "$SERVICE_NAME" --latest)

  printf "\tInstalled version:\t%s\n" "$SERVICE_INSTALLED_VERSION"

  if [ "$latest_version" == "$EXITSTATUS_ERROR" ]; then
    func_exit_error "ERROR: No new version found, exiting.\n"
  fi

  if [ -z "$latest_version" ]; then
    func_exit_error "ERROR: new version number is empty, exiting"
  fi

  printf "\tLatest version available:\t%s\n" "$latest_version"

  if [ "$SERVICE_INSTALLED_VERSION" == "$latest_version" ]; then
    printf "\tWARNING: latest version already installed. Continuing would overwrite existing install\n"
    read -r -p "Continue? (Y/n): " confirm && [[ $confirm != [nN] ]] || exit 1
  fi

  ############################################################################
  #### Download new version
  ############################################################################

  func_print_title "2/7 Download"
  printf "\n\tDownloading version %s\n\n" "$latest_version"

  if ! "$DOWNLOAD_SCRIPT_FILE" -b "$SERVICE_NAME"; then
    func_exit_error "ERROR: Failed to download new version, exiting.\n"
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
      func_exit_error "ERROR: Failed to shutdown service, exiting"
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

  if ! "$BACKUP_SCRIPT_FILE" -b "$SERVICE_NAME" --create; then
    func_exit_error "ERROR: Failed to create backup, exiting"
  fi

  printf "\n\tBackup complete\n\n"
  sleep 1

  ############################################################################
  #### Deploy newly downloaded version
  ############################################################################

  func_print_title "5/7 Deployment"
  printf "\n\tDeploying %s...\n\n" "$latest_version"
  sleep 1

  if ! "$DEPLOY_SCRIPT_FILE" -b "$SERVICE_NAME"; then
    func_exit_error "ERROR: Failed to deploy $latest_version, exiting" "$latest_version"
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
      func_exit_error "ERROR: Failed to restore service to running state, exiting"
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

  # Save new version to SERVICE_VERSION_FILE
  "$VERSION_SCRIPT_FILE" -b "$SERVICE_NAME" --save "$latest_version"

  return 0
}

func_main "$@" && exit $?
