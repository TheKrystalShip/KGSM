#!/bin/bash

function __enable_error_checking() {
  set -o pipefail
}

function __disable_error_checking() {
  set +o pipefail
}

# Exit codes
EC_OKAY=0
EC_GENERAL=1
EC_KGSM_ROOT=2
EC_FAILED_CONFIG=3
EC_INVALID_CONFIG=4
EC_FILE_NOT_FOUND=5
EC_FAILED_SOURCE=6
EC_MISSING_ARG=7
EC_INVALID_ARG=8
EC_FAILED_CD=9
EC_FAILED_CP=10
EC_FAILED_RM=11
EC_FAILED_TEMPLATE=12
EC_FAILED_DOWNLOAD=13
EC_FAILED_DEPLOY=14
EC_FAILED_MKDIR=15
EC_PERMISSION=16
EC_FAILED_SED=17
EC_SYSTEMD=18
EC_UFW=19
EC_MALFORMED_INSTANCE=20
EC_MISSING_DEPENDENCY=21

declare -A EXIT_CODES=(
  [$EC_OKAY]="No error"
  [$EC_GENERAL]="General error"
  [$EC_KGSM_ROOT]="KGSM_ROOT not set"
  [$EC_FAILED_CONFIG]="Failed to load config.ini file"
  [$EC_INVALID_CONFIG]="Invalid configuration"
  [$EC_FILE_NOT_FOUND]="File not found"
  [$EC_FAILED_SOURCE]="Failed to source file"
  [$EC_MISSING_ARG]="Missing argument"
  [$EC_INVALID_ARG]="Invalid argument"
  [$EC_FAILED_CD]="Failed to move into directory"
  [$EC_FAILED_CP]="Failed to copy"
  [$EC_FAILED_RM]="Failed to remove"
  [$EC_FAILED_TEMPLATE]="Failed to generate template"
  [$EC_FAILED_DOWNLOAD]="Failed to download"
  [$EC_FAILED_DEPLOY]="Failed to deploy"
  [$EC_FAILED_MKDIR]="Failed mkdir"
  [$EC_PERMISSION]="Permission issue"
  [$EC_FAILED_SED]="Error with 'sed' command"
  [$EC_SYSTEMD]="Error with 'systemctl' command"
  [$EC_UFW]="Error with 'ufw' command"
  [$EC_MALFORMED_INSTANCE]="Malformed instance config file"
  [$EC_MISSING_DEPENDENCY]="Missing required dependency"
)

function __print_error_code() {
  local code=$1
  local script="${BASH_SOURCE[1]}"  # The script where the error occurred
  local func="${FUNCNAME[1]}"       # The function where the error occurred
  local line="${BASH_LINENO[0]}"    # The line number where the error occurred

  echo "Error $code: ${EXIT_CODES[$code]:-Unknown error}" >&2
  echo "Occurred in script: $script, function: $func, line: $line" >&2
}

trap '__print_error_code $?; exit $?' ERR

__enable_error_checking

# Check for KGSM_ROOT
# Its must be set by any script that sources this one
if [ -z "$KGSM_ROOT" ]; then
  echo "Error: KGSM_ROOT is not set" && exit "$EC_KGSM_ROOT"
fi

