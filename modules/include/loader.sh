#!/usr/bin/env bash

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

# Blueprints (*.bp) are stored here
export BLUEPRINTS_SOURCE_DIR=$KGSM_ROOT/blueprints

# Default blueprints are stored here
export BLUEPRINTS_DEFAULT_SOURCE_DIR=$BLUEPRINTS_SOURCE_DIR/default

# Default native blueprints (*.bp) are stored here
export BLUEPRINTS_DEFAULT_NATIVE_SOURCE_DIR=$BLUEPRINTS_DEFAULT_SOURCE_DIR/native

# Default container blueprints (*.docker-compose.yml) are stored here
export BLUEPRINTS_DEFAULT_CONTAINER_SOURCE_DIR=$BLUEPRINTS_DEFAULT_SOURCE_DIR/container

# Custom blueprints are stored here
export BLUEPRINTS_CUSTOM_SOURCE_DIR=$BLUEPRINTS_SOURCE_DIR/custom

# Custom native blueprints (*.bp) are stored here
export BLUEPRINTS_CUSTOM_NATIVE_SOURCE_DIR=$BLUEPRINTS_CUSTOM_SOURCE_DIR/native

# Custom container blueprints (*.docker-compose.yml) are stored here
export BLUEPRINTS_CUSTOM_CONTAINER_SOURCE_DIR=$BLUEPRINTS_CUSTOM_SOURCE_DIR/container

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

# Locate files inside $KGSM_ROOT or a specified source directory, or
# print an error and exit with a specific error code if not found.
# Usage: __find_or_fail <file_name> [<source>]
function __find_or_fail() {
  local file_name=$1
  local source=${2:-$KGSM_ROOT}

  local file_path
  file_path="$(find "$source" \( -type f -o -type l \) -name "$file_name" -print -quit)"

  if [[ -z "$file_path" ]]; then
    __print_error "Could not find $file_name in $source"
    exit $EC_FILE_NOT_FOUND
  fi

  echo "$file_path"
}

export -f __find_or_fail

# Function to load native, default blueprints
function __find_default_native_blueprint() {
  local blueprint=$1
  [[ "$blueprint" != *.bp ]] && blueprint="${blueprint}.bp"
  __find_or_fail "$blueprint" "$BLUEPRINTS_DEFAULT_NATIVE_SOURCE_DIR"
}

export -f __find_default_native_blueprint

# Function to load container, default blueprints
function __find_default_container_blueprint() {
  local blueprint=$1
  [[ "$blueprint" != *.docker-compose.yml ]] && blueprint="${blueprint}.docker-compose.yml"
  __find_or_fail "$blueprint" "$BLUEPRINTS_DEFAULT_CONTAINER_SOURCE_DIR"
}

export -f __find_default_container_blueprint

# Function to load default blueprints, both native and container
function __find_default_blueprint() {
  local blueprint=$1

  # First try to find a native blueprint
  local loaded_blueprint
  loaded_blueprint=$(__find_default_native_blueprint "$blueprint")

  # If not found, try to find a container blueprint
  if [[ -z "$loaded_blueprint" ]]; then
    loaded_blueprint=$(__find_default_container_blueprint "$blueprint")
  fi

  # Don't print an error if no blueprint is found, just return empty
  echo "$loaded_blueprint"
}

export -f __find_default_blueprint

# Function to load native, custom blueprints
function __find_custom_native_blueprint() {
  local blueprint=$1
  [[ "$blueprint" != *.bp ]] && blueprint="${blueprint}.bp"
  __find_or_fail "$blueprint" "$BLUEPRINTS_CUSTOM_NATIVE_SOURCE_DIR"
}

export -f __find_custom_native_blueprint

# Function to load container, custom blueprints
function __find_custom_container_blueprint() {
  local blueprint=$1
  [[ "$blueprint" != *.docker-compose.yml ]] && blueprint="${blueprint}.docker-compose.yml"
  __find_or_fail "$blueprint" "$BLUEPRINTS_CUSTOM_CONTAINER_SOURCE_DIR"
}

export -f __find_custom_container_blueprint

# Function to load custom blueprints, both native and container
function __find_custom_blueprint() {
  local blueprint=$1

  # First try to find a custom native blueprint
  local loaded_blueprint
  loaded_blueprint=$(__find_custom_native_blueprint "$blueprint")

  # If not found, try to find a custom container blueprint
  if [[ -z "$loaded_blueprint" ]]; then
    loaded_blueprint=$(__find_custom_container_blueprint "$blueprint")
  fi

  # Don't print an error if no blueprint is found, just return empty
  echo "$loaded_blueprint"
}

export -f __find_custom_blueprint

