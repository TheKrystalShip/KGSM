#!/bin/bash

if [ $# -eq 0 ]; then
  echo ">>> ERROR: BLUEPRINT name not supplied. Run script like this: ./${0##*/} \"BLUEPRINT\"" >&2
  exit 1
fi

# Check for KGSM_ROOT env variable
if [ -z "$KGSM_ROOT" ]; then
  echo "WARNING: KGSM_ROOT environmental variable not found, sourcing /etc/environment." >&2
  # shellcheck disable=SC1091
  source /etc/environment

  # If not found in /etc/environment
  if [ -z "$KGSM_ROOT" ]; then
    echo ">>> ERROR: KGSM_ROOT environmental variable not found, exiting." >&2
    exit 1
  else
    echo "INFO: KGSM_ROOT found in /etc/environment, consider rebooting the system" >&2

    # Check if KGSM_ROOT is exported
    if ! declare -p KGSM_ROOT | grep -q 'declare -x'; then
      export KGSM_ROOT
    fi
  fi
fi

BLUEPRINT=$1

COMMON_SCRIPT="$(find "$KGSM_ROOT" -type f -name common.sh)"
BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"
CREATE_DIR_STRUCTURE_SCRIPT="$(find "$KGSM_ROOT" -type f -name create_dir_structure.sh)"
CREATE_SERVICE_FILES_SCRIPT="$(find "$KGSM_ROOT" -type f -name create_service_files.sh)"
CREATE_FIREWALL_RULE_SCRIPT="$(find "$KGSM_ROOT" -type f -name create_firewall_rule.sh)"
CREATE_MANAGE_FILE_SCRIPT="$(find "$KGSM_ROOT" -type f -name create_manage_file.sh)"
CREATE_OVERRIDES_FILE_SCRIPT="$(find "$KGSM_ROOT" -type f -name create_overrides_file.sh)"
SETUP_SCRIPT="$(find "$KGSM_ROOT" -type f -name create_symlinks.sh)"

# shellcheck disable=SC1090
source "$COMMON_SCRIPT" || exit 1

# Check if blueprint ends with .bp extension. If not, add it
if [[ "$BLUEPRINT" != *.bp ]]; then
  BLUEPRINT="${BLUEPRINT}.bp"
fi

BLUEPRINT_FILE_PATH="$BLUEPRINTS_SOURCE_DIR/$BLUEPRINT"

# Check if blueprint file actually exists
if [ ! -f "$BLUEPRINT_FILE_PATH" ]; then
  echo ">>> ERROR: Could not find blueprint $BLUEPRINT_FILE_PATH, exiting" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$BLUEPRINT_SCRIPT" "$BLUEPRINT" || exit 1

"$CREATE_DIR_STRUCTURE_SCRIPT" "$SERVICE_NAME"
"$CREATE_SERVICE_FILES_SCRIPT" "$SERVICE_NAME"
"$CREATE_FIREWALL_RULE_SCRIPT" "$SERVICE_NAME" "$SERVICE_PORT"
"$CREATE_MANAGE_FILE_SCRIPT" "$SERVICE_NAME"
"$CREATE_OVERRIDES_FILE_SCRIPT" "$SERVICE_NAME"

# This will create symlinks
"$SETUP_SCRIPT" "$SERVICE_NAME"
