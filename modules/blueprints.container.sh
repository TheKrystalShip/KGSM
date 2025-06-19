#!/usr/bin/env bash

function usage() {
  local UNDERLINE="\e[4m"
  local END="\e[0m"

  echo -e "${UNDERLINE}Container Blueprint Management for Krystal Game Server Manager${END}

Provides tools to create, list, and manage containerized game server blueprints - the templates used to create server instances.

${UNDERLINE}Usage:${END}
  $(basename "$0") [OPTIONS]

${UNDERLINE}General Options:${END}
  -h, --help                    Display this help information

${UNDERLINE}Blueprint Listing & Information:${END}
  --list                        Display all available container blueprints
    --default                   Show only official default container blueprints
    --custom                    Show only user-created custom container blueprints
    --detailed --json           Output detailed blueprint information in JSON format
  --info <blueprint>            Display the contents of a specific container blueprint file
    --json                      Format the output as JSON
  --find <blueprint>            Locate the absolute path to a container blueprint file

${UNDERLINE}Examples:${END}
  $(basename "$0") --list
  $(basename "$0") --list --custom
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

function _list_custom_container_blueprints() {
  shopt -s extglob nullglob

  local -a custom_bps=("$BLUEPRINTS_CUSTOM_CONTAINER_SOURCE_DIR"/*)
  custom_bps=("${custom_bps[@]#"$BLUEPRINTS_CUSTOM_CONTAINER_SOURCE_DIR/"}")

  # Strip file extensions (.docker-compose.yml)
  local -a stripped_bps=()
  for bp in "${custom_bps[@]}"; do
    local base_name
    base_name="${bp%.docker-compose.yml}"
    stripped_bps+=("$base_name")
  done

  if [[ -z "$json_format" ]]; then
    printf "%s\n" "${stripped_bps[@]}"
  else
    jq -n --argjson blueprints "$(printf '%s\n' "${stripped_bps[@]}" | jq -R . | jq -s .)" '$blueprints'
  fi
}

function _list_default_container_blueprints() {
  shopt -s extglob nullglob

  local -a default_bps=("$BLUEPRINTS_DEFAULT_CONTAINER_SOURCE_DIR"/*)
  default_bps=("${default_bps[@]#"$BLUEPRINTS_DEFAULT_CONTAINER_SOURCE_DIR/"}")

  # Strip file extensions (.docker-compose.yml)
  local -a stripped_bps=()
  for bp in "${default_bps[@]}"; do
    local base_name
    base_name="${bp%.docker-compose.yml}"
    stripped_bps+=("$base_name")
  done

  if [[ -z "$json_format" ]]; then
    printf "%s\n" "${stripped_bps[@]}"
  else
    jq -n --argjson blueprints "$(printf '%s\n' "${stripped_bps[@]}" | jq -R . | jq -s .)" '$blueprints'
  fi
}

function _list_container_blueprints() {
  local previous_json_format=$json_format
  unset json_format

  # Combine both default and custom blueprints
  declare -a blueprint_list
  mapfile -t blueprint_list < <(_list_custom_container_blueprints; _list_default_container_blueprints)

  json_format=$previous_json_format

  # Remove duplicates and sort
  readarray -t blueprint_list < <(printf "%s\n" "${blueprint_list[@]}" | sort -du)

  if [[ -z "$json_format" ]]; then
    printf "%s\n" "${blueprint_list[@]}"
    return 0
  fi

  # Print contents as a JSON array of blueprint names
  jq -n --argjson blueprints "$(printf '%s\n' "${blueprint_list[@]}" | jq -R . | jq -s .)" '$blueprints'
}

function _list_detailed_container_blueprints() {
  local previous_json_format=$json_format
  unset json_format

  declare -a blueprint_list
  mapfile -t blueprint_list < <(_list_container_blueprints)

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
      content=$(_print_container_blueprint "$blueprint")
      # Skip blueprints with invalid content
      if [[ $? -ne 0 || -z "$content" ]]; then
        continue
      fi
      jq -n --arg key "$blueprint" --argjson value "$content" '{"key": $key, "value": $value}'
    done | jq -s 'from_entries')" '$blueprints'
}

function _print_container_blueprint() {
  local blueprint=$1

  local blueprint_path
  blueprint_path=$(__find_container_blueprint "$blueprint")

  if [[ -z "$json_format" ]]; then
    cat "$blueprint_path"
    return $?
  fi

  # For container blueprints, extract structured data from docker-compose.yml
  local name ports

  # Extract the blueprint name
  name="$blueprint"

  # Use the parser function to extract ports from docker-compose.yml
  ports=$(__parse_docker_compose_to_ufw_ports "$blueprint_path")

  # Return the same structure as native blueprints for consistency
  jq -n \
    --arg name "$name" \
    --arg ports "$ports" \
    '{
      Name: $name,
      Ports: $ports,
      BlueprintType: "Container",
      SteamAppId: "",
      IsSteamAccountRequired: "",
      ExecutableFile: "",
      LevelName: "",
      ExecutableSubdirectory: "",
      ExecutableArguments: "",
      StopCommand: "",
      SaveCommand: ""
    }'
}

function __find_container_blueprint() {
  local blueprint="$1"

  # First check custom blueprints
  local bp_path="$BLUEPRINTS_CUSTOM_CONTAINER_SOURCE_DIR/$blueprint.docker-compose.yml"
  [[ -f "$bp_path" ]] && echo "$bp_path" && return 0

  # Then check default blueprints
  bp_path="$BLUEPRINTS_DEFAULT_CONTAINER_SOURCE_DIR/$blueprint.docker-compose.yml"
  [[ -f "$bp_path" ]] && echo "$bp_path" && return 0

  return $EC_NOT_FOUND
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
      _list_container_blueprints
      exit $?
    fi
    case "$1" in
    --default)
      _list_default_container_blueprints
      exit $?
      ;;
    --custom)
      _list_custom_container_blueprints
      exit $?
      ;;
    --detailed)
      _list_detailed_container_blueprints
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
    _print_container_blueprint "$blueprint"
    exit $?
    ;;
  --find)
    shift
    if [[ -z "$1" ]]; then
      __print_error "Missing argument <blueprint>"
      exit $EC_MISSING_ARG
    fi

    blueprint=$1
    blueprint_path=$(__find_container_blueprint "$blueprint")
    if [[ -z "$blueprint_path" ]]; then
      __print_error "Container blueprint '$blueprint' not found"
      exit $EC_NOT_FOUND
    fi

    echo "$blueprint_path"
    exit 0
    ;;
  *)
    __print_error "Invalid argument $1"
    exit $EC_INVALID_ARG
    ;;
  esac
  shift
done

exit $?
