#!/bin/bash

# Check for KGSM_ROOT
if [[ -z "$KGSM_ROOT" ]]; then
  # Absolute path to this script file
  SELF_PATH="$(dirname "$(readlink -f "$0")")"
  while [[ "$SELF_PATH" != "/" ]]; do
    [[ -f "$SELF_PATH/kgsm.sh" ]] && KGSM_ROOT="$SELF_PATH" && break
    SELF_PATH="$(dirname "$SELF_PATH")"
  done
    [[ -z "$KGSM_ROOT" ]] && echo "${0##*/} ERROR: Could not locate kgsm.sh. Ensure the directory structure is intact." && exit 1

  export KGSM_ROOT
fi

# Module loader
if [[ ! $KGSM_LOADER_LOADED ]]; then
  # Provides nice wrappers for locating and loading other modules and files
  include_loader="$(find "$KGSM_ROOT" -type f -name loader.sh -print -quit)"
  if [[ -z "$include_loader" ]]; then
    echo "${0##*/} ERROR: Failed to locate loader.sh" >&2
    echo "${0##*/} ERROR: File structure might be compromised" >&2
    exit 1
  fi

  # shellcheck disable=SC1090
  source "$include_loader" || exit 1
fi

# Error codes and definitions
if [[ ! "$KGSM_ERRORS_LOADED" ]]; then
  # shellcheck disable=SC1090
  source "$(__load_module errors.sh)" || exit 1
fi

# User config.ini
if [[ ! "$KGSM_CONFIG_LOADED" ]]; then
  # shellcheck disable=SC1090
  source "$(__load_module config.sh)" || exit "$EC_FAILED_SOURCE"
fi

# File logging
if [[ ! "$KGSM_LOGGING_LOADED" ]]; then
  # shellcheck disable=SC1090
  source "$(__load_module logging.sh)" || exit "$EC_FAILED_SOURCE"
fi

# KGSM Socket events
if [[ ! "$KGSM_EVENTS_LOADED" ]]; then
  # shellcheck disable=SC1090
  source "$(__load_module events.sh)" || exit "$EC_FAILED_SOURCE"
fi

# Export this to check before loading this file again
export KGSM_COMMON_LOADED=1
