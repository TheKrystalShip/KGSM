#!/usr/bin/env bash

# This script is in charge of doing system tasks for the other modules.
# Things like directories existence, file permissions, and other system-related tasks.
# It is loaded by the main script and should not be run directly.

function _create_dir() {
  local dir="$1"
  if [[ -z "$dir" ]]; then
    __print_error "No directory specified for creation."
    return $EC_INVALID_ARG
  fi

  # Create the directory with appropriate permissions
  mkdir -p "$dir" || {
    __print_error "Failed to create directory '$dir'."
    return $EC_FAILED_MKDIR
  }

  # Set permissions to 755
  chmod 755 "$dir" || {
    __print_error "Failed to set permissions for '$dir'."
    return $EC_PERMISSION
  }
}

export -f _create_dir

function _source() {
  local file="$1"
  if [[ -z "$file" ]]; then
    __print_error "No file specified for sourcing."
    return $EC_INVALID_ARG
  fi

  # Check if the file is readable
  if [[ ! -r "$file" ]]; then
    __print_error "File '$file' is not readable."
    return $EC_PERMISSION
  fi

  # Check if the file exists
  if [[ ! -f "$file" ]]; then
    __print_error "File '$file' does not exist."
    return $EC_FILE_NOT_FOUND
  fi

  # Source the file
  # shellcheck disable=SC1090
  source "$file" || {
    __print_error "Failed to source file '$file'."
    return $EC_FAILED_SOURCE
  }
}

export -f _source

export KGSM_SYSTEM_LOADED=1
