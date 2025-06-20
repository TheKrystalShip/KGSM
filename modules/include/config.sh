#!/usr/bin/env bash

# Check for KGSM_ROOT
if [[ -z "$KGSM_ROOT" ]]; then
  # Absolute path to this script file
  SELF_PATH="$(dirname "$(readlink -f "$0")")"
  echo "$SELF_PATH"
  while [[ "$SELF_PATH" != "/" ]]; do
    [[ -f "$SELF_PATH/kgsm.sh" ]] && KGSM_ROOT="$SELF_PATH" && break
    SELF_PATH="$(dirname "$SELF_PATH")"
  done

  if [[ -z "$KGSM_ROOT" ]]; then
    echo "${0##*/} ERROR: Could not locate kgsm.sh. Ensure the directory structure is intact." && exit 1
  fi

  export KGSM_ROOT
fi

export CONFIG_FILE="$KGSM_ROOT/config.ini"
export DEFAULT_CONFIG_FILE="$KGSM_ROOT/config.default.ini"
export MERGED_CONFIG_FILE="$KGSM_ROOT/config.merged.ini"

# Avoid reloading config if it's already been loaded once
if [[ -z "$KGSM_CONFIG_LOADED" ]]; then
  if [[ ! -f "$CONFIG_FILE" ]]; then
    if [ -f "$DEFAULT_CONFIG_FILE" ]; then
      cp "$DEFAULT_CONFIG_FILE" "$CONFIG_FILE"
      echo "${0##*/} WARNING: config.ini not found, created new file" >&2
      echo "${0##*/} INFO: Please ensure configuration is correct before running the script again" >&2
      exit 0
    else
      echo "${0##*/} ERROR: Could not find config.default.ini, install might be broken" >&2
      exit 1
    fi
  fi

  while IFS= read -r line || [ -n "$line" ]; do
    # Ignore comment lines and empty lines
    if [[ "$line" =~ ^#.*$ ]] || [[ -z "$line" ]]; then continue; fi
    # Export each config with a prefix
    export "config_${line?}"
  done <"$CONFIG_FILE"

  export KGSM_CONFIG_LOADED=1
fi

function __merge_user_config_with_default() {
  if [[ $(type -t __disable_error_checking) == function ]]; then
    __disable_error_checking
  fi

  backup_file="${CONFIG_FILE}.$(get_version).bak"

  __print_info "Updating ${CONFIG_FILE} ..."

  # Back up existing config
  cp "$CONFIG_FILE" "${backup_file}"

  # Start with an empty merged file
  touch "$MERGED_CONFIG_FILE"

  # Temporary variables for holding block content
  block=""
  varname=""

  # Read the default config line by line
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ -z "$line" ]]; then
      # Process the block when we reach an empty line
      varname=$(echo "$block" | grep -oP '^[^#=\n]+(?==)')

      if [[ -n "$varname" ]]; then
        # Check if the variable exists in user config
        user_value=$(grep -m 1 "^$varname=" "$CONFIG_FILE")

        if [[ -n "$user_value" ]]; then
          # Output the commented block only if it's not already commented
          echo "$block" | sed '/^#/! s/^/# /' >>"$MERGED_CONFIG_FILE"
          echo "$user_value" >>"$MERGED_CONFIG_FILE"
        else
          # Use the block as is
          echo "$block" >>"$MERGED_CONFIG_FILE"
        fi
      else
        # No variable in the block, just copy it
        echo "$block" >>"$MERGED_CONFIG_FILE"
      fi

      # Append a newline after processing each block
      echo >>"$MERGED_CONFIG_FILE"

      # Reset the block
      block=""
    else
      # Accumulate lines into the block
      block+="$line"$'\n'
    fi
  done <"$DEFAULT_CONFIG_FILE"

  # Handle the last block (if file does not end with a newline)
  if [[ -n "$block" ]]; then
    varname=$(echo "$block" | grep -oP '^[^#=\n]+(?==)')

    if [[ -n "$varname" ]]; then
      user_value=$(grep -m 1 "^$varname=" "$CONFIG_FILE")

      if [[ -n "$user_value" ]]; then
        echo "$block" | sed '/^#/! s/^/# /' >>"$MERGED_CONFIG_FILE"
        echo "$user_value" >>"$MERGED_CONFIG_FILE"
      else
        echo "$block" >>"$MERGED_CONFIG_FILE"
      fi
    else
      echo "$block" >>"$MERGED_CONFIG_FILE"
    fi
  fi

  mv "$MERGED_CONFIG_FILE" "$CONFIG_FILE"

  __print_success "Configuration update completed. Backup saved as ${backup_file}."

  __print_info "Please check ${CONFIG_FILE} for modified/new options"

  if [[ $(type -t __enable_error_checking) == function ]]; then
    __enable_error_checking
  fi
}

