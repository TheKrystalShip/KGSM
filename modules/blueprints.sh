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

if [ "$#" -eq 0 ]; then usage && exit "$EC_MISSING_ARG"; fi

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
  source "$blueprint_path" || return "$EC_FAILED_SOURCE"

  jq -n \
    --arg name "$BP_NAME" \
    --arg port "$BP_PORT" \
    --arg app_id "$BP_APP_ID" \
    --arg steam_auth_level $BP_STEAM_AUTH_LEVEL \
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
      LevelName: $level_name,
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
    [[ -z "$1" ]] && _list_blueprints && exit $?
    case "$1" in
      --default)
        _list_default_blueprints; exit $?
        ;;
      --custom)
        _list_custom_blueprints; exit $?
        ;;
      --detailed)
        _list_detailed_blueprints; exit $?
        ;;
      *) __print_error "Invalid argument $1" && exit "$EC_INVALID_ARG"
    esac
    ;;
  --create)
    shift
    [[ -z "$1" ]] && __print_error "Missing arguments" >&2 && exit "$EC_MISSING_ARG"
    case "$1" in
    --name)
      shift
      [[ -z "$1" ]] && __print_error "Missing argument <name>" >&2 && exit "$EC_MISSING_ARG"
      _name="$1"
      ;;
    --port)
      shift
      [[ -z "$1" ]] && __print_error "Missing argument <port>" && exit "$EC_MISSING_ARG"
      _port="$1"
      ;;
    --app-id)
      shift
      [[ -z "$1" ]] && __print_error "Missing argument <app-id>" && exit "$EC_MISSING_ARG"
      _app_id="$1"
      ;;
    --steam-auth-level)
      shift
      [[ -z "$1" ]] && __print_error "Missing argument <steam-auth-level>" && exit "$EC_MISSING_ARG"
      _steam_auth_level="$1"
      ;;
    --launch-bin)
      shift
      [[ -z "$1" ]] && __print_error "Missing argument <launch-bin>" && exit "$EC_MISSING_ARG"
      _launch_bin="$1"
      ;;
    --level-name)
      shift
      [[ -z "$1" ]] && __print_error "Missing argument <level-name>" && exit "$EC_MISSING_ARG"
      _level_name="$1"
      ;;
    --install-subdirectory)
      shift
      [[ -z "$1" ]] && __print_error "Missing argument <install-subdirectory>" && exit "$EC_MISSING_ARG"
      _install_subdirectory="$1"
      ;;
    --launch-args)
      shift
      [[ -z "$1" ]] && __print_error "Missing argument <launch-args>" && exit "$EC_MISSING_ARG"
      _launch_args="$1"
      ;;
    --stop-command)
      shift
      [[ -z "$1" ]] && __print_error "Missing argument <stop-command>" && exit "$EC_MISSING_ARG"
      _stop_command="$1"
      ;;
    --save-command)
      shift
      [[ -z "$1" ]] && __print_error "Missing argument <save-command>" && exit "$EC_MISSING_ARG"
      _save_command="$1"
      ;;
    *)
      __print_error "Invalid argument $1" >&2 && exit "$EC_INVALID_ARG"
      ;;
    esac
    ;;
  --info)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <blueprint>" && exit "$EC_MISSING_ARG"
    blueprint=$1
    _print_blueprint "$blueprint"; exit $?
    ;;
  *)
    __print_error "Invalid argument $1" && exit "$EC_INVALID_ARG"
    ;;
  esac
  shift
done

[[ -z "$_name" ]] && __print_error "--name cannot be empty." >&2 && exit "$EC_MISSING_ARG"
[[ -z "$_port" ]] && __print_error "--port cannot be empty." >&2 && exit "$EC_MISSING_ARG"
[[ -z "$_launch_bin" ]] && __print_error "--launch-bin cannot be empty." >&2 && exit "$EC_MISSING_ARG"
[[ "$_steam_auth_level" == "1" ]] && [[ "$_app_id" == "0" ]] && __print_error "--app-id cannot be empty." >&2 && exit "$EC_MISSING_ARG"

# Output file path
BLUEPRINT_OUTPUT_FILE="$BLUEPRINTS_SOURCE_DIR/$_name.bp"

# Create blueprint from template file
if ! eval "cat <<EOF
$(<"$template_input_file")
EOF
" >"$BLUEPRINT_OUTPUT_FILE" 2>/dev/null; then
  __print_error "Failed to create $BLUEPRINT_OUTPUT_FILE" >&2 && exit "$EC_FAILED_TEMPLATE"
fi
