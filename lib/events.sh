#!/usr/bin/env bash

# KGSM Event Dispatcher Library
#
# This module provides centralized event dispatching based on exit codes
# to eliminate code duplication across modules and kgsm.sh.
#
# The dispatcher maps success-event exit codes (200+) to specific event emissions.

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

# Success event exit codes are now centralized in lib/errors.sh
# They are automatically available through the bootstrap process

# Dispatches events based on exit codes from logic functions
# Args: $1 = exit_code, $2 = instance_name, $3... = additional parameters
# Returns: 0 on success, error code on failure
function __dispatch_event_from_exit_code() {
  local exit_code="$1"
  local instance_name="$2"
  shift 2
  local additional_params=("$@")

  # Validate required parameters
  if [[ -z "$exit_code" ]]; then
    return $EC_INVALID_ARG
  fi

  if [[ -z "$instance_name" ]]; then
    return $EC_INVALID_ARG
  fi

  # Find the events module
  local module_events
  if ! module_events=$(__find_module events.sh); then
    return $EC_FILE_NOT_FOUND
  fi

  # Map exit codes to event emissions
  case $exit_code in
    $EC_SUCCESS_DIRECTORIES_CREATED)
      "$module_events" --emit --instance-directories-created "$instance_name"
      return $?
      ;;
    $EC_SUCCESS_DIRECTORIES_REMOVED)
      "$module_events" --emit --instance-directories-removed "$instance_name"
      return $?
      ;;
    *)
      # No event needed for other exit codes
      return 0
      ;;
  esac
}

export -f __dispatch_event_from_exit_code

# Mark module as loaded
export KGSM_EVENTS_LIBRARY_LOADED=1
