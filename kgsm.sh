#!/bin/bash

VERSION="0.1"

function usage() {
  echo "Krystal Game Server Manager - v$VERSION
Used to create, install and manage game servers on Linux.

All of this is achieved through a series of script files found under
\$KGSM_ROOT/scripts; they can be executed manually by themselves if needed but
this script aims to bundle together some of the more common uses and present
them in a simple way through an interactive terminal menu system.

Most of the menu options are interactive and they might require user input at
various steps, as so this script is not meant to be ran programatically and
instead a user should be present when interacting with the script.

Usage:
    ./${0##*/} [-h | --help]

Menu options:
    Add blueprint       Create a new blueprint file. It will be stored under
                        \$KGSM_ROOT/blueprints.
                        It will prompt for input on various details regarding
                        the blueprint.

    Install             Run the installation process for an existing blueprint.
                        It will only prompt for input if there's any issues
                        during the install process.

    Check for update    Check if a new version of a server is available.
                        It will print if a new version is found, otherwise
                        it will fail with exit code 1.

    Update              Runs a version check for a new version, creates a backup
                        of the currently installed version, downloads the new
                        version and deploys it.
                        Highly interactive since it has to run through multiple
                        different steps.

    Create backup       Creates a backup of a server. It will output the full
                        path to the newly created backup directory.

    Restore Backup      Restores a backup of a server
                        It will prompt to select a backup to restore and
                        also if the current installation directory of the
                        server is not empty.

    Uninstall           Runs the uninstall process for a server. Warning: This
                        will remove everything other than the blueprint file
                        the server is based on.
"
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
  -h | --help)
    usage && exit 0
    ;;
  *)
    echo ">>> ${0##*/} Error: Invalid argument $1" >&2
    usage && exit 1
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
    echo ">>> ${0##*/} ERROR: KGSM_ROOT environmental variable not found, exiting." >&2
    exit 1
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

DIRECTORIES_SCRIPT="$(find "$KGSM_ROOT" -type f -name directories.sh)"
if [ -z "$DIRECTORIES_SCRIPT" ]; then
  echo ">>> ${0##*/} ERROR: Failed to load directories.sh" >&2
  exit 1
fi

FILES_SCRIPT="$(find "$KGSM_ROOT" -type f -name files.sh)"
if [ -z "$FILES_SCRIPT" ]; then
  echo ">>> ${0##*/} ERROR: Failed to load files.sh" >&2
  exit 1
fi

VERSION_SCRIPT="$(find "$KGSM_ROOT" -type f -name version.sh)"
if [ -z "$VERSION_SCRIPT" ]; then
  echo ">>> ${0##*/} ERROR: Failed to load version.sh" >&2
  exit 1
fi

CREATE_BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name create_blueprint.sh)"
if [ -z "$CREATE_BLUEPRINT_SCRIPT" ]; then
  echo ">>> ${0##*/} ERROR: Failed to load create_blueprint.sh" >&2
  exit 1
fi

DOWNLOAD_SCRIPT_FILE="$(find "$KGSM_ROOT" -type f -name download.sh)"
if [ -z "$DOWNLOAD_SCRIPT_FILE" ]; then
  echo ">>> ${0##*/} ERROR: Failed to load download.sh" >&2
  exit 1
fi

DEPLOY_SCRIPT_FILE="$(find "$KGSM_ROOT" -type f -name deploy.sh)"
if [ -z "$DEPLOY_SCRIPT_FILE" ]; then
  echo ">>> ${0##*/} ERROR: Failed to load deploy.sh" >&2
  exit 1
fi

UPDATE_SCRIPT="$(find "$KGSM_ROOT" -type f -name update.sh)"
if [ -z "$UPDATE_SCRIPT" ]; then
  echo ">>> ${0##*/} ERROR: Failed to load update.sh" >&2
  exit 1
fi

BACKUP_SCRIPT="$(find "$KGSM_ROOT" -type f -name backup.sh)"
if [ -z "$BACKUP_SCRIPT" ]; then
  echo ">>> ${0##*/} ERROR: Failed to load backup.sh" >&2
  exit 1
fi

function _add_blueprint() {
  echo "KGSM - Create blueprint - v$VERSION"

  ("$CREATE_BLUEPRINT_SCRIPT")
}

