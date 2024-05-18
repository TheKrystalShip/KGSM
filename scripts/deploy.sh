#!/bin/bash

# Params
if [ $# -eq 0 ]; then
  echo ">>> ERROR: Service name not supplied. Run script like this: ./${0##*/} \"SERVICE\""
  exit 1
fi

SERVICE=$1

# shellcheck disable=SC1091
source /opt/scripts/includes/service_vars.sh "$SERVICE"

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

# shellcheck disable=SC1091
source /opt/scripts/includes/overrides.sh "$SERVICE_NAME"

func_deploy "$SERVICE_TEMP_DIR" "$SERVICE_INSTALL_DIR"
