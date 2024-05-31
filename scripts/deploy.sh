#!/bin/bash

# Params
if [ $# -eq 0 ]; then
  echo ">>> ERROR: Service name not supplied. Run script like this: ./${0##*/} \"SERVICE\""
  exit 1
fi

# shellcheck disable=SC1091
source /etc/environment

if [ -z "$KGSM_ROOT" ]; then
  echo ">>> ERROR: KGSM_ROOT environmental variable not set, exiting."
  exit 1
fi

SERVICE=$1

BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"
OVERRIDES_SCRIPT="$(find "$KGSM_ROOT" -type f -name overrides.sh)"

# shellcheck disable=SC1090
source "$BLUEPRINT_SCRIPT" "$SERVICE" || exit 1

function func_deploy() {
  local source=$1
  local dest=$2

  # Check if $source is empty
  if [ -z "$(ls -A -I .gitignore "$source")" ]; then
    echo ">>> WARNING: $source is empty, nothing to deploy. Exiting"
    return 1
  fi

  # Check if $dest is empty
  if [ -n "$(ls -A -I .gitignore "$dest")" ]; then
    # $dest is not empty
    read -r -p ">>> WARNING: $dest is not empty, continue? (y/n): " confirm && [[ $confirm == [yY] ]] || exit 1
  fi

  # Move everything from $source into $dest
  if ! mv -v "$source"/* "$dest"/; then
    echo ">>> ERROR: Failed to move contents from $source into $dest"
    return 1
  fi

  return 0
}

# shellcheck disable=SC1090
source "$OVERRIDES_SCRIPT" "$SERVICE_NAME" || exit 1

func_deploy "$SERVICE_TEMP_DIR" "$SERVICE_INSTALL_DIR"
