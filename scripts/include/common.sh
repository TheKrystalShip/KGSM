#!/bin/bash

if [ -z "$KGSM_ROOT" ]; then
  echo "WARNING: KGSM_ROOT environmental variable not found, sourcing /etc/environment." >&2
  # shellcheck disable=SC1091
  source /etc/environment

  if [ -z "$KGSM_ROOT" ]; then
    echo ">>> ERROR: KGSM_ROOT environmental variable not found, exiting." >&2
    exit 1
  else
    echo "INFO: KGSM_ROOT found in /etc/environment, consider rebooting the system" >&2
  fi
fi

# Blueprints (*.bp) are stored here
# shellcheck disable=SC2155
export BLUEPRINTS_SOURCE_DIR="$(find "$KGSM_ROOT" -type d -name blueprints)"

# Overides (*.overrides.sh) are stored here
# shellcheck disable=SC2155
export OVERRIDES_SOURCE_DIR="$(find "$KGSM_ROOT" -type d -name overrides)"

# Templates (*.tp) are stored here
# shellcheck disable=SC2155
export TEMPLATES_SOURCE_DIR="$(find "$KGSM_ROOT" -type d -name templates)"

# All other scripts (*.sh) are stored here
# shellcheck disable=SC2155
export SCRIPTS_SOURCE_DIR="$(find "$KGSM_ROOT" -type d -name scripts)"

# "Library" scripts are stored here
# shellcheck disable=SC2155
export SCRIPTS_INCLUDE_SOURCE_DIR="$(find "$KGSM_ROOT" -type d -name include)"
