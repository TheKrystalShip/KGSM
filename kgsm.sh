#!/usr/bin/env bash

# Disable shellcheck for double quotes, as it will complain about
# the variables being used in the functions below.
# shellcheck disable=SC2086

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
KGSM_ROOT="$(dirname "$(readlink -f "$0")")"
export KGSM_ROOT

if [[ ! "$KGSM_COMMON_LOADED" ]]; then
  module_common="$(find "$KGSM_ROOT/modules" -type f -name common.sh -print -quit)"
  if [[ -z "$module_common" ]]; then
    echo "${0##*/} ERROR: Could not find module common.sh" >&2
    echo "${0##*/} ERROR: Install compromised, please reinstall KGSM" >&2
    exit 1
  fi

  # shellcheck disable=SC1090
  source "$module_common" || exit 1
fi

# Load essential modules early
module_interactive=$(__find_module interactive.sh)

installer_script="$(__find_or_fail installer.sh)"

if [[ ! -f "$installer_script" ]]; then
  __print_error "installer.sh missing, won't be able to check for updates"
  __print_error "Installation might be compromised, please reinstall KGSM"
  exit "$EC_GENERAL"
fi

function check_for_update() {
  "$installer_script" --check-update $debug
}

function update_script() {
  "$installer_script" --update $debug
  __merge_user_config_with_default
}

function get_version() {
  "$installer_script" --version $debug
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
  -i, --interactive           Start KGSM in interactive mode.
  --update                    Update KGSM to the latest version.
    [--force]                 Ignore version check and download the latest
                              version available.
  --update-config             Update config.ini with the latest options added
                              or modified in config.default.ini
  --ip                        Print the external server IP address.
  --config                    Modify the configuration file.
  -v, --version               Print the KGSM version.
  --check-update              Check for KGSM updates.

${UNDERLINE}Blueprints${END}
  --create-blueprint          Create a new blueprints file.
    [-h, --help]              Print help information about the blueprint
                              creation process.
  --blueprints                List all available blueprints.
  --blueprints --json         Print a JSON array with all blueprints.
  --blueprints --detailed     Print detailed information on all blueprints.
  --blueprints --json --detailed
                              Print a detailed JSON formatted Map with
                              information on all blueprints.
  --create BLUEPRINT          Create a new game server instance from an
                              existing blueprint.
                              BLUEPRINT must be the name of a blueprint.
                              Run --blueprints to see available options.
    [--install-dir <dir>]     Needed in case KGSM_DEFAULT_INSTALL_DIR is not
                              set.
    [--version <version>]     WARNING: Not used by game servers that come from
                              steamcmd, only used by custom game servers.
                              Specific version to install.
    [--name <name>]           Custom name for the instance instead of letting
                              KGSM generate one automatically.

${UNDERLINE}Instances${END}
  --uninstall <instance>      Run the uninstall process for an instance.
  --instances                 List all installed instances.
  --instances <blueprint>     List all instances of a specific blueprint.
  --instances --detailed      List all instances with detailed information.
  --instances --json          Print a JSON formatted array with all instances.
  --instances --json --detailed
                              Print a detailed JSON Map with all instances
                              and their information.

  -i, --instance <x> OPTION   Interact with an instance.
                              OPTION represents one of the following:

    --logs                    Print the last few lines of the instance's log.
      [-f, --follow]          Continuously follow the log output.
    --status                  Return a detailed running status.
    --info                    Print information about the instance.
      [--json]                Print information in JSON format.
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
    --modify                  Modify an existing instance.
      --add OPTION            Add additional functionality. Possible options:
                                ufw, systemd, symlink
      --remove OPTION         Remove functionality. Possible options:
                                ufw, systemd, symlink
"
}

# Check for updates if configuration allows it
if [[ -n "$config_auto_update_check" && "$config_auto_update_check" == "true" ]]; then
  check_for_update
fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
  -h | --help)
    shift
    [[ -z "$1" ]] && usage && exit 0
    case "$1" in
    --interactive)
      "$module_interactive" --description
      exit $?
      ;;
    *)
      __print_error "Invalid argument $1" && exit "$EC_INVALID_ARG"
      ;;
    esac
    ;;
  -i | --interactive)
    "$module_interactive" -i $debug
    exit $?
    ;;
  --check-update)
    check_for_update
    exit $?
    ;;
  --update)
    update_script
    exit $?
    ;;
  *)
    break
    ;;
  esac
  shift
done

module_blueprints=$(__find_module blueprints.sh)
module_directories=$(__find_module directories.sh)
module_files=$(__find_module files.sh)
module_instance=$(__find_module instances.sh)
module_lifecycle=$(__find_module lifecycle.sh)
# module_interactive is already loaded earlier

