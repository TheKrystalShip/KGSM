#!/bin/bash

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

instance_config_file=$(__load_instance "$instance")
# shellcheck disable=SC1090
source "$instance_config_file" || exit 1

# https://github.com/ValveSoftware/steam-for-linux/issues/10975
function func_get_latest_version() {

  app_id="$(grep "BP_APP_ID=" <"$INSTANCE_BLUEPRINT_FILE" | cut -d '=' -f2 | tr -d '"')"
  {
    [[ -z "$app_id" ]] || [[ "$app_id" -eq 0 ]];
  } && echo "${0##*/} ERROR: APP_ID is expected but it's not set" >&2 && return 1

  username=anonymous
  auth_level="$(grep "BP_STEAM_AUTH_LEVEL=" <"$INSTANCE_BLUEPRINT_FILE" | cut -d '=' -f2 | tr -d '"')"
  if [[ $auth_level -ne 0 ]]; then
    [[ -z "$STEAM_USERNAME" ]] && echo "${0##*/} ERROR: STEAM_USERNAME is expected but it's not set" >&2 && return 1
    [[ -z "$STEAM_PASSWORD" ]] && echo "${0##*/} ERROR: STEAM_PASSWORD is expected but it's not set" >&2 && return 1

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

  [[ -z "$latest_version" ]] && return 1
  echo "$latest_version"
}

function _compare() {
  [[ -z "$INSTANCE_INSTALLED_VERSION" ]] && echo "${0##*/} ERROR: $instance is missing INSTANCE_INSTALLED_VERSION varible" >&2 && return 1

  local latest_version
  latest_version=$(func_get_latest_version)

  [[ -z "$latest_version" ]] && return 1
  [[ "$latest_version" == "$INSTANCE_INSTALLED_VERSION" ]] && return 1

  echo "$latest_version"
}

function _save_version() {
  local version=$1

  if grep -q "INSTANCE_INSTALLED_VERSION=" <"$instance_config_file"; then
    sed -i "/INSTANCE_INSTALLED_VERSION=*/c\INSTANCE_INSTALLED_VERSION=$version" "$instance_config_file" >/dev/null
  else
    {
      echo ""
      echo "# Installed version"
      echo "INSTANCE_INSTALLED_VERSION=$version"
    } >>"$instance_config_file"
  fi

  echo "$version" >"${INSTANCE_WORKING_DIR}/${INSTANCE_FULL_NAME}.version"

  return 0
}

# shellcheck disable=SC1090
source "$module_overrides" "$instance"

# Read the argument values
while [[ "$#" -gt 0 ]]; do
  case $1 in
  --compare)
    _compare; exit $?
    ;;
  --installed)
    echo "$INSTANCE_INSTALLED_VERSION" && exit 0
    ;;
  --latest)
    func_get_latest_version; exit $?
    ;;
  --save)
    shift
    [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument <version>" >&2 && exit 1
    _save_version "$1"; exit $?
    ;;
  *)
    echo "${0##*/} ERROR: Invalid argument $1" >&2 && exit 1
    ;;
  esac
  shift
done
