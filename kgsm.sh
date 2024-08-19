#!/bin/bash

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

# Absolute path to this script file
SELF_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# Read configuration file
CONFIG_FILE="$(find "$SELF_PATH" -type f -name config.ini)"
if [ -f "$CONFIG_FILE" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    # Ignore comment lines and empty lines
    if [[ "$line" =~ ^#.*$ ]] || [[ -z "$line" ]]; then continue; fi
    # Export each key-value pair
    export "${line?}"
  done <"$CONFIG_FILE"
  # shellcheck disable=SC2155
  [[ -z "$KGSM_ROOT" ]] && KGSM_ROOT="$SELF_PATH"
  export KGSM_ROOT
  export KGSM_CONFIG_LOADED=1
else
  CONFIG_FILE_EXAMPLE="$(find "$SELF_PATH" -type f -name config.default.ini)"
  if [ -f "$CONFIG_FILE_EXAMPLE" ]; then
    cp "$CONFIG_FILE_EXAMPLE" "$SELF_PATH/config.ini"
    echo "${0##*/} WARNING: config.ini not found, created new file" >&2
    echo "${0##*/} INFO: Please ensure configuration is correct before running the script again" >&2
    exit 0
  else
    echo "${0##*/} ERROR: Could not find config.default.ini, install might be broken" >&2
    echo "${0##*/} INFO: Try to repair the install by running ${0##*/} --update --force" >&2
    exit 1
  fi
fi

set -eo pipefail

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
  $(basename "$0") [option]

Options:
  \e[4mGeneral\e[0m
    -h, --help                  Print this help message.

      [--interactive]           Print help information for interactive mode.
    --update                    Update KGSM to the latest version.
      [--force]                 Ignore version check and download the latest
                                version available.
    --ip                        Get the external server IP used to connect to
                                the server.
    -v, --version               Print the KGSM version.

  \e[4mBlueprints\e[0m
    --create-blueprint          Create a new blueprints file.
      [-h, --help]              Print help information about the blueprint
                                creation process.
    --blueprints                List all available blueprints.
    --install BLUEPRINT         Run the installation process for an existing
                                blueprint.
                                BLUEPRINT must be the name of a blueprint.
                                Run --blueprints to see available options.
      [--install-dir <dir>]     Needed in case KGSM_DEFAULT_INSTALL_DIR is not
                                set.
      [--version <version>]     CURRENTLY NOT USED
                                Specific version to install.
      [--id <id>]               Identifier for the instance as an alternative
                                from letting KGSM generate one.

  \e[4mInstances\e[0m
    --instances [blueprint]     List all installed instances.
                                Optionally a blueprint name can be specified in
                                order to only list instances of that blueprint

    -i, --instance <x> OPTION   Interact with an instance.
                                OPTION represents one of the following:

      --logs                    Return the last 10 lines of the instance log.
      --status                  Return a detailed running status.
      --info                    Print information about the instance.
      --is-active               Check if the instance is active.
      --start                   Start the instance.
      --stop                    Stop the instance.
      --restart                 Restart the instance.
      -v, --version             Provide version information.
                                Running this with no other argument has the same
                                outcome as adding the --installed argument.
        [--installed]           Print the currently installed version.
        [--latest]              Print the latest available version.
      --check-update            Check if a new version is available.
      --update                  Run the update process.
      --create-backup           Create a backup of the currently installed
                                version, if any.
      --restore-backup NAME     Restore a backup.
                                NAME is the backup name.
      --uninstall               Run the uninstall process.
" "$DESCRIPTION"
}

function usage_interactive() {
  printf "%s

Interactive mode menu options:
  \e[4mInstall\e[0m            Run the installation process for a blueprint.

  \e[4mList blueprints\e[0m    Display a list of all blueprints.

  \e[4mList instances\e[0m     Display a list of all created instances with a detailed
                     description.

  \e[4mStart\e[0m              Start up an instance.

  \e[4mStop\e[0m               Stop a running instance.

  \e[4mRestart\e[0m            Restart an instance.

  \e[4mStatus\e[0m             Print a detailed information about an instance.

  \e[4mCheck for update\e[0m   Check if a new version of a instance is available.
                     It will print out the new version if found, otherwise
                     it will fail with exit code 1.

  \e[4mUpdate\e[0m             Runs a check for a new instance version, creates a
                     backup of the current installation if any, downloads the new
                     version and deploys it.

  \e[4mLogs\e[0m               Print out the last 10 lines of the latest instance
                     log file.

  \e[4mCreate backup\e[0m      Creates a backup of an instance.

  \e[4mRestore backup\e[0m     Restores a backup of an instance
                     It will prompt to select a backup to restore and
                     also if the current installation directory of the
                     instance is not empty.

  \e[4mUninstall\e[0m          Runs the uninstall process for an instance.
                     Warning: This will remove everything other than the
                     blueprint file the instance is based on.

  \e[4mHelp\e[0m               Prints this message
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
    echo "${0##*/} ERROR: wget is required but not installed" >&2 && return 1
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
    LATEST_VERSION=$(wget -qO - "$version_url")
  else
    echo "${0##*/} ERROR: wget is required to check for updates." >&2 && return 1
  fi

  # Compare the versions
  if [ "$script_version" != "$LATEST_VERSION" ] || [ "$force" -eq 1 ]; then
    echo "${0##*/} New version available: $LATEST_VERSION. Updating..." >&2

    # Backup the current script
    local backup_file="${0}.${script_version:-0}.bak"
    cp "$0" "$backup_file"
    echo "${0##*/} Backup of the current script created at $backup_file" >&2

    # Download the repository tarball
    if command -v wget >/dev/null 2>&1; then
      wget -O "kgsm.tar.gz" "$repo_archive_url" 2>/dev/null
    else
      echo "${0##*/} ERROR: wget is required to download the update." >&2
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
      echo "${0##*/} ERROR: Failed to extract the update. Reverting to the previous version." >&2
      mv "${0}.${script_version:-0}.bak" "$0"
    fi
  else
    echo "${0##*/} You are already using the latest version: $script_version." >&2
  fi

  return 0
}

[[ "$KGSM_RUN_UPDATE_CHECK" -eq 1 ]] && check_for_update

while [[ "$#" -gt 0 ]]; do
  case $1 in
  -h | --help)
    shift
    [[ -z "$1" ]] && usage && exit 0
    case "$1" in
      --interactive)
      usage_interactive && exit 0
      ;;
      *) echo "${0##*/} ERROR: Unknown argument $1" >&2 && exit 1
    esac
    ;;
  --update)
    update_script "$@" && exit $?
    ;;
  *)
    break
    ;;
  esac
  shift
done

# Trap CTRL-C
trap "echo "" && exit" INT

MODULE_COMMON="$(find "$KGSM_ROOT" -type f -name common.sh)"
[[ -z "$MODULE_COMMON" ]] && echo "${0##*/} ERROR: Failed to load module common.sh" >&2 && exit 1

# shellcheck disable=SC1090
source "$MODULE_COMMON" || exit 1

MODULE_BLUEPRINTS="$(find "$MODULES_SOURCE_DIR" -type f -name blueprints.sh)"
[[ -z "$MODULE_BLUEPRINTS" ]] && echo "${0##*/} ERROR: Failed to load module blueprints.sh" >&2 && exit 1

MODULE_DIRECTORIES="$(find "$MODULES_SOURCE_DIR" -type f -name directories.sh)"
[[ -z "$MODULE_DIRECTORIES" ]] && echo "${0##*/} ERROR: Failed to load module directories.sh" >&2 && exit 1

MODULE_FILES="$(find "$MODULES_SOURCE_DIR" -type f -name files.sh)"
[[ -z "$MODULE_FILES" ]] && echo "${0##*/} ERROR: Failed to load module files.sh" >&2 && exit 1

MODULE_VERSION="$(find "$MODULES_SOURCE_DIR" -type f -name version.sh)"
[[ -z "$MODULE_VERSION" ]] && echo "${0##*/} ERROR: Failed to load module version.sh" >&2 && exit 1

MODULE_DOWNLOAD="$(find "$MODULES_SOURCE_DIR" -type f -name download.sh)"
[[ -z "$MODULE_DOWNLOAD" ]] && echo "${0##*/} ERROR: Failed to load module download.sh" >&2 && exit 1

MODULE_DEPLOY="$(find "$MODULES_SOURCE_DIR" -type f -name deploy.sh)"
[[ -z "$MODULE_DEPLOY" ]] && echo "${0##*/} ERROR: Failed to load module deploy.sh" >&2 && exit 1

MODULE_UPDATE="$(find "$MODULES_SOURCE_DIR" -type f -name update.sh)"
[[ -z "$MODULE_UPDATE" ]] && echo "${0##*/} ERROR: Failed to load module update.sh" >&2 && exit 1

MODULE_BACKUP="$(find "$MODULES_SOURCE_DIR" -type f -name backup.sh)"
[[ -z "$MODULE_BACKUP" ]] && echo "${0##*/} ERROR: Failed to load module backup.sh" >&2 && exit 1

MODULE_INSTANCE="$(find "$MODULES_SOURCE_DIR" -type f -name instances.sh)"
[[ -z "$MODULE_INSTANCE" ]] && echo "${0##*/} ERROR: Failed to load module instances.sh" >&2 && exit 1

function _install() {
  local blueprint=$1
  local install_dir=$2
  local version=$3
  local identifier=${4:-}

  if [[ "$blueprint" != *.bp ]]; then
    blueprint="${blueprint}.bp"
  fi

  local instance

  # The user can pass an instance identifier instead of having KGSM generate
  # one, for ease of use or easy identification. However it's not mandatory,
  # if the user doen't pass one, the $MODULE_INSTANCE will generate one
  # and use it without any issues.
  if [[ -z "$identifier" ]]; then
    instance="$("$MODULE_INSTANCE" --create "$blueprint" --install-dir "$install_dir")"
  else
    instance="$("$MODULE_INSTANCE" --create "$blueprint" --install-dir "$install_dir" --id "$identifier")"
  fi

  "$MODULE_DIRECTORIES" -i "$instance" --create $debug || return $?
  "$MODULE_FILES" -i "$instance" --create $debug || return $?

  if [[ -z "$version" ]] || [[ "$version" -eq 0 ]]; then
    version=$("$MODULE_VERSION" -i "$instance" --latest)
  fi

  "$MODULE_DOWNLOAD" -i "$instance" -v "$version" $debug || return $?
  "$MODULE_DEPLOY" -i "$instance" $debug || return $?
  "$MODULE_VERSION" -i "$instance" --save "$version" $debug || return $?

  echo "Instance $instance has been created in $install_dir" >&2 && return 0
}

function _uninstall() {
  local instance=$1

  if [[ "$instance" != *.ini ]]; then
    instance="${instance}.ini"
  fi

  "$MODULE_DIRECTORIES" -i "$instance" --remove $debug || return $?
  "$MODULE_FILES" -i "$instance" --remove $debug || return $?
  "$MODULE_INSTANCE" --remove "$instance" $debug || return $?
}

function _interactive() {
  echo "$DESCRIPTION

KGSM also accepts named arguments for automation, to see all options run:
${0##*/} --help

Press CTRL+C to exit at any time.

KGSM - Interactive menu
"

  PS3="Choose an action: "

  local action=
  local blueprint_or_instance=

  declare -a menu_options=(
    "Install"
    "List blueprints"
    "List instances"
    "Start"
    "Stop"
    "Restart"
    "Status"
    "Check for update"
    "Update"
    "Logs"
    "Create backup"
    "Restore backup"
    "Uninstall"
    "Help"
  )

  declare -A arg_map=(
    ["Install"]=--install
    ["List blueprints"]=--blueprints
    ["List instances"]=--instances
    ["Start"]=--start
    ["Stop"]=--stop
    ["Restart"]=--restart
    ["Status"]=--status
    ["Check for update"]=--check-update
    ["Update"]=--update
    ["Logs"]=--logs
    ["Create backup"]=--create-backup
    ["Restore backup"]=--restore-backup
    ["Uninstall"]=--uninstall
    ["Help"]=--help
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

  # Depending on the action, load up a list of all blueprints or all instances
  declare -a blueprints_or_instances=()

  PS3="Choose an instance: "

  case "$action" in
  --install)
    # shellcheck disable=SC2178
    # shellcheck disable=SC2207
    blueprints_or_instances=($("$MODULE_BLUEPRINTS" --list | tr '\n' ' '))
    PS3="Choose a blueprint: "
    ;;
  --blueprints)
    exec $0 --blueprints
    ;;
  --instances)
    exec $0 --instances
    ;;
  --help)
    exec $0 --help --interactive
    ;;
  --status)
    # shellcheck disable=SC2207
    # shellcheck disable=SC2178
    blueprints_or_instances=($("$MODULE_INSTANCE" --list))
    ;;
  *)
    # shellcheck disable=SC2207
    # shellcheck disable=SC2178
    blueprints_or_instances=($("$MODULE_INSTANCE" --list))
    "$MODULE_INSTANCE" --list --detailed
    ;;
  esac

  [[ "${#blueprints_or_instances[@]}" -eq 0 ]] && echo "${0##*/} INFO: No instances found" >&2 && return 0

  # Select blueprint/instance for the action
  select bp in "${blueprints_or_instances[@]}"; do
    if [[ -z $bp ]]; then
      echo "Didn't understand \"$REPLY\" " >&2
      REPLY=
    else
      blueprint_or_instance="$bp"
      break
    fi
  done

  # Recursivelly call the script with the given params.
  # --install has a different arg order
  case "$action" in
  --install)
    install_directory=${INSTANCE_DEFAULT_INSTALL_DIR:-}
    if [ -z "$install_directory" ]; then
      echo "INSTANCE_DEFAULT_INSTALL_DIR is not set in the configuration file, please specify an installation directory" >&2
      read -r -p "Installation directory: " install_directory && [[ -n $install_directory ]] || exit 1
    fi

    read -r -p "Version to install (leave empty for latest): " version
    read -r -p "Instance identifier (leave empty for default): " identifier

    echo "Creating an instance of $blueprint_or_instance..." >&2
    # shellcheck disable=SC2086
    "$0" \
      $action $blueprint_or_instance \
      --install-dir $install_directory \
      ${version:+--version "$version"} \
      ${identifier:+--id "$identifier"} \
      $debug
    ;;
  --restore-backup)
    # shellcheck disable=SC2207
    backups_array=($("$MODULE_BACKUP" -i "$blueprint_or_instance" --list))
    [[ "${#backups_array[@]}" -eq 0 ]] && echo "No backups found. Exiting." >&2 && return 1

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
    "$0" --instance $instance $action $backup_to_restore $debug
    ;;
  *)
    # shellcheck disable=SC2086
    $0 --instance $blueprint_or_instance $action $debug
    ;;
  esac
}

# If it's started with no args, default to interactive mode
[[ "$#" -eq 0 ]] && _interactive && exit $?

while [[ "$#" -gt 0 ]]; do
  case $1 in
  --create-blueprint)
    shift
    [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing arguments" >&2 && exit 1
    case "$1" in
    -h | --help) "$MODULE_BLUEPRINTS" --help $debug && exit $? ;;
    *)
      # shellcheck disable=SC2068
      "$MODULE_BLUEPRINTS" --create $@ $debug && exit $?
      ;;
    esac
    ;;
  --install)
    shift
    [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument <blueprint>" >&2 && exit 1
    bp_to_install="$1"
    bp_install_dir=$INSTANCE_DEFAULT_INSTALL_DIR
    bp_install_version=0
    bp_id=
    shift
    if [ -n "$1" ]; then
      while [[ $# -ne 0 ]]; do
        case "$1" in
        --install-dir)
          shift
          [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument <install_dir>" >&2 && exit 1
          bp_install_dir="$1"
          ;;
        --version)
          shift
          [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument <version>" >&2 && exit 1
          bp_install_version=$1
          ;;
        --id)
          shift
          [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument <id>" >&2 && exit 1
          bp_id=$1
          ;;
        *)
          echo "${0##*/} ERROR: Unknown argument $1" >&2 && exit 1
          ;;
        esac
        shift
      done
    fi
    [[ -z "$bp_install_dir" ]] && echo "${0##*/} ERROR: Missing argument <dir>" >&2 && exit 1
    _install "$bp_to_install" "$bp_install_dir" $bp_install_version $bp_id && exit $?
    ;;
  --blueprints)
    "$MODULE_BLUEPRINTS" --list && exit $?
    ;;
  --ip)
    if command -v wget >/dev/null 2>&1; then
      wget -qO- https://icanhazip.com && exit $?
    else
      echo "${0##*/} ERROR: wget is required but not installed" >&2
      exit 1
    fi
    ;;
  --update)
    update_script "$@" && exit $?
    ;;
  --instances)
    "$MODULE_INSTANCE" --list --detailed && exit $?
    ;;
  -i | --instance)
    shift
    [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument <instance>" >&2 && exit 1
    instance=$1
    shift
    [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument [OPTION]" >&2 && exit 1
    case "$1" in
    --logs)
      "$MODULE_INSTANCE" --logs "$instance" && exit $?
      ;;
    --status)
      "$MODULE_INSTANCE" --status "$instance" && exit $?
      ;;
    --info)
      "$MODULE_INSTANCE" --info "$instance" && exit $?
      ;;
    --is-active)
      "$MODULE_INSTANCE" --is-active "$instance" && exit $?
      ;;
    --start)
      "$MODULE_INSTANCE" --start "$instance" && exit $?
      ;;
    --stop)
      "$MODULE_INSTANCE" --stop "$instance" && exit $?
      ;;
    --restart)
      "$MODULE_INSTANCE" --restart "$instance" && exit $?
      ;;
    -v | --version)
      shift
      [[ -z "$1" ]] && "$MODULE_VERSION" -i "$instance" --installed $debug && exit $?
      case "$1" in
      --installed) "$MODULE_VERSION" -i "$instance" --installed $debug && exit $? ;;
      --latest) "$MODULE_VERSION" -i "$instance" --latest $debug && exit $? ;;
      *) echo "${0##*/} ERROR: Invalid argument $1" >&2 && usage && exit 1 ;;
      esac
      ;;
    --check-update)
      case "$1" in
      -h | --help) "$MODULE_VERSION" --help && exit $? ;;
      *) "$MODULE_VERSION" -i "$instance" --compare $debug && exit $? ;;
      esac
      ;;
    --update)
      case "$1" in
      -h | --help) "$MODULE_UPDATE" --help && exit $? ;;
      *) "$MODULE_UPDATE" -i "$instance" $debug && exit $? ;;
      esac
      ;;
    --create-backup)
      case "$1" in
      -h | --help) "$MODULE_BACKUP" --help && exit $? ;;
      *) "$MODULE_BACKUP" -i "$instance" --create $debug && exit $? ;;
      esac
      ;;
    --restore-backup)
      [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument <backup>" >&2 && exit 1
      shift
      case "$1" in
      -h | --help) "$MODULE_BACKUP" --help && exit $? ;;
      *) "$MODULE_BACKUP" -i "$instance" --restore "$1" $debug && exit $? ;;
      esac
      ;;
    --uninstall)
      _uninstall "$instance" && exit $?
      ;;
    *) echo "${0##*/} ERROR: Invalid argument $1" >&2 && exit 1 ;;
    esac
    ;;
  -v | --version)
    echo "KGSM, version $(get_version)
Copyright (C) 2024 TheKrystalShip
License GPL-3.0: GNU GPL version 3 <https://www.gnu.org/licenses/gpl-3.0.en.html>

This is free software; you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law." && exit 0
    ;;
  *)
    echo "${0##*/} ERROR: Invalid argument $1" >&2 && exit 1
    ;;
  esac
  shift
done

exit 0
