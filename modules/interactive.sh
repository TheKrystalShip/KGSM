#!/usr/bin/env bash

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

debug=
# shellcheck disable=SC2199
if [[ $@ =~ "--debug" ]]; then
  debug="--debug"
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

SELF_PATH="$(dirname "$(readlink -f "$0")")"

# Absolute path to this script file
if [ -z "$KGSM_ROOT" ]; then
  while [[ "$SELF_PATH" != "/" ]]; do
    [[ -f "$SELF_PATH/kgsm.sh" ]] && KGSM_ROOT="$SELF_PATH" && break
    SELF_PATH="$(dirname "$SELF_PATH")"
  done
  [[ -z "$KGSM_ROOT" ]] && echo "Error: Could not locate kgsm.sh. Ensure the directory structure is intact." && exit 1
  export KGSM_ROOT
fi

if [[ ! "$KGSM_COMMON_LOADED" ]]; then
  module_common="$(find "$KGSM_ROOT/modules" -type f -name common.sh -print -quit)"
  [[ -z "$module_common" ]] && echo "${0##*/} ERROR: Failed to load module common.sh" >&2 && exit 1
  # shellcheck disable=SC1090
  source "$module_common" || exit 1
fi

export kgsm="$KGSM_ROOT/kgsm.sh"

function usage() {
  local UNDERLINE="\e[4m"
  local END="\e[0m"

  echo -e "${UNDERLINE}Interactive Mode for Krystal Game Server Manager${END}

This module provides a user-friendly menu-driven interface for managing game servers.

${UNDERLINE}Usage:${END}
  $(basename "$0") [OPTIONS]

${UNDERLINE}Options:${END}
  -h, --help              Display this help information
  -i, --interactive       Launch the interactive menu interface
  --description           Show the KGSM description header used in the interactive menu
"
}

function print_interactive_help() {
  local UNDERLINE="\e[4m"
  local END="\e[0m"
  local BOLD="\e[1m"

  echo -e "$(__get_description)"
  echo -e "${BOLD}${UNDERLINE}Interactive Menu Options${END}\n"

  echo -e "  ${UNDERLINE}Server Management${END}"
  echo -e "  ${BOLD}Install${END}            Deploy a new game server from an available blueprint
                     Select from various game types and configurations

  ${BOLD}Uninstall${END}          Remove a game server instance from your system
                     Note: This preserves the original blueprint file but removes
                     all instance data, configuration, and related files

  ${BOLD}Start${END}              Launch a game server instance
                     Makes the server available to players

  ${BOLD}Stop${END}               Gracefully shut down a running server instance
                     Ensures proper save and cleanup procedures

  ${BOLD}Restart${END}            Perform a complete stop and start sequence
                     Useful after configuration changes or to refresh the server

  ${UNDERLINE}Monitoring & Information${END}"
  echo -e "  ${BOLD}List blueprints${END}    View all available game server templates
                     Shows what server types can be installed

  ${BOLD}List instances${END}     Display all created server instances with detailed info
                     Provides overview of your server deployments

  ${BOLD}Status${END}             Show comprehensive information about a server instance
                     Includes running state, configuration, and resource usage

  ${BOLD}Logs${END}               View recent server log entries
                     Shows the last 10 lines from the instance's log file

  ${UNDERLINE}Maintenance & Configuration${END}"
  echo -e "  ${BOLD}Modify${END}             Customize instance features and integrations
                     Add/remove system integrations:
                     • ufw (firewall rules)
                     • systemd (service management)
                     • symlink (command shortcuts)

  ${BOLD}Check for update${END}   Verify if new versions are available for an instance
                     Reports available updates or confirms current version

  ${BOLD}Update${END}             Perform a complete update procedure for an instance
                     Includes backup creation, download, and deployment

  ${BOLD}Create backup${END}      Generate a complete backup of a server instance
                     Preserves all instance data and configurations

  ${BOLD}Restore backup${END}     Recover a server from a previously created backup
                     Select from available backups to restore

  ${BOLD}Help${END}               Display this information screen
"
}

function __get_description() {
  # Get the KGSM version
  local version
  version=$("$KGSM_ROOT/installer.sh" --version $debug)

  echo "Krystal Game Server Manager - $version

Create, install, and manage game servers on Linux.

If you have any problems while using KGSM, please don't hesitate to create an
issue on GitHub: https://github.com/TheKrystalShip/KGSM/issues"
}

