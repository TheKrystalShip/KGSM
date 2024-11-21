#!/bin/bash

# Check for KGSM_ROOT env variable
if [ -z "$KGSM_ROOT" ]; then
  echo "${0##*/} WARNING: KGSM_ROOT not found, sourcing /etc/environment." >&2
  # shellcheck disable=SC1091
  source /etc/environment
  if [ -z "$KGSM_ROOT" ]; then
    echo "${0##*/} ERROR: KGSM_ROOT not found, exiting." >&2 && exit 1
  else
    echo "${0##*/} INFO: KGSM_ROOT found in /etc/environment, consider rebooting the system" >&2
    if ! declare -p KGSM_ROOT | grep -q 'declare -x'; then export KGSM_ROOT; fi
  fi
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
  [[ -z "$file_path" ]] && __print_error "Could not find $file_name" && return 1

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
source "$(__load_module events.sh)" || exit 1

if [[ "$USE_EVENTS" == 0 ]]; then
    # List all functions defined in the current environment (from events.sh) and extract function names
    declare -F | grep -E '^declare -f __emit_' | sed 's/^declare -f //g' | while read func; do
        # For each function name, create a no-op function definition
        eval "$func() { return; }"
    done
fi
