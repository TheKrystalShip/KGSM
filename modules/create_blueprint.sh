#!/bin/bash

function usage() {
  echo "Creates a new blueprint

Usage:
    ./${0##*/} --name <name> --port <port> [options]

Options:
    -h --help                   Prints this message.

    --name <name>               Name of the blueprint. It will also be used as the name of the service.

    --port <port>               Port number(s) in UFW format.
                                Example:
                                  \"16261:16262/tcp|16261:16262/udp\"

    --launch-bin <launch-bin>   Name of the file used to start the service.

    --app-id <app-id>           (Optional) Steam APP ID if applicable.
                                Default: 0

    --steam-auth-level <x>      (Optional) Used to determine if a game server requires a Steam account in order
                                to download or if an annonymous user can be used.
                                Possible values:
                                  0 - Annonymous user can be used
                                  1 - Requires Steam account
                                Default: 0

    --install-subdirectory <x>  (Optional) If the <launch-bin> is not located in the root folder of the game
                                server, specify the subdirectories required to reach it.
                                Relative path to the game server install directory.
                                Default: Empty

    --launch-args <launch-args> (Optional) Arguments used when starting the server
                                Default: Empty

    --stop-command <command>    (Optional) If the server accepts commands, this one will be used to stop
                                the server gracefully
                                Default: Empty

    --save-command <command>    (Optional) If the server accepts command, this will be used to issue a
                                save command to the server. It will also be used before --stop-command
                                when shutting down the server.
                                Default: Empty

Examples:
    ./${0##*/} --name terraria --port 7777 --launch-bin TerrariaServer.bin.x86_64 --stop-command \"exit\"
"
}

set -eo pipefail

# shellcheck disable=SC2199
if [[ $@ =~ "--debug" ]]; then
  export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
  set -x
fi

# Check for KGSM_ROOT env variable
if [ -z "$KGSM_ROOT" ]; then
  echo "WARNING: KGSM_ROOT not found, sourcing /etc/environment." >&2
  # shellcheck disable=SC1091
  source /etc/environment

  # If not found in /etc/environment
  if [ -z "$KGSM_ROOT" ]; then
    echo "ERROR: KGSM_ROOT not found, exiting." >&2
    exit 1
  else
    echo "INFO: KGSM_ROOT found in /etc/environment, consider rebooting the system" >&2

    # Check if KGSM_ROOT is exported
    if ! declare -p KGSM_ROOT | grep -q 'declare -x'; then
      export KGSM_ROOT
    fi
  fi
fi

# Trap CTRL-C
trap "echo "" && exit" INT

COMMON_SCRIPT="$(find "$KGSM_ROOT" -type f -name common.sh)"
TEMPLATE_INPUT_FILE="$(find "$KGSM_ROOT" -type f -name blueprint.tp)"

# shellcheck disable=SC1090
source "$COMMON_SCRIPT" || exit 1

_name=""
_port=""
_app_id="0"
_steam_auth_level="0"
_launch_bin=""
_install_subdirectory=""
_launch_args=""
_stop_command=""
_save_command=""

while [ $# -gt 0 ]; do
  case "$1" in
  -h | --help)
    usage && exit 0
    ;;
  --name)
    shift
    [[ -z "$1" ]] && echo "ERROR: Missing argument <name>" >&2 && exit 1
    _name="$1"
    ;;
  --port)
    shift
    [[ -z "$1" ]] && echo "ERROR: Missing argument <port>" >&2 && exit 1
    _port="$1"
    ;;
  --app-id)
    shift
    [[ -z "$1" ]] && echo "ERROR: Missing argument <app-id>" >&2 && exit 1
    _app_id="$1"
    ;;
  --steam-auth-level)
    shift
    [[ -z "$1" ]] && echo "ERROR: Missing argument <steam-auth-level>" >&2 && exit 1
    _steam_auth_level="$1"
    ;;
  --launch-bin)
    shift
    [[ -z "$1" ]] && echo "ERROR: Missing argument <launch-bin>" >&2 && exit 1
    _launch_bin="$1"
    ;;
  --install-subdirectory)
    shift
    [[ -z "$1" ]] && echo "ERROR: Missing argument <install-subdirectory>" >&2 && exit 1
    _install_subdirectory="$1"
    ;;
  --launch-args)
    shift
    [[ -z "$1" ]] && echo "ERROR: Missing argument <launch-args>" >&2 && exit 1
    _launch_args="$1"
    ;;
  --stop-command)
    shift
    [[ -z "$1" ]] && echo "ERROR: Missing argument <stop-command>" >&2 && exit 1
    _stop_command="$1"
    ;;
  --save-command)
    shift
    [[ -z "$1" ]] && echo "ERROR: Missing argument <save-command>" >&2 && exit 1
    _save_command="$1"
    ;;
  *)
    echo "ERROR: Invalid argument $1" >&2
    usage && exit 1
    ;;
  esac
  shift
done

if [ -z "$_name" ]; then
  echo "ERROR: --name cannot be empty.
  Use \"--help\" to see available parameters." >&2
  exit 1
fi

if [ -z "$_port" ]; then
  echo "ERROR: --port cannot be empty.
  Use \"--help\" to see available parameters." >&2
  exit 1
fi

if [ -z "$_launch_bin" ]; then
  echo "ERROR: --launch-bin cannot be empty.
  Use \"--help\" to see available parameters." >&2
  exit 1
fi

if [ "$_steam_auth_level" == "1" ] && [ "$_app_id" == "0" ]; then
  echo "ERROR: --app-id cannot be empty.
  Use \"--help\" to see available parameters." >&2
  exit 1
fi

# Output file path
BLUEPRINT_OUTPUT_FILE="$BLUEPRINTS_SOURCE_DIR/$_name.bp"

# Create blueprint from template file
if ! eval "cat <<EOF
$(<"$TEMPLATE_INPUT_FILE")
EOF
" >"$BLUEPRINT_OUTPUT_FILE" 2>/dev/null; then
  echo "ERROR: Failed to create $BLUEPRINT_OUTPUT_FILE" >&2
fi
