#!/bin/bash

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

function usage() {
  echo "Used to fetch various version informations.

Usage:
  $(basename "$0") [-i | --instance <instance>] OPTION

Options:
  -h, --help                  Prints this message
  -i, --instance <instance>   Full name of the instance, equivalent of
                              INSTANCE_FULL_NAME from the instance config file
                              The .ini extension is not required
    --installed               Prints the currently installed version
    --latest                  Prints the latest version available
    --compare                 Compares the latest version available with
                              the currently installed version. If the latest
                              available version is different than the installed
                              version then it prints the latest version
    --save <version>          Save the given version

Exit codes:
  0: Success / New version was found, written to stdout
  1: Error / No new version found
  2: Other error

Examples:
  $(basename "$0") -i valheim-3596 --installed
  $(basename "$0") --instance terraria-4759.ini --latest
  $(basename "$0") -i 7dtd-379158.ini --compare
  $(basename "$0") --instance minecraft-1945 --save 1.20.1
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

[[ $# -eq 0 ]] && usage && exit 1

# Read the argument values
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
    *)
      break
      ;;
  esac
  shift
done

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

module_overrides=$(__load_module overrides.sh)

instance_config_file=$(__load_instance "$instance")
# shellcheck disable=SC1090
source "$instance_config_file" || exit $EC_FAILED_SOURCE

# https://github.com/ValveSoftware/steam-for-linux/issues/10975
function func_get_latest_version() {

  app_id="$(grep "BP_APP_ID=" < "$INSTANCE_BLUEPRINT_FILE" | cut -d '=' -f2 | tr -d '"')"
  {
    [[ -z "$app_id" ]] || [[ "$app_id" -eq 0 ]]
  } && __print_error "APP_ID is expected but it's not set" && return $EC_MALFORMED_INSTANCE

  username=anonymous
  auth_level="$(grep "BP_STEAM_AUTH_LEVEL=" < "$INSTANCE_BLUEPRINT_FILE" | cut -d '=' -f2 | tr -d '"')"
  if [[ $auth_level -ne 0 ]]; then
    [[ -z "$STEAM_USERNAME" ]] && __print_error "STEAM_USERNAME is expected but it's not set" && return $EC_MISSING_ARG
    [[ -z "$STEAM_PASSWORD" ]] && __print_error "STEAM_PASSWORD is expected but it's not set" && return $EC_MISSING_ARG

    username="$STEAM_USERNAME $STEAM_PASSWORD"
  fi

  local latest_version
  latest_version=$(steamcmd \
    +login $username \
    +app_info_update 1 \
    +app_info_print $app_id \
    +quit | tr '\n' ' ' | grep \
    --color=NEVER \
    -Po '"branches"\s*{\s*"public"\s*{\s*"buildid"\s*"\K(\d*)')

  if [[ -z "$latest_version" ]]; then
    __print_error "Failed to retrieve latest version, got empty response from SteamCMD"
    return "$EC_GENERAL"
  fi

  echo "$latest_version"
}

function _compare() {
  [[ -z "$INSTANCE_INSTALLED_VERSION" ]] && __print_error "$instance is missing INSTANCE_INSTALLED_VERSION varible" && return $EC_MALFORMED_INSTANCE

  local latest_version
  latest_version=$(func_get_latest_version)

  [[ -z "$latest_version" ]] && return $EC_GENERAL
  [[ "$latest_version" == "$INSTANCE_INSTALLED_VERSION" ]] && return $EC_GENERAL

  echo "$latest_version"
}

function _save_version() {
  local version=$1

  if grep -q "INSTANCE_INSTALLED_VERSION=" < "$instance_config_file"; then
    if ! sed -i "/INSTANCE_INSTALLED_VERSION=*/c\INSTANCE_INSTALLED_VERSION=$version" "$instance_config_file" > /dev/null; then
      return $EC_FAILED_SED
    fi
  else
    {
      echo ""
      echo "# Installed version"
      echo "INSTANCE_INSTALLED_VERSION=$version"
    } >> "$instance_config_file"
  fi

  echo "$version" > "${INSTANCE_WORKING_DIR}/${INSTANCE_FULL_NAME}.version"

  __emit_instance_version_updated "${instance%.ini}" "$INSTANCE_INSTALLED_VERSION" "$version"

  return 0
}

# shellcheck disable=SC1090
source "$module_overrides" "$instance"

# Read the argument values
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --compare)
      _compare
      exit $?
      ;;
    --installed)
      echo "$INSTANCE_INSTALLED_VERSION" && exit 0
      ;;
    --latest)
      func_get_latest_version
      exit $?
      ;;
    --save)
      shift
      [[ -z "$1" ]] && __print_error "Missing argument <version>" && exit $EC_MISSING_ARG
      _save_version "$1"
      exit $?
      ;;
    *)
      __print_error "Invalid argument $1" && exit $EC_INVALID_ARG
      ;;
  esac
  shift
done
