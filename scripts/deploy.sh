#!/bin/bash

if [ $# -eq 0 ]; then
  echo "ERROR: Service name not supplied"
  exit 1
fi

SERVICE=$1

# shellcheck disable=SC1091
source /opt/scripts/service_vars.sh "$SERVICE"

function func_deploy() {
  # Check if SERVICE_TEMP_DIR is empty
  if [ -z "$(ls -A -I .gitignore "$SERVICE_TEMP_DIR")" ]; then
    echo ">>> WARNING: $SERVICE_TEMP_DIR is empty, nothing to deploy. Exiting"
    return 1
  fi

  # Check if SERVICE_INSTALL_DIR is empty
  if [ -n "$(ls -A -I .gitignore "$SERVICE_INSTALL_DIR")" ]; then
    # $SERVICE_INSTALL_DIR is not empty
    read -r -p ">>> WARNING: $SERVICE_INSTALL_DIR is not empty, continue? (y/n): " confirm && [[ $confirm == [yY] ]] || exit 1
  fi

  # Move everything from $SERVICE_TEMP_DIR into $SERVICE_INSTALL_DIR
  if ! mv -v "$SERVICE_TEMP_DIR"/* "$SERVICE_INSTALL_DIR"/; then
    echo ">>> ERROR: Failed to move contents from $SERVICE_TEMP_DIR into $SERVICE_INSTALL_DIR"
    return 1
  fi

  return 0
}

# shellcheck disable=SC1091
source /opt/scripts/overrides.sh "$SERVICE_NAME"

func_deploy
