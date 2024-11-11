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
SELF_PATH="$(dirname "$(readlink -f "$0")")"

# Read configuration file
CONFIG_FILE="$(find "$SELF_PATH" -type f -name config.ini -print -quit)"
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
  CONFIG_FILE_EXAMPLE="$(find "$SELF_PATH" -type f -name config.default.ini -print -quit)"
  if [ -f "$CONFIG_FILE_EXAMPLE" ]; then
    cp "$CONFIG_FILE_EXAMPLE" "$SELF_PATH/config.ini"
    echo "${0##*/} WARNING: config.ini not found, created new file" >&2
    echo "${0##*/} INFO: Please ensure configuration is correct before running the script again" >&2
    exit 0
  else
    echo "${0##*/} ERROR: Could not find config.default.ini, install might be broken" >&2
    exit 1
  fi
fi

set -eo pipefail

# Trap CTRL-C
trap "echo "" && exit" INT

module_common=$(find "$KGSM_ROOT" -type f -name common.sh -print -quit)
[[ -z "$module_common" ]] && echo "${0##*/} ERROR: Could not find module common.sh" >&2 && exit 1

# shellcheck disable=SC1090
source "$module_common" || exit 1

function get_version() {
  [[ -f "$KGSM_ROOT/version.txt" ]] && cat "$KGSM_ROOT/version.txt"
}

DESCRIPTION="Krystal Game Server Manager - $(get_version)

Create, install, and manage game servers on Linux.

If you have any problems while using KGSM, please don't hesitate to create an
issue on GitHub: https://github.com/TheKrystalShip/KGSM/issues"

function usage() {
  local UNDERLINE="\e[4m"
  local END="\e[0m"
  echo -e "$DESCRIPTION"

  echo -e "
Usage:
  $(basename "$0") OPTION

Options:
  ${UNDERLINE}General${END}
  -h, --help                  Print this help message.
    [--interactive]           Print help information for interactive mode.
  --update                    Update KGSM to the latest version.
    [--force]                 Ignore version check and download the latest
                              version available.
  --ip                        Print the external server IP address.
  -v, --version               Print the KGSM version.

${UNDERLINE}Blueprints${END}
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
    [--version <version>]     WARNING: Not used by game servers that come from
                              steamcmd, only used by custom game servers.
                              Specific version to install.
    [--id <id>]               Identifier for the instance as an alternative
                              from letting KGSM generate one.

${UNDERLINE}Instances${END}
  --uninstall <instance>      Run the uninstall process for an instance.
  --instances [blueprint]     List all installed instances.
                              Optionally a blueprint name can be specified in
                              order to only list instances of that blueprint

  -i, --instance <x> OPTION   Interact with an instance.
                              OPTION represents one of the following:

    --logs                    Print a constant output of an instance's log.
    --status                  Return a detailed running status.
    --info                    Print information about the instance.
    --is-active               Check if the instance is active.
    --start                   Start the instance.
    --stop                    Stop the instance.
    --restart                 Restart the instance.
    --save                    Issues the save command to the instance.
    --input <command>         Send a command to the instance's interactive
                              console, if the instance accepts commands.
                              Will display the last 10 lines of the instance
                              log.
    -v, --version             Provide version information.
                              Running this with no other argument has the same
                              outcome as adding the --installed argument.
      [--installed]           Print the currently installed version.
      [--latest]              Print the latest available version.
    --backups                 Print a list of created backups.
    --check-update            Check if a new version is available.
    --update                  Run the update process.
    --create-backup           Create a backup of the currently installed
                              version, if any.
    --restore-backup NAME     Restore a backup.
                              NAME is the backup name.
    --modify                  Modify and existing instance.
      --add OPTION            Add additional functionality. Possible options:
                                ufw, systemd
      --remove OPTION         Remove functionality. Possible options:
                                ufw, systemd
"
}

