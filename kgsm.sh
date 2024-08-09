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
  ./kgsm.sh [option]

Options:
  \e[4mGeneral\e[0m
    -h, --help                  Print this help message.
      --interactive             Print help information for interactive mode.
    --update                    Update KGSM to the latest version.
      --force                   Ignore version check and download the latest
                                version available.
    --ip                        Get the external server IP used to connect to
                                the server.
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
      --install-dir <dir>       Needed in case KGSM_DEFAULT_INSTALL_DIR is not
                                set

  \e[4mInstances\e[0m
    --instances [blueprint]     List all installed instances.
                                Optionally a blueprint name can be specified in
                                order to only list instances of that blueprint

    --instance INSTANCE OPTION  Interact with an instance.
                                OPTION represents one of the following:

      --logs                    Return the last 10 lines of the instance log.
      --status                  Return a detailed running status.
      --is-active               Check if the instance is active.
      --start                   Start the instance.
      --stop                    Stop the instance.
      --restart                 Restart the instance.
      -v, --version             Provide version information.
                                Running this with no other argument has the same
                                outcome as adding the --installed argument.
        --installed             Print the currently installed version.
        --latest                Print the latest available version.
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

# Only call subscripts with sudo if the current user isn't root
SUDO=$([[ "$EUID" -eq 0 ]] && echo "" || echo "sudo -E")

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

COMMON_SCRIPT="$(find "$KGSM_ROOT" -type f -name common.sh)"
[[ -z "$COMMON_SCRIPT" ]] && echo "${0##*/} ERROR: Failed to load module common.sh" >&2 && exit 1

# shellcheck disable=SC1090
source "$COMMON_SCRIPT" || exit 1

BLUEPRINTS_SCRIPT="$(find "$MODULES_SOURCE_DIR" -type f -name blueprints.sh)"
[[ -z "$BLUEPRINTS_SCRIPT" ]] && echo "${0##*/} ERROR: Failed to load module blueprints.sh" >&2 && exit 1

DIRECTORIES_SCRIPT="$(find "$MODULES_SOURCE_DIR" -type f -name directories.sh)"
[[ -z "$DIRECTORIES_SCRIPT" ]] && echo "${0##*/} ERROR: Failed to load module directories.sh" >&2 && exit 1

FILES_SCRIPT="$(find "$MODULES_SOURCE_DIR" -type f -name files.sh)"
[[ -z "$FILES_SCRIPT" ]] && echo "${0##*/} ERROR: Failed to load module files.sh" >&2 && exit 1

VERSION_SCRIPT="$(find "$MODULES_SOURCE_DIR" -type f -name version.sh)"
[[ -z "$VERSION_SCRIPT" ]] && echo "${0##*/} ERROR: Failed to load module version.sh" >&2 && exit 1

DOWNLOAD_SCRIPT="$(find "$MODULES_SOURCE_DIR" -type f -name download.sh)"
[[ -z "$DOWNLOAD_SCRIPT" ]] && echo "${0##*/} ERROR: Failed to load module download.sh" >&2 && exit 1

DEPLOY_SCRIPT="$(find "$MODULES_SOURCE_DIR" -type f -name deploy.sh)"
[[ -z "$DEPLOY_SCRIPT" ]] && echo "${0##*/} ERROR: Failed to load module deploy.sh" >&2 && exit 1

UPDATE_SCRIPT="$(find "$MODULES_SOURCE_DIR" -type f -name update.sh)"
[[ -z "$UPDATE_SCRIPT" ]] && echo "${0##*/} ERROR: Failed to load module update.sh" >&2 && exit 1

BACKUP_SCRIPT="$(find "$MODULES_SOURCE_DIR" -type f -name backup.sh)"
[[ -z "$BACKUP_SCRIPT" ]] && echo "${0##*/} ERROR: Failed to load module backup.sh" >&2 && exit 1

INSTANCE_SCRIPT="$(find "$MODULES_SOURCE_DIR" -type f -name instance.sh)"
[[ -z "$INSTANCE_SCRIPT" ]] && echo "${0##*/} ERROR: Failed to load module instance.sh" >&2 && exit 1

function _install() {
  local blueprint=$1
  local install_dir=$2
  local version=${3:-""}

  if [[ "$blueprint" != *.bp ]]; then
    blueprint="${blueprint}.bp"
  fi

  # TODO: Add option for user to specify instance name, for easy identificiation

  # shellcheck disable=SC2155
  local instance_full_name="$("$INSTANCE_SCRIPT" --create "$blueprint" --install-dir "$install_dir")"

  # Create directory structure
  "$DIRECTORIES_SCRIPT" -i "$instance_full_name" --install $debug || return $?

  # Create necessary files
  $SUDO "$FILES_SCRIPT" -i "$instance_full_name" --install $debug || return $?

  if [[ -z "$version" ]]; then
    # Get the latest version that's gonna be downloaded
    version=$("$VERSION_SCRIPT" -i "$instance_full_name" --latest)
  fi

  # Run the download process
  "$DOWNLOAD_SCRIPT" -i "$instance_full_name" -v "$version" $debug || return $?

  # Deploy newly downloaded
  "$DEPLOY_SCRIPT" -i "$instance_full_name" $debug || return $?

  # Save new version
  "$VERSION_SCRIPT" -i "$instance_full_name" --save "$version" $debug || return $?

  echo "Instance $instance_full_name has been created in $install_dir" >&2 && return 0
}

function _uninstall() {
  local instance=$1

  if [[ "$instance" != *.ini ]]; then
    instance="${instance}.ini"
  fi

  # Remove directory structure
  "$DIRECTORIES_SCRIPT" -i "$instance" --uninstall $debug || return $?
  # Remove files
  $SUDO "$FILES_SCRIPT" -i "$instance" --uninstall $debug || return $?
  # Remove instance
  "$INSTANCE_SCRIPT" --uninstall "$instance" $debug || return $?
}

function get_instances() {
  local -n ref_instances_array=$1
  local blueprint=${2:-}

  shopt -s extglob nullglob

  if [[ -z "$blueprint" ]]; then
    ref_instances_array=( "$INSTANCES_SOURCE_DIR"/**/*.ini )
  else
    # shellcheck disable=SC2034
    ref_instances_array=("$INSTANCES_SOURCE_DIR/$blueprint"/*.ini)
  fi

  # Remove trailing directories from path, leave only filename
  for i in "${!ref_instances_array[@]}"; do
    ref_instances_array["$i"]=$(basename "${ref_instances_array[$i]}")
  done
}

function _print_instances() {
  local instances_array=()
  get_instances instances_array

  [[ "${#instances_array[@]}" -eq 0 ]] && echo "${0##*/} INFO: No instances found" >&2 && return 0

  printf "\e[4mAvailable instances\e[0m\n\n"

  for instance in "${instances_array[@]}"; do
    "$INSTANCE_SCRIPT" --print-info "$instance"
    echo ""
  done
}

function _get_instance_logs() {
  local instance=$1

  [[ "$instance" != *.ini ]] && instance="${instance}.ini"
  instance_config_file=$(find "$KGSM_ROOT" -type f -name "$instance")
  [[ -z "$instance_config_file" ]] && echo "${0##*/} ERROR: Could not find $instance" >&2 && return 1

  # shellcheck disable=SC1090
  source "$instance_config_file" || return 1

  if [[ "$INSTANCE_LIFECYCLE_MANAGER" == "systemd" ]]; then
    [[ "$instance" == *.ini ]] && instance=${instance//.ini}
    journalctl -n 10 -u "$instance" --no-pager
    return $?
  fi

  # shellcheck disable=SC2155
  local instance_logs_dir=$(grep "INSTANCE_LOGS_DIR=" <"$instance_config_file" | cut -d "=" -f2 | tr -d '"')
  [[ -z "$instance_logs_dir" ]] && echo "${0##*/} ERROR: Malformed instance config, no INSTANCE_LOGS_DIR found" >&2 && return 1

  # shellcheck disable=SC2012
  # shellcheck disable=SC2155
  local latest_log_file=$(ls "$instance_logs_dir" -t | head -1)
  [[ -z "$latest_log_file" ]] && echo "${0##*/} INFO: No logs found for $instance" >&2 && return 0

  tail "$instance_logs_dir/$latest_log_file"
}

function __manage_instance() {
  local instance=$1
  local action=$2

  [[ "$instance" != *.ini ]] && instance="${instance}.ini"
  instance_config_file=$(find "$KGSM_ROOT" -type f -name "$instance")
  [[ -z "$instance_config_file" ]] && echo "${0##*/} ERROR: Could not find $instance" >&2 && return 1

  # shellcheck disable=SC2155
  local instance_lifecycle_manager=$(grep "INSTANCE_LIFECYCLE_MANAGER=" <"$instance_config_file" | cut -d "=" -f2 | tr -d '"')

  if [[ "$instance_lifecycle_manager" == "systemd" ]]; then
    # systemctl doesn't need the .ini extension
    if [[ "$instance" == *.ini ]]; then
      instance=${instance//.ini}
    fi
    case "$action" in
      # status doesn't require sudo
      status)
        systemctl $action "$instance" --no-pager
        # systemctl status returns exit code 3, but it prints everything we need
        # so just return 0 afterwords to exit the function
        return 0
        ;;
      # everything else does
      *)
        $SUDO systemctl $action "$instance" --no-pager
        return $?
        ;;
    esac
  fi

  [[ "$instance" != *.ini ]] && instance="${instance}.ini"
  instance_config_file=$(find "$KGSM_ROOT" -type f -name "$instance")
  [[ -z "$instance_config_file" ]] && echo "${0##*/} ERROR: Could not find $instance" >&2 && return 1

  # shellcheck disable=SC2155
  local instance_manage_file=$(grep "INSTANCE_MANAGE_FILE=" <"$instance_config_file" | cut -d "=" -f2 | tr -d '"')
  [[ -z "$instance_manage_file" ]] && echo "${0##*/} ERROR: Could not find INSTANCE_MANAGE_FILE for $instance" >&2 && return 1

  case "$action" in
    start)
      "$instance_manage_file" --start --background
    ;;
    stop)
      "$instance_manage_file" --stop
    ;;
    restart)
      "$instance_manage_file" --stop
      "$instance_manage_file" --start --background
    ;;
    status)
      "$INSTANCE_SCRIPT" --print-info "$instance"
    ;;
    is-active)
      # shellcheck disable=SC2155
      local instance_pid_file=$(grep "INSTANCE_PID_FILE=" <"$instance_config_file" | cut -d "=" | tr -d '"')
      [[ -z "$instance_pid_file" ]] && echo "inactive" && return 1
      [[ ! -f "$instance_pid_file" ]] && echo "inactive" && return 1

      if [[ -n $(cat "$instance_pid_file") ]]; then echo "active" && return 0; fi

      echo "inactive" && return 1
    ;;
    *) echo "${0##*/} ERROR: Unknown action $action" >&2 && return 1
  esac
}