# This function needs to look in both the native blueprints directory
# and the container blueprints directory and return the first match,
# or if there is a match in each directory, return the native one.
# It will return the absolute path to the blueprint file.
# Usage: __find_blueprint <blueprint_name>
# The blueprint name can be either an absolute path or just the name.
function __find_blueprint() {
  local blueprint=$1

  # $blueprint can be either an absolute path, or simply the blueprint name.
  # If it's an absolute path, we extract the name from it.
  if [[ "$blueprint" == /* ]]; then
    # If it's an absolute path, we just use the basename
    blueprint=$(basename "$blueprint")
  fi

  # Load the blueprint file in this order:
  # 1. Custom native blueprint
  # 2. Custom container blueprint
  # 3. Default native blueprint
  # 4. Default container blueprint

  # First try to find a custom blueprint
  local loaded_blueprint
  loaded_blueprint=$(__find_custom_blueprint "$blueprint" 2>/dev/null)

  # If no custom blueprint is found, try to find the default blueprint
  if [[ -z "$loaded_blueprint" ]]; then
    loaded_blueprint=$(__find_default_blueprint "$blueprint" 2>/dev/null)
  fi

  # If no blueprint is found, we return an error code
  if [[ -z "$loaded_blueprint" ]]; then
    return $EC_FILE_NOT_FOUND
  fi

  # If we found a blueprint, we return it
  echo "$loaded_blueprint"
}

export -f __find_blueprint

function __find_module() {
  local module=$1
  [[ "$module" != *.sh ]] && module="${module}.sh"
  __find_or_fail "$module" "$MODULES_SOURCE_DIR"
}

export -f __find_module

function __find_instance_config() {
  local instance=$1
  [[ "$instance" != *.ini ]] && instance="${instance}.ini"
  __find_or_fail "$instance" "$INSTANCES_SOURCE_DIR"
}

export -f __find_instance_config

function __find_template() {
  local template=$1
  [[ "$template" != *.tp ]] && template="${template}.tp"
  __find_or_fail "$template" "$TEMPLATES_SOURCE_DIR"
}

export -f __find_template

# Find the overrides file for a specific instance.
function __find_override() {
  local instance_name=$1

  if [[ -z "$instance_name" ]]; then
    __print_error "No 'instance_name' specified."
    exit $EC_INVALID_ARG
  fi

  # Locate the instance config file
  local instance_config_file
  instance_config_file=$(__find_instance_config "$instance_name")

  if [[ -z "$instance_config_file" ]]; then
    __print_error "Instance config file for '$instance_name' not found."
    exit $EC_FILE_NOT_FOUND
  fi

  # grep the instance blueprint file from the config
  local instance_blueprint_file
  instance_blueprint_file=$(grep -E '^blueprint_file\s*=' "$instance_config_file" | cut -d'=' -f2 | tr -d '"')

  if [[ -z "$instance_blueprint_file" ]]; then
    __print_error "No blueprint file specified for instance '$instance_name'."
    exit $EC_INVALID_ARG
  fi

  # $instance_blueprint_file is the absolute path to the blueprint file, we just need the name
  instance_bp_name=$(basename "$instance_blueprint_file" | sed 's/\.bp$//')

  instance_overrides_file="${instance_bp_name}.overrides.sh"

  __find_or_fail "$instance_overrides_file" "$OVERRIDES_SOURCE_DIR"
}

export -f __find_override

# This function sources a blueprint file and prefixes all variables with "blueprint_".
# It also checks if the blueprint file exists and is readable.
# If the blueprint file is not found, it returns an error.
# Usage: __source_blueprint <blueprint_file> [<prefix>] [--force-reload]
function __source_blueprint() {
  local blueprint_file="$1"
  local prefix="${2:-blueprint_}"
  local force_reload="$3"

  if [[ -z "$blueprint_file" ]]; then
    __print_error "No blueprint file specified."
    exit $EC_INVALID_ARG
  fi

  # Extract blueprint name for caching
  local blueprint_name
  if [[ "$blueprint_file" == /* ]]; then
    blueprint_name=$(basename "$blueprint_file")
  else
    blueprint_name="$blueprint_file"
  fi

  # Check if already cached and not forced to reload
  if [[ "$force_reload" != "--force-reload" ]] && __is_blueprint_cached "$blueprint_name"; then
    if ! __is_blueprint_stale "$blueprint_name"; then
      # Blueprint is fresh, skip loading
      return 0
    else
      # Blueprint is stale, clear cache and continue with fresh load
      __clear_blueprint_cache "$blueprint_name"
    fi
  fi

  # Use the __find_blueprint function to find the blueprint file.
  # This gives the absolute path to the blueprint file.
  local blueprint_absolute_path
  if ! blueprint_absolute_path=$(__find_blueprint "$blueprint_file"); then
    __print_error "Blueprint file '$blueprint_file' not found."
    exit $EC_FILE_NOT_FOUND
  fi

  # Check if the blueprint file is readable
  if [[ ! -r "$blueprint_absolute_path" ]]; then
    __print_error "Blueprint file '$blueprint_file' is not readable."
    exit $EC_PERMISSION
  fi

  # Clear any existing blueprint variables before loading (prevents variable pollution)
  if __is_blueprint_cached "$blueprint_name"; then
    __clear_blueprint_cache "$blueprint_name"
  fi

  # Prefix all the variables in the blueprint file with the specified prefix
  while IFS='=' read -r key value; do
    # Skip comments and empty lines
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    key="${key// /}" # Remove spaces
    value="${value## }"
    value="${value%% }"
    # Remove possible quotes
    value="${value%\"}"
    value="${value#\"}"
    value="${value%\'}"
    value="${value#\'}"
    declare -g "${prefix}${key}=${value}"
    export "${prefix}${key}"
  done < <(grep -v '^[[:space:]]*$' "$blueprint_absolute_path" | grep -v '^[[:space:]]*#')

  # Mark blueprint as cached for future use
  __mark_blueprint_cached "$blueprint_name" "$blueprint_absolute_path"
}

export -f __source_blueprint

# Source the instance config file for a specific instance with caching.
# This function expects the instance_name as the first argument.
# Usage: __source_instance <instance_name> [--force-reload]
# The instance ID can be either an absolute path or just the instance name.
function __source_instance() {
  local instance_name="$1"
  local force_reload="$2"

  if [[ -z "$instance_name" ]]; then
    __print_error "No 'instance_name' specified."
    exit $EC_INVALID_ARG
  fi

  # $instance_name can be either an absolute path, or simply the instance name.
  # If it's an absolute path, we extract the name from it.
  if [[ "$instance_name" == /* ]]; then
    # If it's an absolute path, we just use the basename
    instance_name=$(basename "$instance_name")
  fi

  # Check if already cached and not forced to reload
  if [[ "$force_reload" != "--force-reload" ]] && __is_instance_cached "$instance_name"; then
    # Locate the instance config file for staleness check
    local instance_config_file
    instance_config_file=$(__find_instance_config "$instance_name" 2>/dev/null)

    if [[ -n "$instance_config_file" ]] && ! __is_instance_config_stale "$instance_name" "$instance_config_file"; then
      # Config is fresh, skip loading
      return 0
    else
      # Config is stale or file not found, clear cache and continue with fresh load
      __clear_instance_cache "$instance_name"
    fi
  fi

  # Locate the instance config file
  local instance_config_file
  instance_config_file=$(__find_instance_config "$instance_name")

  if [[ -z "$instance_config_file" ]]; then
    __print_error "Instance config file for '$instance_name' not found."
    exit $EC_FILE_NOT_FOUND
  fi

  # Clear any existing instance variables before loading (prevents variable pollution)
  if __is_instance_cached "$instance_name"; then
    __clear_instance_cache "$instance_name"
  fi

  # Source the instance config file and prefix all variables with "instance_" if needed
  # This allows us to handle both formats (with and without the "instance_" prefix)
  while IFS='=' read -r key value || [ -n "$key" ]; do
    # Skip comments and empty lines
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue

    # Remove leading/trailing whitespace
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    # Remove quotes from value
    value="${value#\"}"
    value="${value%\"}"
    value="${value#\'}"
    value="${value%\'}"

    # Check if the key already starts with "instance_"
    if [[ "$key" =~ ^instance_ ]]; then
      # If it already has the prefix, set it in the current shell
      declare -g "${key}=${value}" && export "${key}"
    else
      # Otherwise, add the "instance_" prefix and set it in the current shell
      declare -g "instance_${key}=${value}" && export "instance_${key}"
    fi
  done < <(grep -v '^[[:space:]]*$' "$instance_config_file" | grep -v '^[[:space:]]*#')

  # Mark instance as cached for future use
  __mark_instance_cached "$instance_name" "$instance_config_file"
}

export -f __source_instance

# Get a single value from an instance config file without sourcing all variables
# Usage: __get_instance_config_value <instance_name> <config_key>
function __get_instance_config_value() {
  local instance_name="$1"
  local config_key="$2"

  if [[ -z "$instance_name" || -z "$config_key" ]]; then
    __print_error "Both instance_name and config_key must be specified."
    exit $EC_INVALID_ARG
  fi

  # Find the instance config file
  local instance_config_file
  instance_config_file=$(__find_instance_config "$instance_name")

  if [[ -z "$instance_config_file" ]]; then
    __print_error "Instance config file for '$instance_name' not found."
    exit $EC_FILE_NOT_FOUND
  fi

  # Extract the specific value using grep with proper anchoring
  local value
  value=$(grep -E "^${config_key}\s*=" "$instance_config_file" 2>/dev/null | cut -d'=' -f2 | tr -d '"' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || echo "")

  echo "$value"
}

export -f __get_instance_config_value

export KGSM_LOADER_LOADED=1
