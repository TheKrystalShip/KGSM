#!/bin/bash

function usage() {
  echo "Download the necessary files for a game server.

Usage:
  $(basename "$0") [-i | --instance <instance>] OPTION

Options:
  -h, --help                  Prints this message
  -i, --instance <instance>   Full name of the instance, equivalent of
                              INSTANCE_FULL_NAME from the instance config file
                              The .ini extension is not required
  -v, --version <v>           Optional: Version number to download.
                              This feature is not currently used

Examples:
  $(basename "$0")-i factorio-9d52mZ.ini
  $(basename "$0") --instance minecraft-gC6dmh -v 1.20
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
  -v | --version)
    shift
    [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument <version>" >&2 && exit 1
    version=$1
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

# Trap CTRL-C
trap "echo "" && exit" INT

module_common=$(find "$KGSM_ROOT" -type f -name common.sh)
[[ -z "$module_common" ]] && echo "${0##*/} ERROR: Could not find module common.sh" >&2 && exit 1

# shellcheck disable=SC1090
source "$module_common" || exit 1

module_overrides=$(__load_module overrides.sh)

# shellcheck disable=SC1090
source "$(__load_instance "$instance")" || exit 1

# If no version is passed, just fetch the latest
if [[ -z "$version" ]]; then
  module_version=$(__load_module version.sh)
  version=$("$module_version" -i "$instance" --latest)
fi

# Calls SteamCMD to handle the download
function func_download() {
  # shellcheck disable=SC2034
  local version=$1
  local dest=$2

  [[ -z "$INSTANCE_APP_ID" ]] && __print_error "INSTANCE_APP_ID is expected but it's not set" && return 1
  [[ -z "$INSTANCE_STEAM_ACCOUNT_NEEDED" ]] && __print_error "INSTANCE_STEAM_ACCOUNT_NEEDED is expected but it's not set" && return 1

  username=anonymous
  if [[ $INSTANCE_STEAM_ACCOUNT_NEEDED -ne 0 ]]; then
    [[ -z "$STEAM_USERNAME" ]] && __print_error "STEAM_USERNAME is expected but it's not set" && return 1
    [[ -z "$STEAM_PASSWORD" ]] && __print_error "STEAM_PASSWORD is expected but it's not set" && return 1

    username="$STEAM_USERNAME $STEAM_PASSWORD"
  fi

  steamcmd \
    +@sSteamCmdForcePlatformType linux \
    +force_install_dir $dest \
    +login $username \
    +app_update $INSTANCE_APP_ID \
    validate \
    +quit
}

# shellcheck disable=SC1090
source "$module_overrides" "$instance" || exit 1

func_download "$version" "$INSTANCE_TEMP_DIR" || exit $?

exit 0
