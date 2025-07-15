#!/usr/bin/env bash

# KGSM Pure Logic Layer - Directory Management
#
# This module contains pure business logic functions for directory operations.
# These functions have no user-facing I/O and communicate results only via exit codes.
#
# Exit Code Conventions:
# - 0: Success (no event needed)
# - 200: Directories created successfully (emit instance-directories-created)
# - 201: Directories removed successfully (emit instance-directories-removed)
# - Standard error codes: EC_FAILED_MKDIR, EC_FAILED_RM, EC_PERMISSION, etc.

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

# Success event exit codes are now centralized in lib/errors.sh
# They are automatically available through the bootstrap process

# Creates directory structure for an instance
# Args: $1 = instance_name, $2 = instance_config_file, $3 = instance_working_dir
# Returns: 200 on success (triggers directories-created event), error codes on failure
function __logic_create_directories() {
  local instance_name="$1"
  local instance_config_file="$2"
  local instance_working_dir="$3"

  # Validate required parameters
  if [[ -z "$instance_name" ]]; then
    return $EC_INVALID_ARG
  fi

  if [[ -z "$instance_config_file" ]]; then
    return $EC_INVALID_ARG
  fi

  if [[ -z "$instance_working_dir" ]]; then
    return $EC_INVALID_ARG
  fi

  # Ensure instance_working_dir is an absolute path
  if [[ ! "$instance_working_dir" = /* ]]; then
    return $EC_INVALID_CONFIG
  fi

  # Define directory structure
  declare -A DIR_ARRAY=(
    ["working_dir"]="$instance_working_dir"
    ["backups_dir"]="${instance_working_dir}/backups"
    ["install_dir"]="${instance_working_dir}/install"
    ["saves_dir"]="${instance_working_dir}/saves"
    ["temp_dir"]="${instance_working_dir}/temp"
    ["logs_dir"]="${instance_working_dir}/logs"
  )

  # Create directories and update config
  for dir_key in "${!DIR_ARRAY[@]}"; do
    local dir_value="${DIR_ARRAY[$dir_key]}"

    # Create directory - suppress all output since this is pure logic
    if ! __create_dir "$dir_value" >/dev/null 2>&1; then
      return $EC_FAILED_MKDIR
    fi

    # Update config file - suppress all output since this is pure logic
    if ! __add_or_update_config "$instance_config_file" "$dir_key" "\"$dir_value\"" >/dev/null 2>&1; then
      return $EC_FAILED_UPDATE_CONFIG
    fi
  done

  # Return success event code
  return $EC_SUCCESS_DIRECTORIES_CREATED
}

export -f __logic_create_directories

# Removes directory structure for an instance
# Args: $1 = instance_name, $2 = instance_working_dir
# Returns: 201 on success (triggers directories-removed event), error codes on failure
function __logic_remove_directories() {
  local instance_name="$1"
  local instance_working_dir="$2"

  # Validate required parameters
  if [[ -z "$instance_name" ]]; then
    return $EC_INVALID_ARG
  fi

  if [[ -z "$instance_working_dir" ]]; then
    return $EC_INVALID_ARG
  fi

  # Ensure instance_working_dir is an absolute path for safety
  if [[ ! "$instance_working_dir" = /* ]]; then
    return $EC_INVALID_CONFIG
  fi

  # Remove main working directory (this removes all subdirectories)
  if ! rm -rf "${instance_working_dir?}" 2>/dev/null; then
    return $EC_FAILED_RM
  fi

  # Return success event code
  return $EC_SUCCESS_DIRECTORIES_REMOVED
}

export -f __logic_remove_directories

# Mark module as loaded
export KGSM_LOGIC_DIRECTORIES_LOADED=1