function usage_interactive() {
  local UNDERLINE="\e[4m"
  local END="\e[0m"

  echo -e "$DESCRIPTION"

  echo -e "Interactive mode menu options:
  ${UNDERLINE}Install${END}            Run the installation process for a blueprint.

  ${UNDERLINE}List blueprints${END}    Display a list of all blueprints.

  ${UNDERLINE}List instances${END}     Display a list of all created instances with a detailed
                     description.

  ${UNDERLINE}Start${END}              Start up an instance.

  ${UNDERLINE}Stop${END}               Stop a running instance.

  ${UNDERLINE}Restart${END}            Restart an instance.

  ${UNDERLINE}Status${END}             Print a detailed information about an instance.

  ${UNDERLINE}Modify${END}             Modify and existing instance to add or remove
                     features.
                     Currently 'ufw' and 'systemd' integrations can
                     be added/removed.

  ${UNDERLINE}Check for update${END}   Check if a new version of a instance is available.
                     It will print out the new version if found, otherwise
                     it will fail with exit code 1.

  ${UNDERLINE}Update${END}             Runs a check for a new instance version, creates a
                     backup of the current installation if any, downloads the new
                     version and deploys it.

  ${UNDERLINE}Logs${END}               Print out the last 10 lines of the latest instance
                     log file.

  ${UNDERLINE}Create backup${END}      Creates a backup of an instance.

  ${UNDERLINE}Restore backup${END}     Restores a backup of an instance
                     It will prompt to select a backup to restore and
                     also if the current installation directory of the
                     instance is not empty.

  ${UNDERLINE}Uninstall${END}          Runs the uninstall process for an instance.
                     Warning: This will remove everything other than the
                     blueprint file the instance is based on.

  ${UNDERLINE}Help${END}               Prints this message
"
}

function check_for_update() {
  # shellcheck disable=SC2155
  local script_version=$(get_version)
  local version_url="https://raw.githubusercontent.com/TheKrystalShip/KGSM/main/version.txt"

  # Fetch the latest version number
  if command -v wget >/dev/null 2>&1; then
    LATEST_VERSION=$(wget -q -O - "$version_url")
  else
    __print_error "wget is required but not installed" && return 1
  fi

  # Compare the versions
  if [ "$script_version" != "$LATEST_VERSION" ]; then
    __print_info "New version available: $LATEST_VERSION"
    __print_info "Please run './${0##*/} --update' to get the latest version"
  fi
}

