#!/usr/bin/env bash

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
if [[ -z "$KGSM_ROOT" ]]; then
  while [[ "$SELF_PATH" != "/" ]]; do
    [[ -f "$SELF_PATH/kgsm.sh" ]] && KGSM_ROOT="$SELF_PATH" && break
    SELF_PATH="$(dirname "$SELF_PATH")"
  done
  [[ -z "$KGSM_ROOT" ]] && echo "Error: Could not locate kgsm.sh. Ensure the directory structure is intact." && exit 1
  export KGSM_ROOT
fi

if [[ ! "$KGSM_COMMON_LOADED" ]]; then
  module_common="$(find "$KGSM_ROOT/modules" -type f -name common.sh -print -quit)"
  [[ -z "$module_common" ]] && echo "${0##*/} ERROR: Failed to load module common.sh" >&2 && exit 1
  # shellcheck disable=SC1090
  source "$module_common" || exit 1
fi

if [[ "$#" -eq 0 ]]; then
  usage
  exit $EC_MISSING_ARG
fi

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
  blueprint_path=$(__find_blueprint "$blueprint")

  if [[ -z "$json_format" ]]; then
    cat "$blueprint_path"
    return $?
  fi

  # shellcheck disable=SC1090
  __source_blueprint "$blueprint" || return $EC_FAILED_SOURCE

  jq -n \
    --arg name "$blueprint_name" \
    --arg ports "$blueprint_ports" \
    --arg steam_app_id "$blueprint_steam_app_id" \
    --arg is_steam_account_required $blueprint_is_steam_account_required \
    --arg executable_file "$blueprint_executable_file" \
    --arg level_name "$blueprint_level_name" \
    --arg executable_subdirectory "$blueprint_executable_subdirectory" \
    --arg executable_arguments "$blueprint_executable_arguments" \
    --arg stop_command "$blueprint_stop_command" \
    --arg save_command "$blueprint_save_command" \
    '{
      Name: $name,
      Ports: $ports,
      SteamAppId: $steam_app_id,
      IsSteamAccountRequired: $is_steam_account_required,
      ExecutableFile: $executable_file,
      LevelName: $level_name,
      ExecutableSubdirectory: $executable_subdirectory,
      ExecutableArguments: $executable_arguments,
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
      usage
      exit 0
      ;;
    --list)
      shift
      if [[ -z "$1" ]]; then
        _list_blueprints
        exit $?
      fi
      case "$1" in
        --default)
          _list_default_blueprints
          exit $?
          ;;
        --custom)
          _list_custom_blueprints
          exit $?
          ;;
        --detailed)
          _list_detailed_blueprints
          exit $?
          ;;
        *)
          __print_error "Invalid argument $1"
          exit $EC_INVALID_ARG
          ;;
      esac
      ;;
    --info)
      shift
      if [[ -z "$1" ]]; then
        __print_error "Missing argument <blueprint>"
        exit $EC_MISSING_ARG
      fi

      blueprint=$1
      _print_blueprint "$blueprint"
      exit $?
      ;;
    *)
      __print_error "Invalid argument $1"
      exit $EC_INVALID_ARG
      ;;
  esac
  shift
done

exit $?
