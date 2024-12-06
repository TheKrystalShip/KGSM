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

SELF_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

module_overrides=$(__load_module overrides.sh)

# shellcheck disable=SC1090
source "$(__load_instance "$instance")" || exit "$EC_FAILED_SOURCE"

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

  [[ -z "$INSTANCE_APP_ID" ]] && __print_error "INSTANCE_APP_ID is expected but it's not set" && return "$EC_MISSING_ARG"
  [[ -z "$INSTANCE_STEAM_ACCOUNT_NEEDED" ]] && __print_error "INSTANCE_STEAM_ACCOUNT_NEEDED is expected but it's not set" && return "$EC_MISSING_ARG"

  username=anonymous
  if [[ $INSTANCE_STEAM_ACCOUNT_NEEDED -ne 0 ]]; then
    [[ -z "$STEAM_USERNAME" ]] && __print_error "STEAM_USERNAME is expected but it's not set" && return "$EC_MISSING_ARG"
    [[ -z "$STEAM_PASSWORD" ]] && __print_error "STEAM_PASSWORD is expected but it's not set" && return "$EC_MISSING_ARG"

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
source "$module_overrides" "$instance" || exit "$EC_FAILED_SOURCE"

__emit_instance_download_started "${instance%.ini}"

func_download "$version" "$INSTANCE_TEMP_DIR" || exit $?

__emit_instance_download_finished "${instance%.ini}"

__emit_instance_downloaded "${instance%.ini}"

exit 0
