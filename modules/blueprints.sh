#!/bin/bash

function usage() {
  echo "Provides information about blueprints and creates new ones.

Usage:
  $(basename "$0") OPTION

Options:
  -h, --help                    Prints this message.
  --list                        Returns a list of all blueprints.
    --default                   Returns a list of only the default blueprints.
    --custom                    Returns a list of only the custom blueprints.
    --detailed --json           Print a json map with each blueprint and their
                                content.
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
    --info <blueprint>          Print the contents of a blueprint file.
    --info <blueprint> --json   Print the contents of a blueprint in JSON format

Examples:
  $(basename "$0") --list
  $(basename "$0") --list --custom
  $(basename "$0") --create --name terraria --port 7777 --launch-bin TerrariaServer.bin.x86_64 --stop-command \"exit\"
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
  CONFIG_FILE="$(find "$KGSM_ROOT" -type f -name config.ini -print -quit)"
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

module_common="$(find "$KGSM_ROOT" -type f -name common.sh -print -quit)"
[[ -z "$module_common" ]] && echo "${0##*/} ERROR: Failed to load module common.sh" >&2 && exit 1

# shellcheck disable=SC1090
source "$module_common" || exit 1

template_input_file=$(__load_template blueprint.tp)

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

function __get_blueprint_list() {
  for B in $(_list_custom_blueprints) $(_list_default_blueprints); do echo "$B"; done | sort -du
}

function _list_custom_blueprints() {
  shopt -s extglob nullglob

  local -a custom_bps=("$BLUEPRINTS_SOURCE_DIR"/*.bp)
  custom_bps=("${custom_bps[@]#"$BLUEPRINTS_SOURCE_DIR/"}")

  if [[ -z "$json_format" ]]; then
    printf "%s\n" "${custom_bps[@]}"
  else
    jq -n --argjson blueprints "$(printf '%s\n' "${custom_bps[@]}" | jq -R . | jq -s .)" '$blueprints'
  fi
}

function _list_default_blueprints() {
  shopt -s extglob nullglob

  local -a default_bps=("$BLUEPRINTS_DEFAULT_SOURCE_DIR"/*.bp)
  default_bps=("${default_bps[@]#"$BLUEPRINTS_DEFAULT_SOURCE_DIR/"}")

  if [[ -z "$json_format" ]]; then
    printf "%s\n" "${default_bps[@]}"
  else
    jq -n --argjson blueprints "$(printf '%s\n' "${default_bps[@]}" | jq -R . | jq -s .)" '$blueprints'
  fi
}

function _list_blueprints() {
  local previous_json_format=$json_format
  unset json_format
  declare -a blueprint_list=($(__get_blueprint_list))
  json_format=$previous_json_format

  if [[ -z "$json_format" ]]; then
    printf "%s\n" "${blueprint_list[@]}"
    return 0
  fi

  # Print contents as a JSON array of blueprint names
  jq -n --argjson blueprints "$(printf '%s\n' "${blueprint_list[@]}" | jq -R . | jq -s .)" '$blueprints'
}

function _list_detailed_blueprints() {

  local previous_json_format=$json_format
  unset json_format
  declare -a blueprint_list=($(__get_blueprint_list))
  json_format=$previous_json_format

  if [[ -z "$json_format" ]]; then
    printf "%s\n" "${blueprint_list[@]}"
    return 0
  fi

  # Build a JSON object with blueprint contents
  jq -n --argjson blueprints \
    "$(for blueprint in "${blueprint_list[@]}"; do
      # Get the content of the blueprint as JSON
      local content
      content=$(_print_blueprint "$blueprint")
      # Skip blueprints with invalid content
      if [[ $? -ne 0 || -z "$content" ]]; then
        continue
      fi
      jq -n --arg key "$blueprint" --argjson value "$content" '{"key": $key, "value": $value}'
    done | jq -s 'from_entries')" '$blueprints'
}

function _print_blueprint() {
  local blueprint=$1

  local blueprint_path
  blueprint_path=$(__load_blueprint "$blueprint")

  if [[ -z "$json_format" ]]; then
    cat "$blueprint_path"; return $?
  fi

  # shellcheck disable=SC1090
  source "$blueprint_path" || return 1

  jq -n \
    --arg name "$BP_NAME" \
    --arg port "$BP_PORT" \
    --arg app_id "$BP_APP_ID" \
    --arg steam_auth_level "$BP_STEAM_AUTH_LEVEL" \
    --arg launch_bin "$BP_LAUNCH_BIN" \
    --arg level_name "$BP_LEVEL_NAME" \
    --arg install_subdirectory "$BP_INSTALL_SUBDIRECTORY" \
    --arg launch_args "$BP_LAUNCH_ARGS" \
    --arg stop_command "$BP_STOP_COMMAND" \
    --arg save_command "$BP_SAVE_COMMAND" \
    '{
      Name: $name,
      Port: $port,
      AppId: $app_id,
      SteamAccountRequired: $steam_auth_level,
      LaunchBin: $launch_bin,
      InstallSubdirectory: $install_subdirectory,
      LaunchArgs: $launch_args,
      StopCommand: $stop_command,
      SaveCommand: $save_command
    }'
}

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
      --detailed)
        _list_detailed_blueprints && exit 0
        ;;
      *) __print_error "Unknown argument $1" && exit 1
    esac
    ;;
  --create)
    shift
    [[ -z "$1" ]] && __print_error "Missing arguments" >&2 && exit 1
    case "$1" in
    --name)
      shift
      [[ -z "$1" ]] && __print_error "Missing argument <name>" >&2 && exit 1
      _name="$1"
      ;;
    --port)
      shift
      [[ -z "$1" ]] && __print_error "Missing argument <port>" && exit 1
      _port="$1"
      ;;
    --app-id)
      shift
      [[ -z "$1" ]] && __print_error "Missing argument <app-id>" && exit 1
      _app_id="$1"
      ;;
    --steam-auth-level)
      shift
      [[ -z "$1" ]] && __print_error "Missing argument <steam-auth-level>" && exit 1
      _steam_auth_level="$1"
      ;;
    --launch-bin)
      shift
      [[ -z "$1" ]] && __print_error "Missing argument <launch-bin>" && exit 1
      _launch_bin="$1"
      ;;
    --level-name)
      shift
      [[ -z "$1" ]] && __print_error "Missing argument <level-name>" && exit 1
      _level_name="$1"
      ;;
    --install-subdirectory)
      shift
      [[ -z "$1" ]] && __print_error "Missing argument <install-subdirectory>" && exit 1
      _install_subdirectory="$1"
      ;;
    --launch-args)
      shift
      [[ -z "$1" ]] && __print_error "Missing argument <launch-args>" && exit 1
      _launch_args="$1"
      ;;
    --stop-command)
      shift
      [[ -z "$1" ]] && __print_error "Missing argument <stop-command>" && exit 1
      _stop_command="$1"
      ;;
    --save-command)
      shift
      [[ -z "$1" ]] && __print_error "Missing argument <save-command>" && exit 1
      _save_command="$1"
      ;;
    *)
      __print_error "Invalid argument $1" >&2 && exit 1
      ;;
    esac
    ;;
  --info)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <blueprint>" && exit 1
    blueprint=$1
    _print_blueprint "$blueprint"; exit $?
    ;;
  *)
    __print_error "Invalid argument $1" && exit 1
    ;;
  esac
  shift
done

[[ -z "$_name" ]] && __print_error "--name cannot be empty." >&2 && exit 1
[[ -z "$_port" ]] && __print_error "--port cannot be empty." >&2 && exit 1
[[ -z "$_launch_bin" ]] && __print_error "--launch-bin cannot be empty." >&2 && exit 1
[[ "$_steam_auth_level" == "1" ]] && [[ "$_app_id" == "0" ]] && __print_error "--app-id cannot be empty." >&2 && exit 1

# Output file path
BLUEPRINT_OUTPUT_FILE="$BLUEPRINTS_SOURCE_DIR/$_name.bp"

# Create blueprint from template file
if ! eval "cat <<EOF
$(<"$template_input_file")
EOF
" >"$BLUEPRINT_OUTPUT_FILE" 2>/dev/null; then
  __print_error "Failed to create $BLUEPRINT_OUTPUT_FILE" >&2
fi
