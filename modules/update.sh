#!/bin/bash

function usage() {
  echo "Runs a full update process for a game server.

Usage:
  $(basename "$0") [-i | --instance <instance>] OPTION

Options:
  -h, --help                  Prints this message
  -i, --instance <instance>   Full name of the instance, equivalent of
                              INSTANCE_FULL_NAME from the instance config file
                              The .ini extension is not required
  --verbose                   Enable verbose output

Examples:
  $(basename "$0") -i valheim-7831.ini
  $(basename "$0") --instance terraria-0576 --verbose
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
  -i | --instance)
    shift
    [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument <instance>" >&2 && exit 1
    instance=$1
    ;;
  --verbose)
    verbose=1
    ;;
  *)
    echo "${0##*/} ERROR: Invalid argument $1" >&2 && exit 1
    ;;
  esac
  shift
done

# Check for KGSM_ROOT env variable
if [ -z "$KGSM_ROOT" ]; then
  echo "WARNING: KGSM_ROOT not found, sourcing /etc/environment." >&2
  # shellcheck disable=SC1091
  source /etc/environment
  [[ -z "$KGSM_ROOT" ]] && echo "${0##*/} ERROR: KGSM_ROOT not found, exiting." >&2 && exit 1
  echo "INFO: KGSM_ROOT found in /etc/environment, consider rebooting the system" >&2
  if ! declare -p KGSM_ROOT | grep -q 'declare -x'; then export KGSM_ROOT; fi
fi

# Read configuration file
if [ -z "$KGSM_CONFIG_LOADED" ]; then
  CONFIG_FILE="$(find "$KGSM_ROOT" -type f -name config.ini)"
  [[ -z "$CONFIG_FILE" ]] && echo "${0##*/} ERROR: Failed to load config.ini file" >&2 && exit 1
  while IFS= read -r line || [ -n "$line" ]; do
    # Ignore comment lines and empty lines
    if [[ "$line" =~ ^#.*$ ]] || [[ -z "$line" ]]; then continue; fi
    export "${line?}"
  done <"$CONFIG_FILE"
  export KGSM_CONFIG_LOADED=1
fi

[[ "$EUID" -ne 0 ]] && SUDO="sudo -E"

module_common=$(find "$KGSM_ROOT" -type f -name common.sh)
[[ -z "$module_common" ]] && echo "${0##*/} ERROR: Could not find module common.sh" >&2 && exit 1

# shellcheck disable=SC1090
source "$module_common" || exit 1

module_version=$(__load_module version.sh)
module_download=$(__load_module download.sh)
module_backup=$(__load_module backup.sh)
module_deploy=$(__load_module deploy.sh)
module_instances=$(__load_module instances.sh)

# shellcheck disable=SC1090
source "$(__load_instance "$instance")" || exit 1

function func_exit_error() {
  printf "%s\n" "${*:- Update process cancelled}" >&2
  exit 1
}

# Trap CTRL-C
trap func_exit_error INT

function func_print_title() {
  {
    echo ""
    echo "================================================================================"
    echo "> $1 <"
    echo "================================================================================"
    echo ""
  } >&2
}

function func_main() {

  [[ $verbose ]] && func_print_title "Update process started for $INSTANCE_FULL_NAME"

  ############################################################################
  #### Check for new version
  ############################################################################

  if [[ $verbose ]]; then
    func_print_title "1/7 Version check"
    printf "Checking for latest version...\n" >&2
  fi

  local latest_version
  latest_version=$("$module_version" -i "$instance" --latest)

  [[ "$verbose" ]] && printf "Installed version:\t%s\n" "$INSTANCE_INSTALLED_VERSION" >&2

  [[ -z "$latest_version" ]] && __print_error "new version number is empty, exiting" && return 1

  [[ "$verbose" ]] && printf "Latest version available:\t%s\n" "$latest_version"

  if [[ "$INSTANCE_INSTALLED_VERSION" == "$latest_version" ]]; then
    printf "WARNING: latest version already installed.\n" >&2
    printf "Continuing would overwrite existing install\n" >&2
    read -r -p "Continue? (Y/n): " confirm && [[ $confirm != [nN] ]] || exit 1
  fi

  ############################################################################
  #### Download new version
  ############################################################################

  if [[ "$verbose" ]]; then
    func_print_title "2/7 Download"
    printf "Downloading version %s\n" "$latest_version" >&2
  fi

  if ! "$module_download" -i "$instance"; then
    __print_error "Failed to download new version, exiting" && return 1
  fi

  [[ "$verbose" ]] && printf "Download completed\n"

  ############################################################################
  #### Check if instance is currently running and shut it down if needed
  ############################################################################

  if [[ "$verbose" ]]; then
    func_print_title "3/7 Instance status"
    printf "Checking current instance status\n" >&2
  fi

  local instance_status
  instance_status=$("$module_instances" --is-active "$instance")

  if [[ "$instance_status" == "active" ]]; then
    [[ "$verbose" ]] && printf "Instance %s is currently running, shutting down...\n" "$instance" >&2

    if ! "$module_instances" --stop "$instance"; then
      __print_error "Failed to shutdown $instance" && return 1
    fi

    [[ "$verbose" ]] && printf "Instance %s successfully stopped\n" "$instance" >&2
  else
    [[ "$verbose" ]] && printf "Instance %s is not currently running, continuing\n" "$instance" >&2
  fi

  ############################################################################
  #### Backup existing install if it exists
  ############################################################################

  if [[ "$verbose" ]]; then
    func_print_title "4/7 Backup"
    printf "Creating backup of current version\n" >&2
  fi

  if ! "$module_backup" -i "$instance" --create; then
    __print_error "Failed to create backup, exiting" && return 1
  fi

  [[ "$verbose" ]] && printf "Backup complete\n" >&2

  ############################################################################
  #### Deploy newly downloaded version
  ############################################################################

  if [[ "$verbose" ]]; then
    func_print_title "5/7 Deployment"
    printf "Deploying %s...\n" "$latest_version" >&2
  fi

  if ! "$module_deploy" -i "$instance"; then
    __print_error "Failed to deploy $latest_version, exiting" && return 1
  fi

  [[ "$verbose" ]] && printf "Deployment complete.\n"

  ############################################################################
  #### Restore instance state if needed
  ############################################################################

  [[ "$verbose" ]] && func_print_title "6/7 Restore"

  if [[ "$instance_status" == "active" ]]; then
    [[ "$verbose" ]] && printf "Starting the instance back up\n"

    if ! "$module_instances" --start "$instance"; then
      __print_error "Failed to start $instance" && return 1
    fi

    [[ "$verbose" ]] && printf "Instance started successfully\n"
  else
    [[ "$verbose" ]] && printf "Instance was %s, skipping restore step\n" "$instance_status"
  fi

  ############################################################################
  #### Save the new installed version number
  ############################################################################

  if [[ "$verbose" ]]; then
    func_print_title "7/7 Updating version record"
    printf "Saving new version %s\n" "$latest_version"
  fi

  if ! "$module_version" -i "$instance" --save "$latest_version"; then
    __print_error "Failed to save version $latest_version for $instance" && return 1
  fi

  [[ "$verbose" ]] && printf "Successfully updated %s to version %s\n" "$instance" "$latest_version" >&2

  return 0
}

func_main "$@" && exit $?