function start_interactive() {
  echo "$(__get_description)

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
    "Uninstall"
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
    "Help"
  )

  declare -A arg_map=(
    ["Install"]=--create
    ["Uninstall"]=--uninstall
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
  --create)
    # shellcheck disable=SC2178
    # shellcheck disable=SC2207
    blueprints_or_instances=($("$kgsm" --blueprints $debug | tr '\n' ' '))
    PS3="Choose a blueprint: "
    ;;
  --blueprints)
    exec "$kgsm" --blueprints $debug
    ;;
  --instances)
    exec "$kgsm" --instances $debug
    ;;
  --help)
    print_interactive_help
    return 0
    ;;
  --status)
    # shellcheck disable=SC2207
    # shellcheck disable=SC2178
    blueprints_or_instances=($("$kgsm" --instances $debug))
    ;;
  *)
    # shellcheck disable=SC2207
    # shellcheck disable=SC2178
    blueprints_or_instances=($("$kgsm" --instances $debug))
    "$kgsm" --instances --detailed $debug
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

  # Recursively call the script with the given params
  # --install has a different arg order
  case "$action" in
  --create)
    install_directory=${config_default_install_directory:-}
    if [ -z "$install_directory" ]; then
      echo "'default_install_directory' is not set in the configuration file, please specify an installation directory" >&2
      read -r -p "Installation directory: " install_directory && [[ -n $install_directory ]] || return $EC_INVALID_ARG
    fi

    read -r -p "Version to install (leave empty for latest): " version
    read -r -p "Instance name (leave empty for default): " instance_name

    echo "Creating an instance of $blueprint_or_instance..." >&2
    # shellcheck disable=SC2086
    "$kgsm" \
      $action $blueprint_or_instance \
      --install-dir $install_directory \
      ${version:+--version "$version"} \
      ${instance_name:+--name "$instance_name"} \
      $debug
    ;;
  --uninstall)
    "$kgsm" --uninstall "$blueprint_or_instance" $debug
    ;;
  --restore-backup)
    local instance_config_file
    local instance_management_file
    local backups_array
    local backup_to_restore

    # Get the instance management file path
    instance_config_file=$(__find_instance_config "$blueprint_or_instance")
    # shellcheck disable=SC1090
    source "$instance_config_file" || return "$EC_FAILED_SOURCE"

    # shellcheck disable=SC2207
    backups_array=($("$instance_management_file" --list-backups $debug))
    [[ "${#backups_array[@]}" -eq 0 ]] && echo "No backups found. Exiting." >&2 && return $EC_GENERAL

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
    "$kgsm" --instance $blueprint_or_instance $action $backup_to_restore $debug
    ;;
  --modify)
    declare -a modify_options=()
    declare -A modify_arg_map=(
      ["Enable systemd"]="--add systemd"
      ["Disable systemd"]="--remove systemd"
      ["Enable ufw"]="--add ufw"
      ["Disable ufw"]="--remove ufw"
      ["Create symlink"]="--add symlink"
      ["Remove symlink"]="--remove symlink"
      ["Enable UPnP"]="--add upnp"
      ["Disable UPnP"]="--remove upnp"
    )
    local mod_action

    local instance_config_file
    instance_config_file=$(__find_instance_config "$blueprint_or_instance")

    if grep -q "instance_systemd_service_file=" <"$instance_config_file"; then
      modify_options+=("Disable systemd")
    else
      modify_options+=("Enable systemd")
    fi

    if grep -q "instance_ufw_file=" <"$instance_config_file"; then
      modify_options+=("Disable ufw")
    else
      modify_options+=("Enable ufw")
    fi

    if grep -q "instance_command_shortcut_file=" <"$instance_config_file"; then
      modify_options+=("Remove symlink")
    else
      modify_options+=("Create symlink")
    fi

    if grep -q "instance_enable_port_forwarding=\"true\"" <"$instance_config_file"; then
      modify_options+=("Disable UPnP")
    else
      modify_options+=("Enable UPnP")
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
    "$kgsm" --instance "$blueprint_or_instance" --modify $mod_action $debug
    ;;
  *)
    # shellcheck disable=SC2086
    "$kgsm" --instance $blueprint_or_instance $action $debug
    ;;
  esac
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
  -h | --help)
    usage
    exit 0
    ;;
  -i | --interactive)
    start_interactive
    exit $?
    ;;
  *)
    __print_error "Invalid argument $1"
    exit $EC_INVALID_ARG
    ;;
  esac
  shift
done

# By default, start interactive mode if no arguments provided
start_interactive
exit $?
