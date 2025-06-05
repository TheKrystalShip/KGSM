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
  module_common="$(find "$KGSM_ROOT" -type f -name common.sh -print -quit)"
  if [[ -z "$module_common" ]]; then
    echo "${0##*/} ERROR: Could not find module common.sh" >&2
    echo "${0##*/} ERROR: Install compromised, please reinstall KGSM" >&2
    exit 1
  fi

  # shellcheck disable=SC1090
  source "$module_common" || exit 1
fi

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
  --update                    Update KGSM to the latest version.
    [--force]                 Ignore version check and download the latest
                              version available.
  --update-config             Update config.ini with the latest options added
                              or modified in config.default.ini
  --ip                        Print the external server IP address.
  --config                    Modify the configuration file.
  -v, --version               Print the KGSM version.

${UNDERLINE}Blueprints${END}
  --create-blueprint          Create a new blueprints file.
    [-h, --help]              Print help information about the blueprint
                              creation process.
  --blueprints                List all available blueprints.
  --blueprints --json         Print a JSON array with all blueprints.
  --blueprints --json --detailed
                              Print a detailed JSON formatted Map with
                              information on all blueprints.
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
  --instances --json          Print a JSON formatted array with all instances.
  --instances --json --detailed
                              Print a detailed JSON Map with all instances
                              and their information.
                              Optionally a blueprint name can be specified in
                              order to only list instances of that blueprint

  -i, --instance <x> OPTION   Interact with an instance.
                              OPTION represents one of the following:

    --logs                    Print the last few lines of the instance's log.
      [-f, --follow]          Continuously follow the log output.
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

if [[ "$KGSM_RUN_UPDATE_CHECK" -eq 1 ]]; then
  check_for_update
fi

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
          __print_error "Invalid argument $1" && exit "$EC_INVALID_ARG"
          ;;
      esac
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

function _install() {
  local blueprint=$1
  local install_dir=$2
  # Value of 0 means get latest
  local version=$3
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
      ${identifier:+--id $identifier} \
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
    version=$("$INSTANCE_MANAGE_FILE" --version --latest)
  fi

  "$INSTANCE_MANAGE_FILE" --download "$version" $debug || return $EC_FAILED_DOWNLOAD
  "$INSTANCE_MANAGE_FILE" --deploy $debug || return $EC_FAILED_DEPLOY
  "$INSTANCE_MANAGE_FILE" --version --save "$version" $debug || return $EC_FAILED_VERSION_SAVE

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

  # If the user selected an action that requires a blueprint or instance,
  # check if there are any available.
  if [[ "${#blueprints_or_instances[@]}" -eq 0 ]]; then
    __print_warning "No instances found"
    return 0
  fi

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
        read -r -p "Installation directory: " install_directory && [[ -n $install_directory ]] || exit "$EC_INVALID_ARG"
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
      "$0" --uninstall "$blueprint_or_instance" $debug
      ;;
    --restore-backup)
      # shellcheck disable=SC2207
      backups_array=($("$INSTANCE_MANAGE_FILE" --list-backups))
      [[ "${#backups_array[@]}" -eq 0 ]] && echo "No backups found. Exiting." >&2 && return "$EC_GENERAL"

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
        ["Add symlink"]="--add symlink"
        ["Remove symlink"]="--remove symlink"
      )
      local mod_action

      local instance_config_file
      instance_config_file=$(__find_instance_config "$blueprint_or_instance")

      if grep -q "INSTANCE_SYSTEMD_SERVICE_FILE=" < "$instance_config_file"; then
        modify_options+=("Remove systemd")
      else
        modify_options+=("Add systemd")
      fi

      if grep -q "INSTANCE_UFW_FILE=" < "$instance_config_file"; then
        modify_options+=("Remove ufw")
      else
        modify_options+=("Add ufw")
      fi

      if grep -q "INSTANCE_SYMLINK=" < "$instance_config_file"; then
        modify_options+=("Remove symlink")
      else
        modify_options+=("Add symlink")
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
      "$0" --instance "$blueprint_or_instance" --modify $mod_action $debug
      ;;
    *)
      # shellcheck disable=SC2086
      $0 --instance $blueprint_or_instance $action $debug
      ;;
  esac
}

# If it's started with no args, default to interactive mode
[[ "$#" -eq 0 ]] && _interactive && exit $?

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
    --install)
      shift
      [[ -z "$1" ]] && __print_error "Missing argument <blueprint>" && exit "$EC_MISSING_ARG"
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
              [[ -z "$1" ]] && __print_error "Missing argument <install_dir>" && exit "$EC_MISSING_ARG"
              bp_install_dir="$1"
              ;;
            --version)
              shift
              [[ -z "$1" ]] && __print_error "Missing argument <version>" && exit "$EC_MISSING_ARG"
              bp_install_version=$1
              ;;
            --id)
              shift
              [[ -z "$1" ]] && __print_error "Missing argument <id>" && exit "$EC_MISSING_ARG"
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
      if command -v wget > /dev/null 2>&1; then
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
          "$INSTANCE_MANAGE_FILE" --save $debug
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
            "$INSTANCE_MANAGE_FILE" --version --installed $debug
            exit $?
          fi
          case "$1" in
            --installed)
              "$INSTANCE_MANAGE_FILE" --version --installed $debug
              exit $?
              ;;
            --latest)
              "$INSTANCE_MANAGE_FILE" --version --latest $debug
              exit $?
              ;;
            *) __print_error "Invalid argument $1" && exit "$EC_INVALID_ARG" ;;
          esac
          ;;
        --check-update)
          "$INSTANCE_MANAGE_FILE" --version --compare $debug
          exit $?
          ;;
        --update)
          "$INSTANCE_MANAGE_FILE" --update $debug
          exit $?
          ;;
        --backups)
          "$INSTANCE_MANAGE_FILE" --list-backups $debug
          exit $?
          ;;
        --create-backup)
          "$INSTANCE_MANAGE_FILE" --create-backup $debug
          exit $?
          ;;
        --restore-backup)
          [[ -z "$1" ]] && __print_error "Missing argument <backup>" && exit "$EC_MISSING_ARG"
          "$INSTANCE_MANAGE_FILE" --restore-backup "$1" $debug
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
