#!/bin/bash

# Check for KGSM_ROOT env variable
if [ -z "$KGSM_ROOT" ]; then
  echo "WARNING: KGSM_ROOT not found, sourcing /etc/environment." >&2
  # shellcheck disable=SC1091
  source /etc/environment

  # If not found in /etc/environment
  if [ -z "$KGSM_ROOT" ]; then
    echo "ERROR: KGSM_ROOT not found, exiting." >&2
    exit 1
  else
    echo "INFO: KGSM_ROOT found in /etc/environment, consider rebooting the system" >&2

    # Check if KGSM_ROOT is exported
    if ! declare -p KGSM_ROOT | grep -q 'declare -x'; then
      export KGSM_ROOT
    fi
  fi
fi

# Blueprints (*.bp) are stored here
# shellcheck disable=SC2155
export BLUEPRINTS_SOURCE_DIR="$(find "$KGSM_ROOT" -type d -name blueprints)"

# Default blueprints (*.bp) are stored here
# shellcheck disable=SC2155
export BLUEPRINTS_DEFAULT_SOURCE_DIR="$(find "$BLUEPRINTS_SOURCE_DIR" -type d -name default)"

# Specific game server overrides ([service].overrides.sh) are stored here
# shellcheck disable=SC2155
export OVERRIDES_SOURCE_DIR="$(find "$KGSM_ROOT" -type d -name overrides)"

# Templates (*.tp) are stored here
# shellcheck disable=SC2155
export TEMPLATES_SOURCE_DIR="$(find "$KGSM_ROOT" -type d -name templates)"

# All other scripts (*.sh) are stored here
# shellcheck disable=SC2155
export MODULES_SOURCE_DIR="$(find "$KGSM_ROOT" -type d -name modules)"

# "Library" scripts are stored here
# shellcheck disable=SC2155
export SCRIPTS_INCLUDE_SOURCE_DIR="$(find "$KGSM_ROOT" -type d -name include)"

###### System directories

# Systemd directory where .service files will be created
export SYSTEMD_DIR="/etc/systemd/system"

# UFW directory where firewall rule files will be created
export UFW_DIR="/etc/ufw/applications.d"