export -f __merge_user_config_with_default

# Function to add or update a config key in an instance config file
function __add_or_update_config() {
  local config_file="$1"
  local key="$2"
  local value="$3"
  local after_key="${4:-}"

  if [[ -z "$key" || -z "$value" || -z "$config_file" ]]; then
    __print_error "Invalid arguments provided to __add_or_update_config_key."
    return $EC_INVALID_ARG
  fi

  # Check if the config file exists
  if [[ ! -f "$config_file" ]]; then
    __print_error "Config file '$config_file' does not exist."
    return $EC_FILE_NOT_FOUND
  fi

  # Check if the key already exists in the config filee
  if grep -q "^$key=" "$config_file"; then
    # If it exists, modify in-place
    if ! sed -i "/^$key=/c$key=$value" "$config_file" >/dev/null; then
      __print_error "Failed to update key '$key' in '$config_file'."
      return $EC_FAILED_SED
    fi
  else
    # If it doesn't exist, append after the specified key or at the end
    if [[ -n "$after_key" ]] && grep -q "^$after_key=" "$config_file"; then
      sed -i "/^$after_key=/a$key=$value" "$config_file"
    else
      echo "$key=$value" >>"$config_file"
    fi
  fi
}

export -f __add_or_update_config

function __remove_config() {
  local config_file="$1"
  local key="$2"

  # Check if the key and config file are provided
  if [[ -z "$key" || -z "$config_file" ]]; then
    __print_error "Invalid arguments provided to __remove_config_key."
    return $EC_INVALID_ARG
  fi

  # Check if the config file exists
  if [[ ! -f "$config_file" ]]; then
    __print_error "Config file '$config_file' does not exist."
    return $EC_FILE_NOT_FOUND
  fi

  # Check if the file is readable
  if [[ ! -r "$config_file" ]]; then
    __print_error "Config file '$config_file' is not readable."
    return $EC_PERMISSION
  fi

  # Check if the file is writable
  if [[ ! -w "$config_file" ]]; then
    __print_error "Config file '$config_file' is not writable."
    return $EC_PERMISSION
  fi

  # Check if the key exists in the config file
  if ! grep -q "^$key=" "$config_file"; then
    __print_error "Key '$key' does not exist in '$config_file'."
    return $EC_KEY_NOT_FOUND
  fi

  # Remove the key from the config file
  if ! sed -i "/^$key=/d" "$config_file" >/dev/null; then
    __print_error "Failed to remove key '$key' from '$config_file'."
    return $EC_FAILED_SED
  fi

  return 0
}

export -f __remove_config

# Extract the value from a config file, given a key and a path to the config file
function __get_config_value() {
  local config_file="$1"
  local key="$2"

  # Verify that the config file and key are provided
  if [[ -z "$config_file" ]]; then
    __print_error "Config file must be provided to extract value."
    return $EC_INVALID_ARG
  fi
  if [[ -z "$key" ]]; then
    __print_error "Key must be provided to extract value."
    return $EC_INVALID_ARG
  fi

  # Check if the config file exists
  if [[ ! -f "$config_file" ]]; then
    __print_error "Config file '$config_file' does not exist."
    return $EC_FILE_NOT_FOUND
  fi

  # Extract the value using grep and cut
  local value
  value=$(grep -m 1 "^$key=" "$config_file" | cut -d '=' -f2 | tr -d '"')

  # Check if the key was found
  if [[ -z "$value" ]]; then
    __print_error "Key '$key' not found in '$config_file'."
    return $EC_KEY_NOT_FOUND
  fi

  echo "$value"
}