function _install() {
  echo "KGSM - Install blueprint - v$VERSION"
  PS3="Choose a blueprint: "

  declare -a blueprints
  get_blueprints blueprints

  if ((${#blueprints[@]} < 1)); then
    printf 'No blueprints found. Exiting.\n'
    return 0
  fi

  # shellcheck disable=SC2155
  local choice=$(get_choice blueprints)

  local blueprint_abs_path="$BLUEPRINTS_SOURCE_DIR/$choice"
  # shellcheck disable=SC2155
  local service_name=$(cat "$blueprint_abs_path" | grep "SERVICE_NAME=" | cut -d "=" -f2 | tr -d '"')
  local install_dir=""

  while true; do
    read -rp "Install directory: " install_dir

    # If the path doesn't contain the service name, append it
    if [[ "$install_dir" != *$service_name ]]; then
      if [[ "$install_dir" == *\/ ]]; then
        install_dir="${install_dir}${service_name}"
      else
        install_dir="$install_dir/$service_name"
      fi
    fi

    if [ ! -d "$install_dir" ]; then
      if ! mkdir -p "$install_dir"; then
        echo ">>> ${0##*/} ERROR: Failed to create directory $install_dir" >&2
        return 1
      fi
    fi

    if [ ! -w "$install_dir" ]; then
      echo ">>> ${0##*/} ERROR: You don't have write permissions for $install_dir, specify a different directory" >&2
      return 1
    fi

    break
  done

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

  # First create directory structure
  "$DIRECTORIES_SCRIPT" -b "$choice" --install
  # Create necessary files
  sudo "$FILES_SCRIPT" -b "$choice" --install
  # Run the download process
  "$DOWNLOAD_SCRIPT_FILE" -b "$choice"
  # Deploy newly downloaded
  "$DEPLOY_SCRIPT_FILE" -b "$choice"
  # Save new version
  "$VERSION_SCRIPT" -b "$choice" --save "$latest_version"

  return 0
}

function _update() {
  echo "KGSM - Update - v$VERSION"

  declare -a blueprints
  get_blueprints blueprints

  # shellcheck disable=SC2155
  local choice=$(get_choice blueprints)
  # shellcheck disable=SC2155
  local latest_version=$("$VERSION_SCRIPT" -b "$choice" --latest)

  ("$UPDATE_SCRIPT" -b "$choice")
}

function _check_for_update() {
  echo "KGSM - Check for update - v$VERSION"

  declare -a services
  get_installed_services services

  # shellcheck disable=SC2155
  local choice=$(get_choice services)

  ("$VERSION_SCRIPT" -b "$choice" --compare)
}

function _create_backup() {
  echo "KGSM - Create backup - v$VERSION"
  PS3="Choose a service: "

  declare -a services
  get_installed_services services

  # shellcheck disable=SC2155
  local choice=$(get_choice services)

  ("$BACKUP_SCRIPT" -b "$choice" --create)
}

function _restore_backup() {
  echo "KGSM - Restore backup - v$VERSION"
  PS3="Choose a service: "

  declare -a services
  get_services services

  # shellcheck disable=SC2155
  local choice=$(get_choice services)

  ("$BACKUP_SCRIPT" -b "$choice" --restore)
}

function _uninstall() {
  echo "KGSM - Uninstall - v$VERSION"
  PS3="Choose a service: "

  declare -a services
  get_installed_services services

  if [ "${#services[@]}" -eq 0 ]; then
    echo "${0##*/} INFO: No services installed" >&2
    return
  fi

  # shellcheck disable=SC2155
  local choice=$(get_choice services)

  # Remove directory structure
  "$DIRECTORIES_SCRIPT" -b "$choice" --uninstall
  # Remove files
  sudo "$FILES_SCRIPT" -b "$choice" --uninstall
}

function get_choice() {
  local -n ref_arr=$1

  select choice in "${ref_arr[@]}"; do
    if [[ -z $choice ]]; then
      echo "Didn't understand \"$REPLY\" " >&2
      REPLY=
    else
      echo "$choice"
      return
    fi
  done
}

function get_blueprints() {
  local -n ref_blueprints_array=$1

  shopt -s extglob nullglob

  # Create array
  ref_blueprints_array=("$BLUEPRINTS_SOURCE_DIR"/*)
  # remove leading $BLUEPRINTS_SOURCE_DIR:
  ref_blueprints_array=("${ref_blueprints_array[@]#"$BLUEPRINTS_SOURCE_DIR/"}")
}

function get_services() {
  local -n ref_services_array=$1
  declare -a blueprints=()
  get_blueprints blueprints

  for bp in "${blueprints[@]}"; do
    # shellcheck disable=SC2002
    service_name=$(cat "$BLUEPRINTS_SOURCE_DIR/$bp" | grep "SERVICE_NAME=" | cut -d "=" -f2 | tr -d '"')
    # shellcheck disable=SC2002
    service_working_dir=$(cat "$BLUEPRINTS_SOURCE_DIR/$bp" | grep "SERVICE_WORKING_DIR=" | cut -d "=" -f2 | tr -d '"')

    # If there's no $service_working_dir, skip
    if [ ! -d "$service_working_dir" ]; then
      continue
    fi

    ref_services_array+=("$service_name")
  done
}

function get_installed_services() {
  # shellcheck disable=SC2178
  local -n ref_services_array=$1
  declare -a blueprints=()
  get_blueprints blueprints

  for bp in "${blueprints[@]}"; do
    service_name=$(cat "$BLUEPRINTS_SOURCE_DIR/$bp" | grep "SERVICE_NAME=" | cut -d "=" -f2 | tr -d '"')
    service_working_dir=$(cat "$BLUEPRINTS_SOURCE_DIR/$bp" | grep "SERVICE_WORKING_DIR=" | cut -d "=" -f2 | tr -d '"')
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

function init() {
  echo "KGSM - Main menu - v$VERSION
Start the script with -h or --help to see a detailed description
of each menu option
Press CTRL+C to exit at any time.
"

  PS3="Choose an action: "

  declare -A services=()
  get_installed_services services

  declare -a menu_options=(
    "Add blueprint"
    "Install"
    "Check for update"
    "Update"
    "Create backup"
    "Restore backup"
    "Uninstall"
  )

  declare -A menu_options_functions=(
    ["Add blueprint"]=_add_blueprint
    ["Install"]=_install
    ["Check for update"]=_check_for_update
    ["Update"]=_update
    ["Create backup"]=_create_backup
    ["Restore backup"]=_restore_backup
    ["Uninstall"]=_uninstall
  )

  select opt in "${menu_options[@]}"; do
    if [[ -z $opt ]]; then
      echo "Didn't understand \"$REPLY\" " >&2
      REPLY=
    else
      # Here we check that the option is in the associative array
      if [[ -z "${menu_options_functions[$opt]}" ]]; then
        echo "Invalid option. Try another one." >&2
      else
        # Here we execute the function
        "${menu_options_functions[$opt]}"
        break
      fi
    fi
  done
}

init "$@"
