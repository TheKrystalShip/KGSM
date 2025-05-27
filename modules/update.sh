#!/usr/bin/env bash

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

[[ "$EUID" -ne 0 ]] && SUDO="sudo -E"

SELF_PATH="$(dirname "$(readlink -f "$0")")"

# Check for KGSM_ROOT
if [ -z "$KGSM_ROOT" ]; then
  while [[ "$SELF_PATH" != "/" ]]; do
    [[ -f "$SELF_PATH/kgsm.sh" ]] && KGSM_ROOT="$SELF_PATH" && break
    SELF_PATH="$(dirname "$SELF_PATH")"
  done
  [[ -z "$KGSM_ROOT" ]] && echo "Error: Could not locate kgsm.sh. Ensure the directory structure is intact." && exit 1
  export KGSM_ROOT
fi

if [[ ! "$KGSM_COMMON_LOADED" ]]; then
  module_common="$(find "$KGSM_ROOT" -type f -name common.sh -print -quit)"
  [[ -z "$module_common" ]] && echo "${0##*/} ERROR: Failed to load module common.sh" >&2 && exit 1
  # shellcheck disable=SC1090
  source "$module_common" || exit 1
fi

module_version=$(__load_module version.sh)
module_download=$(__load_module download.sh)
module_backup=$(__load_module backup.sh)
module_deploy=$(__load_module deploy.sh)
module_instances=$(__load_module instances.sh)

# shellcheck disable=SC1090
source "$(__load_instance "$instance")" || exit "$EC_FAILED_SOURCE"

function func_print_title() {
  {
    echo ""
    echo "================================================================================"
    echo "> $1 <"
    echo "================================================================================"
    echo ""
  }
}

function func_main() {

  [[ $verbose ]] && func_print_title "Update process started for $INSTANCE_FULL_NAME"

  ############################################################################
  #### Check for new version
  ############################################################################

  if [[ $verbose ]]; then
    func_print_title "1/7 Version check"
    printf "Checking for latest version...\n"
  fi

  local latest_version
  latest_version=$("$module_version" -i "$instance" --latest)

  [[ "$verbose" ]] && printf "Installed version:\t%s\n" "$INSTANCE_INSTALLED_VERSION"

  [[ -z "$latest_version" ]] && __print_error "new version number is empty, exiting" && return "$EC_GENERAL"

  [[ "$verbose" ]] && printf "Latest version available:\t%s\n" "$latest_version"

  if [[ "$INSTANCE_INSTALLED_VERSION" == "$latest_version" ]]; then
    printf "WARNING: latest version already installed.\n"
    printf "Continuing would overwrite existing install\n"
    read -r -p "Continue? (Y/n): " confirm && [[ $confirm != [nN] ]] || exit "$EC_GENERAL"
  fi

  ############################################################################
  #### Download new version
  ############################################################################

  if [[ "$verbose" ]]; then
    func_print_title "2/7 Download"
    printf "Downloading version %s\n" "$latest_version"
  fi

  if ! "$module_download" -i "$instance"; then
    __print_error "Failed to download new version, exiting" && return "$EC_FAILED_DOWNLOAD"
  fi

  [[ "$verbose" ]] && printf "Download completed\n"

  ############################################################################
  #### Check if instance is currently running and shut it down if needed
  ############################################################################

  if [[ "$verbose" ]]; then
    func_print_title "3/7 Instance status"
    printf "Checking current instance status\n"
  fi

  local instance_status
  instance_status=$("$module_instances" --is-active "$instance")

  if [[ "$instance_status" == "active" ]]; then
    [[ "$verbose" ]] && printf "Instance %s is currently running, shutting down...\n" "$instance"

    if ! "$module_instances" --stop "$instance"; then
      __print_error "Failed to shutdown $instance" && return "$EC_GENERAL"
    fi

    [[ "$verbose" ]] && printf "Instance %s successfully stopped\n" "$instance"
  else
    [[ "$verbose" ]] && printf "Instance %s is not currently running, continuing\n" "$instance"
  fi

  ############################################################################
  #### Backup existing install if it exists
  ############################################################################

  if [[ "$verbose" ]]; then
    func_print_title "4/7 Backup"
    printf "Creating backup of current version\n"
  fi

  if ! "$module_backup" -i "$instance" --create; then
    __print_error "Failed to create backup, exiting" && return "$EC_GENERAL"
  fi

  [[ "$verbose" ]] && printf "Backup complete\n"

  ############################################################################
  #### Deploy newly downloaded version
  ############################################################################

  if [[ "$verbose" ]]; then
    func_print_title "5/7 Deployment"
    printf "Deploying %s...\n" "$latest_version"
  fi

  if ! "$module_deploy" -i "$instance"; then
    __print_error "Failed to deploy $latest_version, exiting" && return "$EC_GENERAL"
  fi

  [[ "$verbose" ]] && printf "Deployment complete.\n"

  ############################################################################
  #### Restore instance state if needed
  ############################################################################

  [[ "$verbose" ]] && func_print_title "6/7 Restore"

  if [[ "$instance_status" == "active" ]]; then
    [[ "$verbose" ]] && printf "Starting the instance back up\n"

    if ! "$module_instances" --start "$instance"; then
      __print_error "Failed to start $instance" && return "$EC_GENERAL"
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
    __print_error "Failed to save version $latest_version for $instance" && return "$EC_GENERAL"
  fi

  [[ "$verbose" ]] && printf "Successfully updated %s to version %s\n" "$instance" "$latest_version"

  return 0
}

__emit_instance_update_started "${instance%.ini}"

func_main "$@"

__emit_instance_update_finished "${instance%.ini}"

__emit_instance_updated "${instance%.ini}"

exit 0
