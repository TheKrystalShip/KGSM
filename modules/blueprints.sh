#!/bin/bash

function usage() {
  echo "Creates a new blueprint

Usage:
    ./${0##*/} --name <name> --port <port> [options]

Options:
  -h, --help                    Prints this message.

  --list                        Returns a list of all blueprints.
    --default                   Returns a list of only the default blueprints.
    --custom                    Returns a list of only the custom blueprints.

  --create
    --name <name>               Name of the blueprint.

    --port <port>               Port number(s) in UFW format.
                                Example:
                                  \"16261:16262/tcp|16261:16262/udp\"

    --launch-bin <launch-bin>   Name of the file used to start the service.

    --level-name <name>         Name of the savefile, world, level, whichever is
                                applicable for the game server.

    --app-id <app-id>           (Optional) Steam APP ID if applicable.
                                Default: 0

    --steam-auth-level <x>      (Optional) Used to determine if a game server
                                requires a Steam account in order to download
                                or if an annonymous user can be used.
                                Possible values:
                                  0 - Annonymous user can be used
                                  1 - Requires Steam account
                                Default: 0

    --install-subdirectory <x>  (Optional) If the <launch-bin> is not located in
                                the root folder of the game server, specify the
                                subdirectories required to reach it.
                                Relative path to the game server install
                                directory.
                                Default: Empty

    --launch-args <launch-args> (Optional) Arguments used when starting the
                                server
                                Default: Empty

    --stop-command <command>    (Optional) If the server accepts commands, this
                                one will be used to stop the server gracefully.
                                Default: Empty

    --save-command <command>    (Optional) If the server accepts command, this
                                will be used to issue a save command to the
                                server. It will also be used before
                                --stop-command when shutting down the server.
                                Default: Empty

Examples:
  ./${0##*/} --create --name terraria --port 7777 --launch-bin TerrariaServer.bin.x86_64 --stop-command \"exit\"
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

COMMON_SCRIPT="$(find "$KGSM_ROOT" -type f -name common.sh)"
[[ -z "$COMMON_SCRIPT" ]] && echo "${0##*/} ERROR: Failed to load module common.sh" >&2 && exit 1

TEMPLATE_INPUT_FILE="$(find "$KGSM_ROOT" -type f -name blueprint.tp)"
[[ -z "$TEMPLATE_INPUT_FILE" ]] && echo "${0##*/} ERROR: Failed to load template blueprint.tp" >&2 && exit 1

# shellcheck disable=SC1090
source "$COMMON_SCRIPT" || exit 1

_name=""
_port=""
_app_id="0"
_steam_auth_level="0"
_launch_bin=""
_level_name=""
_install_subdirectory=""
_launch_args=""
_stop_command=""
_save_command=""

function _list_custom_blueprints() {
  shopt -s extglob nullglob

  local -a custom_bps=("$BLUEPRINTS_SOURCE_DIR"/*.bp)
  custom_bps=("${custom_bps[@]#"$BLUEPRINTS_SOURCE_DIR/"}")

  printf "%s\n" "${custom_bps[@]}"
}

function _list_default_blueprints() {
  shopt -s extglob nullglob

  local -a default_bps=("$BLUEPRINTS_DEFAULT_SOURCE_DIR"/*.bp)
  default_bps=("${default_bps[@]#"$BLUEPRINTS_DEFAULT_SOURCE_DIR/"}")

  printf "%s\n" "${default_bps[@]}"
}

function _list_blueprints() {
  for B in $(_list_custom_blueprints) $(_list_default_blueprints); do echo "$B"; done | sort -du
}

while [ $# -gt 0 ]; do
  case "$1" in
  -h | --help)
    usage && exit 0
    ;;
  --list)
    shift
    [[ -z "$1" ]] && _list_blueprints && exit 0
    case "$1" in
      --default)
        _list_default_blueprints && exit 0
        ;;
      --custom)
        _list_custom_blueprints && exit 0
        ;;
      *) echo "${0##*/} ERROR: Unknown argument $1" >&2 && exit 1
    esac
    ;;
  --create)
    shift
    [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing arguments" >&2 && exit 1
    case "$1" in
    --name)
      shift
      [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument <name>" >&2 && exit 1
      _name="$1"
      ;;
    --port)
      shift
      [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument <port>" >&2 && exit 1
      _port="$1"
      ;;
    --app-id)
      shift
      [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument <app-id>" >&2 && exit 1
      _app_id="$1"
      ;;
    --steam-auth-level)
      shift
      [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument <steam-auth-level>" >&2 && exit 1
      _steam_auth_level="$1"
      ;;
    --launch-bin)
      shift
      [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument <launch-bin>" >&2 && exit 1
      _launch_bin="$1"
      ;;
    --level-name)
      shift
      [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument <level-name>" >&2 && exit 1
      _level_name="$1"
      ;;
    --install-subdirectory)
      shift
      [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument <install-subdirectory>" >&2 && exit 1
      _install_subdirectory="$1"
      ;;
    --launch-args)
      shift
      [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument <launch-args>" >&2 && exit 1
      _launch_args="$1"
      ;;
    --stop-command)
      shift
      [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument <stop-command>" >&2 && exit 1
      _stop_command="$1"
      ;;
    --save-command)
      shift
      [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument <save-command>" >&2 && exit 1
      _save_command="$1"
      ;;
    *)
      echo "${0##*/} ERROR: Invalid argument $1" >&2 && exit 1
      ;;
    esac
    ;;
  *)
    echo "${0##*/} ERROR: Invalid argument $1" >&2 && exit 1
    ;;
  esac
  shift
done

[[ -z "$_name" ]] && echo "${0##*/} ERROR: --name cannot be empty." >&2 && exit 1
[[ -z "$_port" ]] && echo "${0##*/} ERROR: --port cannot be empty." >&2 && exit 1
[[ -z "$_launch_bin" ]] && echo "${0##*/} ERROR: --launch-bin cannot be empty." >&2 && exit 1
[[ "$_steam_auth_level" == "1" ]] && [[ "$_app_id" == "0" ]] && echo "${0##*/} ERROR: --app-id cannot be empty." >&2 && exit 1

# Output file path
BLUEPRINT_OUTPUT_FILE="$BLUEPRINTS_SOURCE_DIR/$_name.bp"

# Create blueprint from template file
if ! eval "cat <<EOF
$(<"$TEMPLATE_INPUT_FILE")
EOF
" >"$BLUEPRINT_OUTPUT_FILE" 2>/dev/null; then
  echo "${0##*/} ERROR: Failed to create $BLUEPRINT_OUTPUT_FILE" >&2
fi