# Read configuration file
if [ -z "$KGSM_CONFIG_LOADED" ]; then
  CONFIG_FILE="$(find "$KGSM_ROOT" -type f -name config.ini -print -quit)"
  [[ -z "$CONFIG_FILE" ]] && echo "${0##*/} ERROR: Failed to load config.ini file" >&2 && exit "$EC_FAILED_CONFIG"
  while IFS= read -r line || [ -n "$line" ]; do
    # Ignore comment lines and empty lines
    if [[ "$line" =~ ^#.*$ ]] || [[ -z "$line" ]]; then continue; fi
    export "${line?}"
  done <"$CONFIG_FILE"
  export KGSM_CONFIG_LOADED=1
fi

# Blueprints (*.bp) are stored here
export BLUEPRINTS_SOURCE_DIR=$KGSM_ROOT/blueprints

# Default blueprints (*.bp) are stored here
export BLUEPRINTS_DEFAULT_SOURCE_DIR=$BLUEPRINTS_SOURCE_DIR/default

# Specific game server overrides ([service].overrides.sh) are stored here
export OVERRIDES_SOURCE_DIR=$KGSM_ROOT/overrides

# Templates (*.tp) are stored here
export TEMPLATES_SOURCE_DIR=$KGSM_ROOT/templates

# All other scripts (*.sh) are stored here
export MODULES_SOURCE_DIR=$KGSM_ROOT/modules

# "Library" scripts are stored here
export MODULES_INCLUDE_SOURCE_DIR=$MODULES_SOURCE_DIR/include

# Directory where instances and their config is stored
export INSTANCES_SOURCE_DIR=$KGSM_ROOT/instances

## Colored output
# Check if stdout is tty
if test -t 1; then
  ncolors=0

  # Check for availability of tput
  if command -v tput >/dev/null 2>&1; then
    ncolors="$(tput colors)"
  fi

  # More than 8 means it supports colors
  if [[ $ncolors ]] && [[ "$ncolors" -gt 8 ]]; then

    export COLOR_RED="\033[0;31m"
    export COLOR_GREEN="\033[0;32m"
    export COLOR_ORANGE="\033[0;33m"
    export COLOR_BLUE="\033[0;34m"
    export COLOR_END="\033[0m"

  fi
fi

function __print_error() {
  echo -e "[${BASH_SOURCE[-1]##*/}:${BASH_LINENO[0]} - ${COLOR_RED}ERROR${COLOR_END}] $1" >&2
}

export -f __print_error

function __print_success() {
  echo -e "[${BASH_SOURCE[-1]##*/}:${BASH_LINENO[0]} - ${COLOR_GREEN}SUCCESS${COLOR_END}] $1"
}

export -f __print_success

function __print_warning() {
  echo -e "[${BASH_SOURCE[-1]##*/}:${BASH_LINENO[0]} - ${COLOR_ORANGE}WARNING${COLOR_END}] $1" >&2
}

export -f __print_warning

function __print_info() {
  echo -e "[${BASH_SOURCE[-1]##*/}:${BASH_LINENO[0]} - ${COLOR_BLUE}INFO${COLOR_END}] $1"
}

export -f __print_info

function __find_or_fail() {
  local file_name=$1
  local source=${2:-$KGSM_ROOT}

  local file_path
  file_path="$(find "$source" -type f -name "$file_name" -print -quit)"
  [[ -z "$file_path" ]] && __print_error "Could not find $file_name" && return $EC_FILE_NOT_FOUND

  echo "$file_path"
}

export -f __find_or_fail

function __load_blueprint() {
  local blueprint=$1
  [[ "$blueprint" != *.bp ]] && blueprint="${blueprint}.bp"
  __find_or_fail "$blueprint" "$BLUEPRINTS_SOURCE_DIR"
}

export -f __load_blueprint

function __load_module() {
  local module=$1
  [[ "$module" != *.sh ]] && module="${module}.sh"
  __find_or_fail "$module" "$MODULES_SOURCE_DIR"
}

export -f __load_module

function __load_instance() {
  local instance=$1
  [[ "$instance" != *.ini ]] && instance="${instance}.ini"
  __find_or_fail "$instance" "$INSTANCES_SOURCE_DIR"
}

export -f __load_instance

function __load_template() {
  local template=$1
  [[ "$template" != *.tp ]] && template="${template}.tp"
  __find_or_fail "$template" "$TEMPLATES_SOURCE_DIR"
}

export -f __load_template

# Events
# shellcheck disable=SC1090
source "$(__load_module events.sh)" || exit $EC_FAILED_SOURCE

if [[ "$USE_EVENTS" == 0 ]]; then
  # List all functions defined in the current environment (from events.sh) and extract function names
  declare -F | \
    grep -E '^declare -f __emit_' | \
    sed 's/^declare -f //g' | \
    while read -r func; do
      # For each function name, create a no-op function definition
      eval "$func() { return; }"
    done
fi