function _install() {
  local blueprint=$1
  local install_dir=$2
  # Value of 0 means get latest
  local version=$3
  # Optional identifier for the instance, if not provided, KGSM will generate one
  local identifier=${4:-}

  __print_info "Installing $blueprint in $install_dir"

  local instance

  # The user can pass an instance identifier instead of having KGSM generate
  # one, for ease of use or easy identification. However it's not mandatory,
  # if the user doen't pass one, the $module_instance will generate one
  # and use it without any issues.
  instance="$(
    "$module_instance" \
      --create "$blueprint" \
      --install-dir "$install_dir" \
      ${identifier:+--name $identifier} \
      $debug
  )"

  __emit_instance_installation_started "${instance%.ini}" "${blueprint}"

  "$module_directories" -i "$instance" --create $debug || return $?
  "$module_files" -i "$instance" --create $debug || return $?

  # After generating the instance and the files, we need to load the instance
  # config file so we can use the variables defined in it.
  # From this point on, we will use the instance managment file to handle
  # the next installation steps.

  # shellcheck disable=SC1090
  source "$(__find_instance_config "$instance")" || return $EC_FAILED_SOURCE
  if [[ "$version" == 0 ]]; then
    version=$("$instance_management_file" --version --latest)
  fi

  "$instance_management_file" --download "$version" $debug || return $EC_FAILED_DOWNLOAD
  "$instance_management_file" --deploy $debug || return $EC_FAILED_DEPLOY
  "$instance_management_file" --version --save "$version" $debug || return $EC_FAILED_VERSION_SAVE

  __emit_instance_installation_finished "${instance%.ini}" "${blueprint}"

  __print_success "Instance $instance has been created in $install_dir"

  __emit_instance_installed "${instance%.ini}" "${blueprint}"

  return 0
}

function _uninstall() {
  local instance=$1

  if [[ "$instance" != *.ini ]]; then
    instance="${instance}.ini"
  fi

  __emit_instance_uninstall_started "${instance%.ini}"

  "$module_directories" -i "$instance" --remove $debug || return $?
  "$module_files" -i "$instance" --remove $debug || return $?
  "$module_instance" --remove "$instance" $debug || return $?

  __emit_instance_uninstall_finished "${instance%.ini}"

  __print_success "Instance ${instance%.ini} uninstalled"

  __emit_instance_uninstalled "${instance%.ini}"

  return 0
}

# Interactive mode function moved to modules/interactive.sh

# If it's started with no args, default to interactive mode
if [[ "$#" -eq 0 ]]; then
  "$module_interactive" -i $debug
  exit $?
fi

# shellcheck disable=SC2199
if [[ $@ =~ "--json" ]]; then
  json_format=1
  for a; do
    shift
    case $a in
    --json) continue ;;
    *) set -- "$@" "$a" ;;
    esac
  done
fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
  --create-blueprint)
    shift
    [[ -z "$1" ]] && __print_error "Missing arguments" && exit "$EC_MISSING_ARG"
    case "$1" in
    -h | --help)
      "$module_blueprints" --help $debug
      exit $?
      ;;
    *)
      # shellcheck disable=SC2068
      "$module_blueprints" --create $@ $debug
      exit $?
      ;;
    esac
    ;;
  --create)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <blueprint>" && exit "$EC_MISSING_ARG"
    bp_to_install="$1"
    bp_install_dir=$config_default_install_directory
    bp_install_version=0
    bp_id=
    shift
    if [ -n "$1" ]; then
      while [[ $# -ne 0 ]]; do
        case "$1" in
        --install-dir)
          shift
          [[ -z "$1" ]] && __print_error "Missing argument <install_dir>" && exit "$EC_MISSING_ARG"
          bp_install_dir="$1"
          ;;
        --version)
          shift
          [[ -z "$1" ]] && __print_error "Missing argument <version>" && exit "$EC_MISSING_ARG"
          bp_install_version=$1
          ;;
        --name)
          shift
          [[ -z "$1" ]] && __print_error "Missing argument <name>" && exit "$EC_MISSING_ARG"
          bp_id=$1
          ;;
        *)
          __print_error "Invalid argument $1" && exit "$EC_INVALID_ARG"
          ;;
        esac
        shift
      done
    fi
    [[ -z "$bp_install_dir" ]] && __print_error "Missing argument <dir>" && exit "$EC_MISSING_ARG"
    _install "$bp_to_install" "$bp_install_dir" $bp_install_version $bp_id
    exit $?
    ;;
  --uninstall)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <instance>" && exit "$EC_MISSING_ARG"
    _uninstall "$1"
    exit $?
    ;;
  --blueprints)
    shift
    if [[ -z "$1" ]]; then
      "$module_blueprints" --list $debug
      exit $?
    else
      while [[ $# -ne 0 ]]; do
        case "$1" in
        --detailed)
          detailed=1
          ;;
        --json)
          json_format=1
          ;;
        *)
          __print_error "Invalid argument $1" && exit "$EC_INVALID_ARG"
          ;;
        esac
        shift
      done

      "$module_blueprints" --list ${detailed:+--detailed} ${json_format:+--json} $debug
      exit $?
    fi
    ;;
  --ip)
    if command -v wget >/dev/null 2>&1; then
      wget -qO- https://icanhazip.com
      exit $?
    else
      __print_error "wget is required but not installed" && exit "$EC_MISSING_DEPENDENCY"
    fi
    ;;
  --config)
    ${EDITOR:-vim} "$CONFIG_FILE" || {
      __print_error "Failed to open $CONFIG_FILE with ${EDITOR:-vim}"
      exit "$EC_GENERAL"
    }
    ;;
  --update)
    update_script "$@"
    exit $?
    ;;
  --update-config)
    __merge_user_config_with_default
    exit $?
    ;;
  --instances)
    shift
    if [[ -z "$1" ]]; then
      "$module_instance" --list $debug
      exit $?
    else
      while [[ $# -ne 0 ]]; do
        case "$1" in
        --detailed)
          detailed=1
          ;;
        --json)
          json_format=1
          ;;
        --list) ;;
        *)
          blueprint=$1
          ;;
        esac
        shift
      done

      "$module_instance" --list ${detailed:+--detailed} ${json_format:+--json} $blueprint $debug
      exit $?
    fi
    ;;
  -i | --instance)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <instance>" && exit "$EC_MISSING_ARG"
    instance=$1

    # shellcheck disable=SC1090
    source "$(__find_instance_config "$instance")" || exit $EC_FAILED_SOURCE
    shift
    [[ -z "$1" ]] && __print_error "Missing argument [OPTION]" && exit "$EC_MISSING_ARG"
    case "$1" in
    --logs)
      shift
      follow=""
      if [[ "$1" == "-f" ]] || [[ "$1" == "--follow" ]]; then
        follow="--follow"
      fi
      "$module_lifecycle" --logs "$instance" $follow $debug
      exit $?
      ;;
    --status)
      "$module_instance" --status "$instance" $debug
      exit $?
      ;;
    --info)
      "$module_instance" --info "$instance" ${json_format:+--json} $debug
      exit $?
      ;;
    --is-active)
      # Inactive instances return exit code 1.
      __disable_error_checking
      "$module_lifecycle" --is-active "$instance" $debug
      exit $?
      ;;
    --start)
      "$module_lifecycle" --start "$instance" $debug
      exit $?
      ;;
    --stop)
      "$module_lifecycle" --stop "$instance" $debug
      exit $?
      ;;
    --restart)
      "$module_lifecycle" --restart "$instance" $debug
      exit $?
      ;;
    --save)
      "$instance_management_file" --save $debug
      exit $?
      ;;
    --input)
      shift
      [[ -z "$1" ]] && __print_error "Missing argument <command>" && exit "$EC_MISSING_ARG"
      "$module_instance" --input "$instance" "$1" $debug
      exit $?
      ;;
    -v | --version)
      shift
      if [[ -z "$1" ]]; then
        "$instance_management_file" --version --installed $debug
        exit $?
      fi
      case "$1" in
      --installed)
        "$instance_management_file" --version --installed $debug
        exit $?
        ;;
      --latest)
        "$instance_management_file" --version --latest $debug
        exit $?
        ;;
      *) __print_error "Invalid argument $1" && exit "$EC_INVALID_ARG" ;;
      esac
      ;;
    --check-update)
      "$instance_management_file" --version --compare $debug
      exit $?
      ;;
    --update)
      "$instance_management_file" --update $debug
      exit $?
      ;;
    --backups)
      "$instance_management_file" --list-backups $debug
      exit $?
      ;;
    --create-backup)
      "$instance_management_file" --create-backup $debug
      exit $?
      ;;
    --restore-backup)
      [[ -z "$1" ]] && __print_error "Missing argument <backup>" && exit "$EC_MISSING_ARG"
      "$instance_management_file" --restore-backup "$1" $debug
      exit $?
      ;;
    --modify)
      shift
      [[ -z "$1" ]] && __print_error "Missing argument <option>" && exit "$EC_MISSING_ARG"
      case "$1" in
      --add)
        shift
        [[ -z "$1" ]] && __print_error "Missing argument <option>" && exit "$EC_MISSING_ARG"
        case "$1" in
        ufw)
          "$module_files" -i "$instance" --create --ufw $debug
          exit $?
          ;;
        systemd)
          "$module_files" -i "$instance" --create --systemd $debug
          exit $?
          ;;
        symlink)
          "$module_files" -i "$instance" --create --symlink $debug
          exit $?
          ;;
        *)
          __print_error "Invalid argument $1"
          exit "$EC_INVALID_ARG"
          ;;
        esac
        ;;
      --remove)
        shift
        [[ -z "$1" ]] && __print_error "Missing argument <option>" && exit "$EC_MISSING_ARG"
        case "$1" in
        ufw)
          "$module_files" -i "$instance" --remove --ufw $debug
          exit $?
          ;;
        systemd)
          "$module_files" -i "$instance" --remove --systemd $debug
          exit $?
          ;;
        symlink)
          "$module_files" -i "$instance" --remove --symlink $debug
          exit $?
          ;;
        *)
          __print_error "Invalid argument $1" && exit "$EC_INVALID_ARG"
          ;;
        esac
        ;;
      *)
        __print_error "Invalid argument $1" && exit "$EC_INVALID_ARG"
        ;;
      esac
      ;;
    *)
      __print_error "Invalid argument $1" && exit "$EC_INVALID_ARG"
      ;;
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
    __print_error "Invalid argument $1" && exit "$EC_INVALID_ARG"
    ;;
  esac
  shift
done

exit 0
