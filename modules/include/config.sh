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
    # Export each key-value pair
    export "${line?}"
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
          echo "$block" | sed '/^#/! s/^/# /' >> "$MERGED_CONFIG_FILE"
          echo "$user_value" >> "$MERGED_CONFIG_FILE"
        else
          # Use the block as is
          echo "$block" >> "$MERGED_CONFIG_FILE"
        fi
      else
        # No variable in the block, just copy it
        echo "$block" >> "$MERGED_CONFIG_FILE"
      fi

      # Append a newline after processing each block
      echo >> "$MERGED_CONFIG_FILE"

      # Reset the block
      block=""
    else
      # Accumulate lines into the block
      block+="$line"$'\n'
    fi
  done < "$DEFAULT_CONFIG_FILE"

  # Handle the last block (if file does not end with a newline)
  if [[ -n "$block" ]]; then
    varname=$(echo "$block" | grep -oP '^[^#=\n]+(?==)')

    if [[ -n "$varname" ]]; then
      user_value=$(grep -m 1 "^$varname=" "$CONFIG_FILE")

      if [[ -n "$user_value" ]]; then
        echo "$block" | sed '/^#/! s/^/# /' >> "$MERGED_CONFIG_FILE"
        echo "$user_value" >> "$MERGED_CONFIG_FILE"
      else
        echo "$block" >> "$MERGED_CONFIG_FILE"
      fi
    else
      echo "$block" >> "$MERGED_CONFIG_FILE"
    fi
  fi

  mv "$MERGED_CONFIG_FILE" "$CONFIG_FILE"

  __print_success "Configuration update completed. Backup saved as ${backup_file}."

  __print_info "Please check ${CONFIG_FILE} for modified/new options"

  if [[ $(type -t __enable_error_checking) == function ]]; then
    __enable_error_checking
  fi
}