function _interactive() {
  echo "$DESCRIPTION

KGSM also accepts named arguments for automation, to see all options run:
$0 --help

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
    blueprints_or_instances=$("$BLUEPRINTS_SCRIPT" --list)
    PS3="Choose a blueprint: "
    ;;
  --check-update)
    get_instances blueprints_or_instances
    _print_instances
    ;;
  --update)
    get_instances blueprints_or_instances
    _print_instances
    ;;
  --create-backup)
    get_instances blueprints_or_instances
    _print_instances
    ;;
  --restore-backup)
    get_instances blueprints_or_instances
    _print_instances
    ;;
  --uninstall)
    get_instances blueprints_or_instances
    _print_instances
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
  --start)
    get_instances blueprints_or_instances
    _print_instances
    ;;
  --stop)
    get_instances blueprints_or_instances
    _print_instances
    ;;
  --restart)
    get_instances blueprints_or_instances
    _print_instances
    ;;
  --logs)
    get_instances blueprints_or_instances
    _print_instances
    ;;
  --status)
    get_instances blueprints_or_instances
    ;;
  *) echo "${0##*/} ERROR: Unknown action $action" >&2 && return 1 ;;
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
    # shellcheck disable=SC2086
    "$0" $action $blueprint_or_instance --install-dir $install_directory $debug
    ;;
  --restore-backup)
    instance=$blueprint_or_instance
    [[ "$instance" != *.ini ]] && instance="${instance}.ini"
    instance_config_file="$(find "$KGSM_ROOT" -type f -name "$instance")"
    [[ -z "$instance_config_file" ]] && echo "${0##*/} ERROR: Could not find $instance" >&2 && return 1

    # shellcheck disable=SC1090
    source "$instance_config_file" || exit 1

    shopt -s extglob nullglob

    # Restore backup requires specifying which one to restore
    backup_to_restore=
    # Create array
    backups_array=("$INSTANCE_BACKUPS_DIR"/*)
    # remove leading $INSTANCE_BACKUPS_DIR:
    backups_array=("${backups_array[@]#"$INSTANCE_BACKUPS_DIR/"}")

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
    -h | --help) "$BLUEPRINTS_SCRIPT" --help $debug && exit $? ;;
    *)
      # shellcheck disable=SC2068
      "$BLUEPRINTS_SCRIPT" --create $@ $debug && exit $?
      ;;
    esac
    ;;
  --install)
    shift
    [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument <blueprint>" >&2 && exit 1
    bp_to_install="$1"
    install_dir=${INSTANCE_DEFAULT_INSTALL_DIR:-}
    shift
    if [ -n "$1" ]; then
      case "$1" in
      --install-dir)
        shift
        [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument <install_dir>" >&2 && exit 1
        install_dir="$1"
        ;;
      *)
        echo "${0##*/} ERROR: Unknown argument $1" >&2 && exit 1
        ;;
      esac
    fi
    [[ -z "$install_dir" ]] && echo "${0##*/} ERROR: Missing argument <dir>" >&2 && exit 1
    _install "$bp_to_install" "$install_dir" && exit $?
    ;;
  --blueprints)
    "$BLUEPRINTS_SCRIPT" --list && exit $?
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
    _print_instances && exit $?
    ;;
  --instance)
    shift
    [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument <instance>" >&2 && exit 1
    instance=$1
    shift
    [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument [OPTION]" >&2 && exit 1
    case "$1" in
    --logs)
      _get_instance_logs "$instance" && exit $?
      ;;
    --status)
      __manage_instance "$instance" "status" && exit $?
      ;;
    --is-active)
      __manage_instance "$instance" "is-active" && exit $?
      ;;
    --start)
      __manage_instance "$instance" "start" && exit $?
      ;;
    --stop)
      __manage_instance "$instance" "stop" && exit $?
      ;;
    --restart)
      __manage_instance "$instance" "restart" && exit $?
      ;;
    -v | --version)
      shift
      [[ -z "$1" ]] && "$VERSION_SCRIPT" -i "$instance" --installed $debug && exit $?
      case "$1" in
      --installed) "$VERSION_SCRIPT" -i "$instance" --installed $debug && exit $? ;;
      --latest) "$VERSION_SCRIPT" -i "$instance" --latest $debug && exit $? ;;
      *) echo "${0##*/} ERROR: Invalid argument $1" >&2 && usage && exit 1 ;;
      esac
      ;;
    --check-update)
      case "$1" in
      -h | --help) "$VERSION_SCRIPT" --help && exit $? ;;
      *) "$VERSION_SCRIPT" -i "$instance" --compare $debug && exit $? ;;
      esac
      ;;
    --update)
      case "$1" in
      -h | --help) "$UPDATE_SCRIPT" --help && exit $? ;;
      *) "$UPDATE_SCRIPT" -i "$instance" $debug && exit $? ;;
      esac
      ;;
    --create-backup)
      case "$1" in
      -h | --help) "$BACKUP_SCRIPT" --help && exit $? ;;
      *) "$BACKUP_SCRIPT" -i "$instance" --create $debug && exit $? ;;
      esac
      ;;
    --restore-backup)
      [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument <backup>" >&2 && exit 1
      shift
      case "$1" in
      -h | --help) "$BACKUP_SCRIPT" --help && exit $? ;;
      *) "$BACKUP_SCRIPT" -i "$instance" --restore "$1" $debug && exit $? ;;
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
