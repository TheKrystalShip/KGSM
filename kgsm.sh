#!/bin/bash

function get_version() {
  [[ -f "version.txt" ]] && cat "version.txt"
}

DESCRIPTION="Krystal Game Server Manager - $(get_version)

Create, install and manage game servers on Linux."

function usage() {
  printf "%s

Usage:
  ./kgsm.sh [option]

Options:
  \e[4mGeneral\e[0m
    -h --help                   Prints this message

    --update                    Updates KGSM to the latest version

    --install-requirements      Checks for required packages and installs them
                                if they are not present.

    --get-ip                    Gets the external server IP used to connect to the
                                server.
    --interactive               Starts the script in interactive mode.
        -h --help               Prints the help information for the interactive mode

    -v --version                Prints the KGSM version

  \e[4mBlueprints\e[0m
    --create-blueprint          Create a new blueprints file.
        -h --help               Prints the help information about the blueprint
                                creation process.

    --get-blueprints            Returns a list of all available blueprints

    --install \e[1mBLUEPRINT\e[0m         Run the installation process for an existing blueprint.
                                \e[1mBLUEPRINT\e[0m must be the name of a blueprint.
                                Run --get-blueprints to see a list of all available
                                blueprints.

  \e[4mServices\e[0m
    --service \e[1mSERVICE\e[0m [OPTION]  Issue commands to a service.
                                \e[1mSERVICE\e[0m must be the name of a server or a blueprint
                                OPTION represents one of the following

        --get-logs              Returns the last 10 lines of the service's log.
        --get-status            Returns a detailed status of the service.
        --is-active
        --start                 Starts the service.
        --stop                  Stops the service.
        --restart               Restarts the service.
        --check-update          Checks if a new version is available.
        --update                Runs the update process.
            -h --help           Prints the help information for the update process
        --create-backup         Creates a backup of the currently installed version if any.
            -h --help           Prints the help information for the backup process.
        --restore-backup \e[1mNAME\e[0m   Restores a backup.
                                \e[1mNAME\e[0m is the backup name.
            -h --help           Prints the help information for the backup process.
        --uninstall             Run the uninstall process.
" "$DESCRIPTION"
}

function usage_interactive() {
  printf "%s

Menu options:
     \e[4mInstall\e[0m            Run the installation process for an existing blueprint.
                        It will only prompt for input if there's any issues
                        during the install process.

     \e[4mCheck for update\e[0m   Check if a new version of a server is available.
                        It will print if a new version is found, otherwise
                        it will fail with exit code 1.

     \e[4mUpdate\e[0m             Runs a check for a new version, creates a backup
                        of the current installation if any, downloads the new
                        version and deploys it.

     \e[4mCreate backup\e[0m      Creates a backup of the current installation if any.

     \e[4mRestore Backup\e[0m     Restores a backup of a server
                        It will prompt to select a backup to restore and
                        also if the current installation directory of the
                        server is not empty.

     \e[4mUninstall\e[0m          Runs the uninstall process for a server.
                        Warning: This will remove everything other than the
                        blueprint file the server is based on.
" "$DESCRIPTION"
}

# Define a function to update the script and other files
function update_script() {
  # Define the raw URL of the script and version file
  # shellcheck disable=SC2155
  local script_version=$(get_version)
  local version_url="https://raw.githubusercontent.com/TheKrystalShip/KGSM/main/version.txt"
  local repo_archive_url="https://github.com/TheKrystalShip/KGSM/archive/refs/heads/main.tar.gz"
  echo "Checking for updates..." >&2

  # Fetch the latest version number
  if command -v curl >/dev/null 2>&1; then
    LATEST_VERSION=$(curl -s "$version_url")
  elif command -v wget >/dev/null 2>&1; then
    LATEST_VERSION=$(wget -q -O - "$version_url")
  else
    echo "Error: curl or wget is required to check for updates." >&2
    return 1
  fi

  # Compare the versions
  if [ "$script_version" != "$LATEST_VERSION" ]; then
    echo "New version available: $LATEST_VERSION. Updating..." >&2

    # Backup the current script
    cp "$0" "${0}.bak"
    echo "Backup of the current script created at ${0}.bak" >&2

    # Download the repository tarball
    if command -v curl >/dev/null 2>&1; then
      curl -L -o "kgsm.tar.gz" "$repo_archive_url" 2>/dev/null
    elif command -v wget >/dev/null 2>&1; then
      wget -O "kgsm.tar.gz" "$repo_archive_url" 2>/dev/null
    else
      echo "Error: curl or wget is required to download the update." >&2
      return 1
    fi

    # Extract the tarball
    if tar -xzf "kgsm.tar.gz"; then
      # Overwrite the existing files with the new ones
      cp -r KGSM-main/* .
      chmod +x kgsm.sh scripts/*.sh
      echo "Scripts updated successfully to version $LATEST_VERSION." >&2

      # Cleanup
      rm -rf "KGSM-main" "kgsm.tar.gz"

      # Remove --update arg from $@
      for arg in "$@"; do
        shift
        [ "$arg" = "--update" ] && continue
        set -- "$@" "$arg"
      done

      # Restart the script
      exec "$0" "$@"
    else
      echo "Error: Failed to extract the update. Reverting to the previous version." >&2
      mv "${0}.bak" "$0"
    fi
  else
    echo "You are already using the latest version: $script_version." >&2
  fi

  return 0
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
  -h | --help)
    usage && exit 0
    ;;
  --update)
    update_script "$@" && exit $?
    ;;
  updated)
    echo "Script was updated and restarted." >&2
    ;;
  *)
    break
    ;;
  esac
  shift
done

# Check for KGSM_ROOT env variable
if [ -z "$KGSM_ROOT" ]; then
  echo "${0##*/} WARNING: KGSM_ROOT environmental variable not found, sourcing /etc/environment." >&2
  # shellcheck disable=SC1091
  source /etc/environment

  # If not found in /etc/environment
  if [ -z "$KGSM_ROOT" ]; then
    # Only kgsm.sh can use this, all other scripts will require KGSM_ROOT as
    # an environment variable.
    KGSM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    export KGSM_ROOT
  else
    echo "${0##*/} INFO: KGSM_ROOT found in /etc/environment, consider rebooting the system" >&2

    # Check if KGSM_ROOT is exported
    if ! declare -p KGSM_ROOT | grep -q 'declare -x'; then
      export KGSM_ROOT
    fi
  fi
fi

# Trap CTRL-C
trap "echo "" && exit" INT

COMMON_SCRIPT="$(find "$KGSM_ROOT" -type f -name common.sh)"

# shellcheck disable=SC1090
source "$COMMON_SCRIPT" || exit 1

CREATE_BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name create_blueprint.sh)"
[[ -z "$CREATE_BLUEPRINT_SCRIPT" ]] && echo ">>> ${0##*/} ERROR: Failed to load create_blueprint.sh" >&2 && exit 1

DIRECTORIES_SCRIPT="$(find "$KGSM_ROOT" -type f -name directories.sh)"
[[ -z "$DIRECTORIES_SCRIPT" ]] && echo ">>> ${0##*/} ERROR: Failed to load directories.sh" >&2 && exit 1

FILES_SCRIPT="$(find "$KGSM_ROOT" -type f -name files.sh)"
[[ -z "$FILES_SCRIPT" ]] && echo ">>> ${0##*/} ERROR: Failed to load files.sh" >&2 && exit 1

VERSION_SCRIPT="$(find "$KGSM_ROOT" -type f -name version.sh)"
[[ -z "$VERSION_SCRIPT" ]] && echo ">>> ${0##*/} ERROR: Failed to load version.sh" >&2 && exit 1

DOWNLOAD_SCRIPT="$(find "$KGSM_ROOT" -type f -name download.sh)"
[[ -z "$DOWNLOAD_SCRIPT" ]] && echo ">>> ${0##*/} ERROR: Failed to load download.sh" >&2 && exit 1

DEPLOY_SCRIPT="$(find "$KGSM_ROOT" -type f -name deploy.sh)"
[[ -z "$DEPLOY_SCRIPT" ]] && echo ">>> ${0##*/} ERROR: Failed to load deploy.sh" >&2 && exit 1

UPDATE_SCRIPT="$(find "$KGSM_ROOT" -type f -name update.sh)"
[[ -z "$UPDATE_SCRIPT" ]] && echo ">>> ${0##*/} ERROR: Failed to load update.sh" >&2 && exit 1

BACKUP_SCRIPT="$(find "$KGSM_ROOT" -type f -name backup.sh)"
[[ -z "$BACKUP_SCRIPT" ]] && echo ">>> ${0##*/} ERROR: Failed to load backup.sh" >&2 && exit 1

REQUIREMENTS_SCRIPT="$(find "$KGSM_ROOT" -type f -name requirements.sh)"
[[ -z "$REQUIREMENTS_SCRIPT" ]] && echo ">>> ${0##*/} ERROR: Failed to load requirements.sh" >&2 && exit 1

function _install() {
  local blueprint=$1
  local install_dir=${2:-$KGSM_DEFAULT_INSTALL_DIR}

  if [[ "$blueprint" != *.bp ]]; then
    blueprint="${blueprint}.bp"
  fi

  # shellcheck disable=SC2155
  local blueprint_abs_path="$(find "$BLUEPRINTS_SOURCE_DIR" -type f -name "$blueprint")"
  # shellcheck disable=SC2155
  local service_name=$(cat "$blueprint_abs_path" | grep "SERVICE_NAME=" | cut -d "=" -f2 | tr -d '"')

  # If the path doesn't contain the service name, append it
  if [[ "$blueprint" != *$service_name ]]; then
    install_dir=$install_dir/$service_name
  fi

  if [ ! -d "$install_dir" ]; then
    if ! mkdir -p "$install_dir"; then
      echo ">>> ${0##*/} ERROR: Failed to create directory $install_dir" >&2
      return 1
    fi
  fi

  if [ ! -w "$install_dir" ]; then
    echo ">>> ${0##*/} ERROR: You don't have write permissions for $install_dir" >&2
    return 1
  fi

  # IMPORTANT
  # Once the installation directory has been established, it is essential
  # that it gets saved into the blueprint itself because all other scripts
  # expect the blueprint to have a $SERVICE_WORKING_DIR variable

  # If SERVICE_WORKING_DIR already exists in the blueprint, replace the value
  if cat "$blueprint_abs_path" | grep -q "SERVICE_WORKING_DIR="; then
    sed -i "/SERVICE_WORKING_DIR=*/c\SERVICE_WORKING_DIR=\"$install_dir\"" "$blueprint_abs_path" >/dev/null
  # Othwewise just append to the blueprint
  else
    {
      echo ""
      echo "# Directory where service is installed"
      echo "SERVICE_WORKING_DIR=\"$install_dir\""
    } >>"$blueprint_abs_path"
  fi

  # Get the latest version that's gonna be downloaded
  # shellcheck disable=SC2155
  local latest_version=$("$VERSION_SCRIPT" -b "$blueprint" --latest)

  # First create directory structure
  "$DIRECTORIES_SCRIPT" -b "$blueprint" --install
  # Create necessary files
  sudo "$FILES_SCRIPT" -b "$blueprint" --install
  # Run the download process
  "$DOWNLOAD_SCRIPT" -b "$blueprint"
  # Deploy newly downloaded
  "$DEPLOY_SCRIPT" -b "$blueprint"
  # Save new version
  "$VERSION_SCRIPT" -b "$blueprint" --save "$latest_version"

  return 0
}

function _uninstall() {
  local blueprint=$1

  if [[ "$blueprint" != *.bp ]]; then
    blueprint="${blueprint}.bp"
  fi

  # Remove directory structure
  "$DIRECTORIES_SCRIPT" -b "$blueprint" --uninstall
  # Remove files
  sudo "$FILES_SCRIPT" -b "$blueprint" --uninstall
}

function get_blueprints() {
  local -n ref_blueprints_array=$1

  shopt -s extglob nullglob

  # Create array
  ref_blueprints_array=("$BLUEPRINTS_SOURCE_DIR"/*)
  # remove leading $BLUEPRINTS_SOURCE_DIR:
  ref_blueprints_array=("${ref_blueprints_array[@]#"$BLUEPRINTS_SOURCE_DIR/"}")
}

function get_installed_services() {
  # shellcheck disable=SC2178
  local -n ref_services_array=$1
  declare -a blueprints=()
  get_blueprints blueprints

  for bp in "${blueprints[@]}"; do
    # shellcheck disable=SC2155
    local bp_file=$(find "$BLUEPRINTS_SOURCE_DIR" -type f -name "$bp")
    if [ -z "$bp_file" ]; then continue; fi

    service_name=$(cat "$bp_file" | grep "SERVICE_NAME=" | cut -d "=" -f2 | tr -d '"')
    service_working_dir=$(cat "$bp_file" | grep "SERVICE_WORKING_DIR=" | cut -d "=" -f2 | tr -d '"')
    service_version_file="$service_working_dir/$service_name.version"

    # If there's no $service_working_dir, skip
    if [ ! -d "$service_working_dir" ]; then
      continue
    fi

    # If there's no .version file, skip
    if [ ! -f "$service_version_file" ]; then
      continue
    fi

    service_version=$(cat "$service_version_file")

    # Check if there's a version number stored in the file
    if [ -z "$service_version" ] || [[ "$service_version" == "0" ]]; then
      continue
    fi

    ref_services_array+=("$service_name")
  done
}

function _interactive() {
  echo "KGSM - Interactive menu - $(get_version)

Start the script with '--interactive -h' or '--interactive --help' for a detailed description of each menu option
Press CTRL+C to exit at any time.

"
  PS3="Choose an action: "

  local action=""
  local args=""

  declare -a menu_options=(
    "Install"
    "Check for update"
    "Update"
    "Create backup"
    "Restore backup"
    "Uninstall"
  )

  declare -A arg_map=(
    ["Install"]=--install
    ["Check for update"]=--check-update
    ["Update"]=--update
    ["Create backup"]=--create-backup
    ["Restore backup"]=--restore-backup
    ["Uninstall"]=--uninstall
  )

  # Select action first
  select opt in "${menu_options[@]}"; do
    if [[ -z $opt ]]; then
      echo "Didn't understand \"$REPLY\" " >&2
      REPLY=
    else
      action="${arg_map[$opt]}"
      break
    fi
  done

  # Depending on the action, load up a list of all blueprints,
  # all services or only the installed services
  declare -a blueprints_or_services=()

  case "$action" in
  --install)
    get_blueprints blueprints_or_services
    ;;
  --check-update)
    get_installed_services blueprints_or_services
    ;;
  --update)
    get_installed_services blueprints_or_services
    ;;
  --create-backup)
    get_installed_services blueprints_or_services
    ;;
  --restore-backup)
    get_blueprints blueprints_or_services
    ;;
  --uninstall)
    get_installed_services blueprints_or_services
    ;;
  *) echo ">>> ${0##*/} Error: Unknown action $action" >&2 && return 1 ;;
  esac

  [[ "${#blueprints_or_services[@]}" -eq 0 ]] && echo ">>> ${0##*/} Error: No blueprints or services found, exiting" >&2 && return 1

  PS3="Choose a blueprint/service: "

  # Select blueprint/service for the action
  select bp in "${blueprints_or_services[@]}"; do
    if [[ -z $bp ]]; then
      echo "Didn't understand \"$REPLY\" " >&2
      REPLY=
    else
      args="$bp"
      break
    fi
  done

  # Recursivelly call the script with the given params.
  # --install has a different arg order
  case "$action" in
  # Arg splitting is intended
  --install) ./"$0" $action $args ;;
  *) ./"$0" --service $args $action ;;
  esac
}

# Exit code
ret=0

# If it's started with no args, default to interactive mode
[[ "$#" -eq 0 ]] && _interactive || ret=$?

while [[ "$#" -gt 0 ]]; do
  case $1 in
  --create-blueprint)
    shift
    # [[ -z "$1" ]] && echo ">>> ${0##*/} Error: Missing arguments" >&2 && exit 1
    case "$1" in
    -h | --help) "$CREATE_BLUEPRINT_SCRIPT" --help && exit 0 ;;
    *) "$CREATE_BLUEPRINT_SCRIPT" "$@" && exit $? ;;
    esac
    ;;
  --install)
    blueprint=
    install_dir=$KGSM_DEFAULT_INSTALL_DIR
    shift
    [[ -z "$1" ]] && echo ">>> ${0##*/} Error: Missing argument <blueprint>" >&2 && exit 1
    blueprint="$1"
    shift
    case "$1" in
    --dir)
      shift
      install_dir="$1"
      ;;
    esac
    _install "$blueprint" "$install_dir" && exit $?
    ;;
  --get-blueprints)
    declare -a bps=()
    get_blueprints bps
    for bp in "${bps[@]}"; do
      echo "$bp"
    done
    exit 0
    ;;
  --get-ip)
    curl https://icanhazip.com 2>/dev/null && exit 0 || ret=$?
    ;;
  --update)
    update_script "$@" && exit $?
    ;;
  --service)
    shift
    [[ -z "$1" ]] && echo ">>> ${0##*/} Error: Missing argument <service>" >&2 && exit 1
    service=$1
    shift
    [[ -z "$1" ]] && usage && exit 1
    case "$1" in
    --get-logs)
      journalctl -n "10" -u "$service" --no-pager && exit 0 || ret=$?
      ;;
    --get-status)
      systemctl status "$service" | head -n 3 && exit 0 || ret=$?
      ;;
    --is-active)
      systemctl is-active "$service" && exit 0 || ret=$?
      ;;
    --start)
      systemctl start "$service" && exit 0 || ret=$?
      ;;
    --stop)
      systemctl stop "$service" && exit 0 || ret=$?
      ;;
    --restart)
      systemctl restart "$service" && exit 0 || ret=$?
      ;;
    --check-update)
      case "$1" in
      -h | --help) "$VERSION_SCRIPT" --help && exit 0 ;;
      *) "$VERSION_SCRIPT" -b "$service" --compare && exit $? ;;
      esac
      ;;
    --update)
      case "$1" in
      -h | --help) "$UPDATE_SCRIPT" --help && exit 0 ;;
      *) "$UPDATE_SCRIPT" -b "$service" || ret=$? ;;
      esac
      ;;
    --create-backup)
      case "$1" in
      -h | --help) "$BACKUP_SCRIPT" --help && exit 0 ;;
      *) "$BACKUP_SCRIPT" -b "$service" --create || ret=$? ;;
      esac
      ;;
    --restore-backup)
      case "$1" in
      -h | --help) "$BACKUP_SCRIPT" --help && exit 0 ;;
      *) "$BACKUP_SCRIPT" -b "$service" --create || ret=$? ;;
      esac
      ;;
    --uninstall)
      _uninstall "$service" || ret=$?
      ;;
    *) usage && exit 1 ;;
    esac
    ;;
  --interactive)
    shift
    case "$1" in
    -h | --help) usage_interactive && exit 0 ;;
    *) _interactive || ret=$? ;;
    esac
    ;;
  --install-requirements)
    sudo "$REQUIREMENTS_SCRIPT" && exit $?
    ;;
  -v | --version)
    get_version && exit 0
    ;;
  *)
    echo ">>> ${0##*/} Error: Invalid argument $1" >&2 && usage && exit 1
    ;;
  esac
  shift
done

exit "$ret"
