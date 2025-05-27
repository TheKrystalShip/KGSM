#!/usr/bin/env bash

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

export KGSM_LOADER_LOADED=1
