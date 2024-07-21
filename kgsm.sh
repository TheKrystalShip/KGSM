#!/bin/bash

# Read configuration file
CONFIG_FILE="$(find "$(dirname "$0")" -type f -name config.cfg)"
if [ -f "$CONFIG_FILE" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    # Ignore comment lines and empty lines
    if [[ "$line" =~ ^#.*$ ]] || [[ -z "$line" ]]; then
      continue
    fi
    # Export each key-value pair
    export "${line?}"
  done <"$CONFIG_FILE"

  if [ -z "$KGSM_ROOT" ]; then
    KGSM_ROOT="$(dirname "$0")"
  fi

  export KGSM_ROOT
else
  CONFIG_FILE_EXAMPLE="$(find "$(dirname "$0")" -type f -name config.cfg.example)"
  if [ -f "$CONFIG_FILE_EXAMPLE" ]; then
    cp "$CONFIG_FILE_EXAMPLE" "$(dirname "$0")"/config.cfg
    echo "${0##*/} WARNING: config.cfg not found, created new file" >&2
    echo "${0##*/} INFO: Please ensure configuration is correct before running the script again" >&2
    exit 0
  else
    echo "${0##*/} ERROR: Could not find config.cfg.example, install might be broken" >&2
    echo "${0##*/} INFO: Try to repair the install by running ${0##*/} --update --force" >&2
    exit 1
  fi
fi

set -eo pipefail

debug=
# shellcheck disable=SC2199
if [[ $@ =~ "--debug" ]]; then
  debug=" --debug"
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

function get_version() {
  [[ -f "$KGSM_ROOT/version.txt" ]] && cat "$KGSM_ROOT/version.txt"
}

DESCRIPTION="Krystal Game Server Manager - $(get_version)

Create, install, and manage game servers on Linux.

If you have any problems while using KGSM, please don't hesitate to create an
issue on GitHub: https://github.com/TheKrystalShip/KGSM/issues"

function usage() {
  printf "%s

Usage:
  ./kgsm.sh [option]

Options:
  \e[4mGeneral\e[0m
    -h, --help                  Print this help message.
    --update                    Update KGSM to the latest version.
      --force                   Ignore version check and download the latest
                                version available.
    --ip                        Get the external server IP used to connect to
                                the server.
    --interactive               Start the script in interactive mode.
      -h, --help                Print help information for interactive mode.
    -v, --version               Print the KGSM version.

  \e[4mBlueprints\e[0m
    --create-blueprint          Create a new blueprints file.
      -h, --help                Print help information about the blueprint
                                creation process.
    --blueprints                List all available blueprints.
    --install BLUEPRINT         Run the installation process for an existing
                                blueprint.
                                BLUEPRINT must be the name of a blueprint.
                                Run --blueprints to see available options.

  \e[4mServices\e[0m
    --service SERVICE [OPTION]  Issue commands to a service.
                                SERVICE must be the name of a server or a
                                blueprint.
                                OPTION represents one of the following:
      --logs                    Return the last 10 lines of the service's log.
      --status                  Return a detailed status of the service.
      --is-active               Check if the service is active.
      --start                   Start the service.
      --stop                    Stop the service.
      --restart                 Restart the service.
      -v, --version             Provide version information.
                                Running this with no other argument has the same
                                outcome as adding the --installed argument.
        --installed             Print the currently installed version.
        --latest                Print the latest available version number.
      --check-update            Check if a new version is available.
      --update                  Run the update process.
        -h, --help              Print help information for the update process.
      --create-backup           Create a backup of the currently installed
                                version, if any.
        -h, --help              Print help information for the backup process.
      --restore-backup NAME     Restore a backup.
                                NAME is the backup name.
        -h, --help              Print help information for the backup process.
      --uninstall               Run the uninstall process.
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

function check_for_update() {
  # shellcheck disable=SC2155
  local script_version=$(get_version)
  local version_url="https://raw.githubusercontent.com/TheKrystalShip/KGSM/main/version.txt"

  # Fetch the latest version number
  if command -v wget >/dev/null 2>&1; then
    LATEST_VERSION=$(wget -q -O - "$version_url")
  else
    echo "ERROR: wget is required but not installed" >&2 && return 1
  fi

  # Compare the versions
  if [ "$script_version" != "$LATEST_VERSION" ]; then
    printf "\033[0;33mNew version available: %s
Please run ./%s --update to get the latest version\033[0m\n\n" "$LATEST_VERSION" "${0##*/}" >&2
  fi
}

# Define a function to update the script and other files
function update_script() {
  # Define the raw URL of the script and version file
  # shellcheck disable=SC2155
  local script_version=$(get_version)
  local version_url="https://raw.githubusercontent.com/TheKrystalShip/KGSM/main/version.txt"
  local repo_archive_url="https://github.com/TheKrystalShip/KGSM/archive/refs/heads/main.tar.gz"

  local force=0
  for arg in "$@"; do
    shift
    [ "$arg" = "--force" ] && force=1
  done

  echo "Checking for updates..." >&2

  # Fetch the latest version number
  if command -v wget >/dev/null 2>&1; then
    LATEST_VERSION=$(wget -q -O - "$version_url")
  else
    echo "ERROR: wget is required to check for updates." >&2
    return 1
  fi

  # Compare the versions
  if [ "$script_version" != "$LATEST_VERSION" ] || [ "$force" -eq 1 ]; then
    echo "${0##*/} New version available: $LATEST_VERSION. Updating..." >&2

    # Backup the current script
    cp "$0" "${0}.${script_version:-0}.bak"
    echo "${0##*/} Backup of the current script created at ${0}.bak" >&2

    # Download the repository tarball
    if command -v wget >/dev/null 2>&1; then
      wget -O "kgsm.tar.gz" "$repo_archive_url" 2>/dev/null
    else
      echo "ERROR: wget is required to download the update." >&2
      return 1
    fi

    # Extract the tarball
    if tar -xzf "kgsm.tar.gz"; then
      # Overwrite the existing files with the new ones
      cp -r KGSM-main/* .
      chmod +x kgsm.sh modules/*.sh
      echo "${0##*/} KGSM updated successfully to version $LATEST_VERSION." >&2

      # Cleanup
      rm -rf "KGSM-main" "kgsm.tar.gz"
    else
      echo "ERROR: Failed to extract the update. Reverting to the previous version." >&2
      mv "${0}.${script_version:-0}.bak" "$0"
    fi
  else
    echo "${0##*/} You are already using the latest version: $script_version." >&2
  fi

  return 0
}

# Only call subscripts with sudo if the current user isn't root
SUDO=$([[ "$EUID" -eq 0 ]] && echo "" || echo "sudo -E")

check_for_update

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

# Trap CTRL-C
trap "echo "" && exit" INT

COMMON_SCRIPT="$(find "$KGSM_ROOT" -type f -name common.sh)"

# shellcheck disable=SC1090
source "$COMMON_SCRIPT" || exit 1

CREATE_BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name create_blueprint.sh)"
[[ -z "$CREATE_BLUEPRINT_SCRIPT" ]] && echo "ERROR: Failed to load create_blueprint.sh" >&2 && exit 1

DIRECTORIES_SCRIPT="$(find "$KGSM_ROOT" -type f -name directories.sh)"
[[ -z "$DIRECTORIES_SCRIPT" ]] && echo "ERROR: Failed to load directories.sh" >&2 && exit 1

FILES_SCRIPT="$(find "$KGSM_ROOT" -type f -name files.sh)"
[[ -z "$FILES_SCRIPT" ]] && echo "ERROR: Failed to load files.sh" >&2 && exit 1

VERSION_SCRIPT="$(find "$KGSM_ROOT" -type f -name version.sh)"
[[ -z "$VERSION_SCRIPT" ]] && echo "ERROR: Failed to load version.sh" >&2 && exit 1

DOWNLOAD_SCRIPT="$(find "$KGSM_ROOT" -type f -name download.sh)"
[[ -z "$DOWNLOAD_SCRIPT" ]] && echo "ERROR: Failed to load download.sh" >&2 && exit 1

DEPLOY_SCRIPT="$(find "$KGSM_ROOT" -type f -name deploy.sh)"
[[ -z "$DEPLOY_SCRIPT" ]] && echo "ERROR: Failed to load deploy.sh" >&2 && exit 1

UPDATE_SCRIPT="$(find "$KGSM_ROOT" -type f -name update.sh)"
[[ -z "$UPDATE_SCRIPT" ]] && echo "ERROR: Failed to load update.sh" >&2 && exit 1

BACKUP_SCRIPT="$(find "$KGSM_ROOT" -type f -name backup.sh)"
[[ -z "$BACKUP_SCRIPT" ]] && echo "ERROR: Failed to load backup.sh" >&2 && exit 1

function _install() {
  local blueprint=$1
  local install_dir=$2

  if [[ "$blueprint" != *.bp ]]; then
    blueprint="${blueprint}.bp"
  fi

  # shellcheck disable=SC2155
  local blueprint_abs_path="$(find "$BLUEPRINTS_SOURCE_DIR" -type f -name "$blueprint" -print -quit)"
  # shellcheck disable=SC2155
  local service_name=$(grep "SERVICE_NAME=" <"$blueprint_abs_path" | cut -d "=" -f2 | tr -d '"')

  # If the path doesn't contain the service name, append it
  if [[ "$install_dir" != *$service_name ]]; then
    install_dir=$install_dir/$service_name
  fi

  if [ ! -d "$install_dir" ]; then
    if ! mkdir -p "$install_dir"; then
      echo "ERROR: Failed to create directory $install_dir" >&2
      return 1
    fi
  fi

  if [ ! -w "$install_dir" ]; then
    echo "ERROR: You don't have write permissions for $install_dir" >&2
    return 1
  fi

  # IMPORTANT
  # Once the installation directory has been established, it is essential
  # that it gets saved into the blueprint itself because all other scripts
  # expect the blueprint to have a $SERVICE_WORKING_DIR variable

  # If SERVICE_WORKING_DIR already exists in the blueprint, replace the value
  if grep -q "SERVICE_WORKING_DIR=" <"$blueprint_abs_path"; then
    sed -i "/SERVICE_WORKING_DIR=*/c\SERVICE_WORKING_DIR=$install_dir" "$blueprint_abs_path" >/dev/null
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
  "$DIRECTORIES_SCRIPT" -b "$blueprint" --install $debug || return $?
  # Create necessary files
  $SUDO "$FILES_SCRIPT" -b "$blueprint" --install $debug || return $?
  # Run the download process
  "$DOWNLOAD_SCRIPT" -b "$blueprint" $debug || return $?
  # Deploy newly downloaded
  "$DEPLOY_SCRIPT" -b "$blueprint" $debug || return $?
  # Save new version
  "$VERSION_SCRIPT" -b "$blueprint" --save "$latest_version" $debug || return $?

  return 0
}

function _uninstall() {
  local blueprint=$1

  if [[ "$blueprint" != *.bp ]]; then
    blueprint="${blueprint}.bp"
  fi

  # Remove directory structure
  "$DIRECTORIES_SCRIPT" -b "$blueprint" --uninstall $debug || return $?
  # Remove files
  $SUDO "$FILES_SCRIPT" -b "$blueprint" --uninstall $debug || return $?
}

function get_blueprints() {
  local -n ref_blueprints_array=$1

  shopt -s extglob nullglob

  # Create array
  ref_blueprints_array=("$BLUEPRINTS_DEFAULT_SOURCE_DIR"/*.bp)
  # remove leading $BLUEPRINTS_DEFAULT_SOURCE_DIR:
  ref_blueprints_array=("${ref_blueprints_array[@]#"$BLUEPRINTS_DEFAULT_SOURCE_DIR/"}")
}

function get_installed_services() {
  # shellcheck disable=SC2178
  local -n ref_services_array=$1
  declare -a blueprints=()
  get_blueprints blueprints

  for bp in "${blueprints[@]}"; do
    # shellcheck disable=SC2155
    local bp_file=$(find "$BLUEPRINTS_SOURCE_DIR" -type f -name "$bp" -print -quit)
    [[ ! -f "$bp_file" ]] && continue

    service_name=$(grep "SERVICE_NAME=" <"$bp_file" | cut -d "=" -f2 | tr -d '"')
    service_working_dir=$(grep "SERVICE_WORKING_DIR=" <"$bp_file" | cut -d "=" -f2 | tr -d '"')
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
  echo "$DESCRIPTION

Start the script with '--interactive -h' or '--interactive --help' for a
detailed description of each menu option.
Press CTRL+C to exit at any time.

KGSM - Interactive menu
"

  PS3="Choose an action: "

  local action=
  local blueprint_or_service=

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
  *) echo "ERROR: Unknown action $action" >&2 && return 1 ;;
  esac

  [[ "${#blueprints_or_services[@]}" -eq 0 ]] && echo "ERROR: No blueprints or services found, exiting" >&2 && return 1

  PS3="Choose a blueprint/service: "

  # Select blueprint/service for the action
  select bp in "${blueprints_or_services[@]}"; do
    if [[ -z $bp ]]; then
      echo "Didn't understand \"$REPLY\" " >&2
      REPLY=
    else
      blueprint_or_service="$bp"
      break
    fi
  done

  # Recursivelly call the script with the given params.
  # --install has a different arg order
  case "$action" in
  --install)
    install_directory=${KGSM_DEFAULT_INSTALL_DIRECTORY:-}
    if [ -z "$install_directory" ]; then
      echo "KGSM_DEFAULT_INSTALL_DIRECTORY is not set in the configuration file, please specify an installation directory" >&2
      read -r -p "Installation directory: " install_directory && [[ -n $install_directory ]] || exit 1
    fi
    # shellcheck disable=SC2086
    "$0" $action $blueprint_or_service --dir $install_directory $debug
    ;;
  --restore-backup)
    BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"
    # shellcheck disable=SC1090
    source "$BLUEPRINT_SCRIPT" "$blueprint_or_service" || exit 1
    shopt -s extglob nullglob

    # Restore backup requires specifying which one to restore
    backup_to_restore=
    # Create array
    backups_array=("$SERVICE_BACKUPS_DIR"/*)
    # remove leading $SERVICE_BACKUPS_DIR:
    backups_array=("${backups_array[@]#"$SERVICE_BACKUPS_DIR/"}")

    if ((${#backups_array[@]} < 1)); then
      echo "No backups found. Exiting." >&2
      return 0
    fi

    PS3="Choose a backup to restore: "

    select backup in "${backups_array[@]}"; do
      if [[ -z $backup ]]; then
        echo "Didn't understand \"$REPLY\" " >&2
        REPLY=
      else
        backup_to_restore="$backup"
        break
      fi
    done
    # shellcheck disable=SC2086
    "$0" --service $blueprint_or_service $action $backup_to_restore $debug
    ;;
  *)
    # shellcheck disable=SC2086
    $0 --service $blueprint_or_service $action $debug
    ;;
  esac
}

# If it's started with no args, default to interactive mode
[[ "$#" -eq 0 ]] && _interactive && exit $?

while [[ "$#" -gt 0 ]]; do
  case $1 in
  --create-blueprint)
    shift
    [[ -z "$1" ]] && echo "ERROR: Missing arguments" >&2 && exit 1
    case "$1" in
    -h | --help) "$CREATE_BLUEPRINT_SCRIPT" --help $debug && exit $? ;;
    *)
      # shellcheck disable=SC2068
      "$CREATE_BLUEPRINT_SCRIPT" $@ $debug && exit $?
      ;;
    esac
    ;;
  --install)
    shift
    [[ -z "$1" ]] && echo "ERROR: Missing argument <blueprint>" >&2 && exit 1
    bp_to_install="$1"
    install_dir=${KGSM_DEFAULT_INSTALL_DIRECTORY:-}
    shift
    if [ -n "$1" ]; then
      case "$1" in
      --dir)
        shift
        [[ -z "$1" ]] && echo "ERROR: Missing argument <dir>" >&2 && exit 1
        install_dir="$1"
        ;;
      *)
        echo "ERROR: Unknown argument $1" >&2 && exit 1
        ;;
      esac
    fi
    [[ -z "$install_dir" ]] && echo "ERROR: Missing argument <dir>" >&2 && exit 1
    _install "$bp_to_install" "$install_dir" && exit $?
    ;;
  --blueprints)
    declare -a bps=()
    get_blueprints bps
    for bp in "${bps[@]}"; do
      echo "$bp"
    done
    exit 0
    ;;
  --ip)
    if command -v wget >/dev/null 2>&1; then
      wget -qO- https://icanhazip.com && exit $?
    else
      echo "ERROR: wget is required but not installed" >&2
      exit 1
    fi
    ;;
  --update)
    update_script "$@" && exit $?
    ;;
  --service)
    shift
    [[ -z "$1" ]] && echo "ERROR: Missing argument <service>" >&2 && exit 1
    service=$1
    shift
    [[ -z "$1" ]] && echo "ERROR: Missing argument [OPTION]" >&2 && exit 1
    case "$1" in
    --logs)
      journalctl -n "10" -u "$service" --no-pager && exit $?
      ;;
    --status)
      systemctl status "$service" | head -n 3 && exit $?
      ;;
    --is-active)
      systemctl is-active "$service" && exit $?
      ;;
    --start)
      $SUDO systemctl start "$service" && exit $?
      ;;
    --stop)
      $SUDO systemctl stop "$service" && exit $?
      ;;
    --restart)
      $SUDO systemctl restart "$service" && exit $?
      ;;
    -v | --version)
      shift
      [[ -z "$1" ]] && "$VERSION_SCRIPT" -b "$service" --installed $debug && exit $?
      case "$1" in
      --installed) "$VERSION_SCRIPT" -b "$service" --installed $debug && exit $? ;;
      --latest) "$VERSION_SCRIPT" -b "$service" --latest $debug && exit $? ;;
      *) echo "ERROR: Invalid argument $1" >&2 && usage && exit 1 ;;
      esac
      ;;
    --check-update)
      case "$1" in
      -h | --help) "$VERSION_SCRIPT" --help && exit $? ;;
      *) "$VERSION_SCRIPT" -b "$service" --compare $debug && exit $? ;;
      esac
      ;;
    --update)
      case "$1" in
      -h | --help) "$UPDATE_SCRIPT" --help && exit $? ;;
      *) "$UPDATE_SCRIPT" -b "$service" $debug && exit $? ;;
      esac
      ;;
    --create-backup)
      case "$1" in
      -h | --help) "$BACKUP_SCRIPT" --help && exit $? ;;
      *) "$BACKUP_SCRIPT" -b "$service" --create $debug && exit $? ;;
      esac
      ;;
    --restore-backup)
      [[ -z "$1" ]] && echo "ERROR: Missing argument <backup>" >&2 && exit 1
      shift
      case "$1" in
      -h | --help) "$BACKUP_SCRIPT" --help && exit $? ;;
      *) "$BACKUP_SCRIPT" -b "$service" --restore "$1" $debug && exit $? ;;
      esac
      ;;
    --uninstall)
      _uninstall "$service" && exit $?
      ;;
    *) echo "ERROR: Invalid argument $1" >&2 && exit 1 ;;
    esac
    ;;
  --interactive)
    shift
    case "$1" in
    -h | --help) usage_interactive && exit $? ;;
    *) _interactive && exit $? ;;
    esac
    ;;
  -v | --version)
    get_version && exit 0
    ;;
  *)
    echo "ERROR: Invalid argument $1" >&2 && exit 1
    ;;
  esac
  shift
done

exit 0