# Define a function to update the script and other files
function update_script() {
  # Define the raw URL of the script and version file
  local script_version
  script_version=$(get_version)
  local version_url="https://raw.githubusercontent.com/TheKrystalShip/KGSM/main/version.txt"
  local repo_archive_url="https://github.com/TheKrystalShip/KGSM/archive/refs/heads/main.tar.gz"
  local repo_compare_url="https://api.github.com/repos/TheKrystalShip/KGSM/compare"
  local local_temp_file="kgsm.tar.gz"
  local local_temp_dir="KGSM-main"

  local force=0
  for arg in "$@"; do
    shift
    [ "$arg" = "--force" ] && force=1
  done

  __print_info "Checking for updates..."

  # Fetch the latest version number
  if command -v wget >/dev/null 2>&1; then
    LATEST_VERSION=$(wget -qO - "$version_url")
  else
    __print_error "wget is required to check for updates." && return 1
  fi

  # Compare the versions
  if [ "$script_version" != "$LATEST_VERSION" ] || [ "$force" -eq 1 ]; then
    __print_info "New version available: $LATEST_VERSION. Updating..."

    # Backup the current script
    local backup_file="${0}.${script_version:-0}.bak"
    cp "$0" "$backup_file"
    __print_info "Backup of the current script created at $backup_file"

    # Download the repository tarball
    if ! wget -qO "$local_temp_file" "$repo_archive_url" 2>/dev/null; then
      __print_error "Failed to download new version from $repo_archive_url" && return 1
    fi

    # Extract the tarball
    if ! tar -xzf "$local_temp_file"; then
      __print_error "Failed to extract the update. Reverting to the previous version."
      mv "${0}.${script_version:-0}.bak" "$0"
    fi

    # Overwrite the existing files with the new ones
    cp -r "$local_temp_dir"/* .
    chmod +x kgsm.sh modules/*.sh

    # Print changelog
    local commits_url="${repo_compare_url}/${script_version}...${LATEST_VERSION}"
    local bold="\033[1m"
    local bold_end="\033[0m"
    __print_info "Changes between ${bold}${script_version}${bold_end} and ${bold}$LATEST_VERSION${bold_end}:"
    wget -qO- "$commits_url" | jq -r \
      '.commits[]
      | select(.commit.message | test("^Bumped version to [0-9]+\\.[0-9]+\\.[0-9]+") | not)
      | "\(.sha[0:7]): \(.commit.message)"'

    # Cleanup
    rm -rf "$local_temp_dir" "$local_temp_file"

    __print_success "KGSM updated to version ${bold}$LATEST_VERSION${bold_end}"
  else
    __print_info "You are already using the latest version: $script_version."
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
    *)
      __print_error "Unknown argument $1" && exit 1
      ;;
    esac
    ;;
  --update)
    update_script "$@"; exit $?
    ;;
  *)
    break
    ;;
  esac
  shift
done

module_blueprints=$(__load_module blueprints.sh)
module_directories=$(__load_module directories.sh)
module_files=$(__load_module files.sh)
module_version=$(__load_module version.sh)
module_download=$(__load_module download.sh)
module_deploy=$(__load_module deploy.sh)
module_update=$(__load_module update.sh)
module_backup=$(__load_module backup.sh)
module_instance=$(__load_module instances.sh)

function _install() {
  local blueprint=$1
  local install_dir=$2
  # Value of 0 means get latest
  local version=$3
  local identifier=${4:-}

  if [[ "$blueprint" != *.bp ]]; then
    blueprint="${blueprint}.bp"
  fi

  local instance

  # The user can pass an instance identifier instead of having KGSM generate
  # one, for ease of use or easy identification. However it's not mandatory,
  # if the user doen't pass one, the $module_instance will generate one
  # and use it without any issues.
  if [[ -z "$identifier" ]]; then
    instance="$("$module_instance" --create "$blueprint" --install-dir "$install_dir")"
  else
    instance="$("$module_instance" --create "$blueprint" --install-dir "$install_dir" --id "$identifier")"
  fi

  "$module_directories" -i "$instance" --create $debug || return $?
  "$module_files" -i "$instance" --create $debug || return $?

  if [[ "$version" == 0 ]]; then
    version=$("$module_version" -i "$instance" --latest)
  fi

  "$module_download" -i "$instance" -v "$version" $debug || return $?
  "$module_deploy" -i "$instance" $debug || return $?
  "$module_version" -i "$instance" --save "$version" $debug || return $?

  __print_success "Instance $instance has been created in $install_dir"

  return 0
}

function _uninstall() {
  local instance=$1

  if [[ "$instance" != *.ini ]]; then
    instance="${instance}.ini"
  fi

  "$module_directories" -i "$instance" --remove $debug || return $?
  "$module_files" -i "$instance" --remove $debug || return $?
  "$module_instance" --remove "$instance" $debug || return $?

  __print_success "Instance ${instance%.ini} uninstalled"

  return 0
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
    "Modify"
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
    ["Modify"]=--modify
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
    blueprints_or_instances=($("$module_blueprints" --list | tr '\n' ' '))
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
    blueprints_or_instances=($("$module_instance" --list))
    ;;
  *)
    # shellcheck disable=SC2207
    # shellcheck disable=SC2178
    blueprints_or_instances=($("$module_instance" --list))
    "$module_instance" --list --detailed
    ;;
  esac

  [[ "${#blueprints_or_instances[@]}" -eq 0 ]] && __print_warning "No instances found" && return 0

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
  --uninstall)
    "$0" --uninstall "$blueprint_or_instance"
    ;;
  --restore-backup)
    # shellcheck disable=SC2207
    backups_array=($("$module_backup" -i "$blueprint_or_instance" --list))
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
    "$0" --instance $blueprint_or_instance $action $backup_to_restore $debug
    ;;
  --modify)
    declare -a modify_options=()
    declare -A modify_arg_map=(
      ["Add systemd"]="--add systemd"
      ["Remove systemd"]="--remove systemd"
      ["Add ufw"]="--add ufw"
      ["Remove ufw"]="--remove ufw"
    )
    local mod_action

    local instance_config_file
    instance_config_file=$(__load_instance "$blueprint_or_instance")

    if grep -q "INSTANCE_SYSTEMD_SERVICE_FILE=" <"$instance_config_file"; then
      modify_options+=("Remove systemd")
    else
      modify_options+=("Add systemd")
    fi

    if grep -q "INSTANCE_UFW_FILE=" <"$instance_config_file"; then
      modify_options+=("Remove ufw")
    else
      modify_options+=("Add ufw")
    fi

    select mod_arg in "${modify_options[@]}"; do
      if [[ -z "$mod_arg" ]]; then
        echo "Didn't understand \"$REPLY\"" >&2
        REPLY=
      else
        mod_action="${modify_arg_map[$mod_arg]}"
        break
      fi
    done

    # shellcheck disable=SC2086
    "$0" --instance "$blueprint_or_instance" --modify $mod_action
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
    [[ -z "$1" ]] && __print_error "Missing arguments" && exit 1
    case "$1" in
    -h | --help) "$module_blueprints" --help $debug; exit $? ;;
    *)
      # shellcheck disable=SC2068
      "$module_blueprints" --create $@ $debug; exit $?
      ;;
    esac
    ;;
  --install)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <blueprint>" && exit 1
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
          [[ -z "$1" ]] && __print_error "Missing argument <install_dir>" && exit 1
          bp_install_dir="$1"
          ;;
        --version)
          shift
          [[ -z "$1" ]] && __print_error "Missing argument <version>" && exit 1
          bp_install_version=$1
          ;;
        --id)
          shift
          [[ -z "$1" ]] && __print_error "Missing argument <id>" && exit 1
          bp_id=$1
          ;;
        *)
          __print_error "Unknown argument $1" && exit 1
          ;;
        esac
        shift
      done
    fi
    [[ -z "$bp_install_dir" ]] && __print_error "Missing argument <dir>" && exit 1
    _install "$bp_to_install" "$bp_install_dir" $bp_install_version $bp_id; exit $?
    ;;
  --uninstall)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <instance>" && exit 1
    _uninstall "$1"; exit $?
    ;;
  --blueprints)
    "$module_blueprints" --list $debug; exit $?
    ;;
  --ip)
    if command -v wget >/dev/null 2>&1; then
      wget -qO- https://icanhazip.com; exit $?
    else
      __print_error "wget is required but not installed" && exit 1
    fi
    ;;
  --update)
    update_script "$@"; exit $?
    ;;
  --instances)
    shift
    if [[ -z "$1" ]]; then
      "$module_instance" --list $debug
      exit $?
    else
      case "$1" in
        --detailed)
          "$module_instance" --list --detailed $debug; exit $?
          ;;
        *)
          __print_error "Invalid argument $1" && exit 1
          ;;
      esac
    fi
    ;;
  -i | --instance)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <instance>" && exit 1
    instance=$1
    shift
    [[ -z "$1" ]] && __print_error "Missing argument [OPTION]" && exit 1
    case "$1" in
    --logs)
      "$module_instance" --logs "$instance" $debug; exit $?
      ;;
    --status)
      "$module_instance" --status "$instance" $debug; exit $?
      ;;
    --info)
      "$module_instance" --info "$instance" $debug; exit $?
      ;;
    --is-active)
      "$module_instance" --is-active "$instance" $debug; exit $?
      ;;
    --start)
      "$module_instance" --start "$instance" $debug; exit $?
      ;;
    --stop)
      "$module_instance" --stop "$instance" $debug; exit $?
      ;;
    --restart)
      "$module_instance" --restart "$instance" $debug; exit $?
      ;;
    --save)
      "$module_instance" --save "$instance" $debug; exit $?
      ;;
    --input)
      shift
      [[ -z "$1" ]] && __print_error "Missing argument <command>" && exit 1
      "$module_instance" --input "$instance" "$1" $debug; exit $?
      ;;
    -v | --version)
      shift
      if [[ -z "$1" ]]; then "$module_version" -i "$instance" --installed $debug; exit $?; fi
      case "$1" in
      --installed) "$module_version" -i "$instance" --installed $debug; exit $? ;;
      --latest) "$module_version" -i "$instance" --latest $debug; exit $? ;;
      *) __print_error "Invalid argument $1" && exit 1 ;;
      esac
      ;;
    --check-update)
      case "$1" in
      -h | --help) "$module_version" --help; exit $? ;;
      *) "$module_version" -i "$instance" --compare $debug; exit $? ;;
      esac
      ;;
    --update)
      case "$1" in
      -h | --help) "$module_update" --help; exit $? ;;
      *) "$module_update" -i "$instance" $debug; exit $? ;;
      esac
      ;;
    --backups)
      "$module_backup" -i "$instance" --list $debug; exit $? ;;
    --create-backup)
      case "$1" in
      -h | --help) "$module_backup" --help; exit $? ;;
      *) "$module_backup" -i "$instance" --create $debug; exit $? ;;
      esac
      ;;
    --restore-backup)
      [[ -z "$1" ]] && __print_error "Missing argument <backup>" && exit 1
      shift
      case "$1" in
      -h | --help) "$module_backup" --help; exit $? ;;
      *) "$module_backup" -i "$instance" --restore "$1" $debug; exit $? ;;
      esac
      ;;
    --modify)
      shift
      [[ -z "$1" ]] && __print_error "Missing argument <option>" && exit 1
      case "$1" in
      --add)
        shift
        [[ -z "$1" ]] && __print_error "Missing argument <option>" && exit 1
        case "$1" in
        ufw) "$module_files" -i "$instance" --create --ufw $debug; exit $? ;;
        systemd) "$module_files" -i "$instance" --create --systemd $debug; exit $? ;;
        *) __print_error "Invalid argument $1"; exit 1 ;;
        esac
        ;;
      --remove)
        shift
        [[ -z "$1" ]] && __print_error "Missing argument <option>" && exit 1
        case "$1" in
        ufw) "$module_files" -i "$instance" --remove --ufw $debug; exit $? ;;
        systemd) "$module_files" -i "$instance" --remove --systemd $debug; exit $? ;;
        *) __print_error "Invalid argument $1" && exit 1 ;;
        esac
        ;;
      *) __print_error "Invalid argument $1" && exit 1 ;;
      esac
      ;;
    *) __print_error "Invalid argument $1" && exit 1 ;;
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
    __print_error "Invalid argument $1" && exit 1
    ;;
  esac
  shift
done

exit 0
