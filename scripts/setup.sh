#!/bin/bash

# Params
if [ $# -eq 0 ]; then
  echo ">>> ERROR: Service NAME not supplied. Run script like this: ./${0##*/} \"NAME\" \"PORT\"" >&2
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

SERVICE=$1

BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"
OVERRIDES_SCRIPT="$(find "$KGSM_ROOT" -type f -name overrides.sh)"

# shellcheck disable=SC1090
source "$BLUEPRINT_SCRIPT" "$SERVICE" || exit 1

# INPUT:
# $1: Origin file
# $2: Destination file
function _create_symlink() {
  local source=$1
  local dest=$2

  if sudo ln -s "$source" "$dest"; then
    echo "$source -> $dest" >&2
  fi
}

# Safe to run multiple times.
# Ensures symlinks for .service/.socket/ufw
# files exist and creates them if it can
function func_setup() {
  # Symlink .service file to systemd
  local service_symlink=/etc/systemd/system/$SERVICE_NAME.service
  if [ ! -e "$service_symlink" ]; then
    local service_file="$SERVICE_SERVICE_DIR/$SERVICE_NAME.service"
    if [ -f "$service_file" ]; then
      _create_symlink "$service_file" "$service_symlink"
    fi
  else
    # If it already exists, need to replace it with new
    if ! sudo rm "$service_symlink"; then
      echo ">>> ERROR: Failed to remove existing symlink: $service_symlink" >&2
    fi

    _create_symlink "$service_file" "$service_symlink"
  fi

  # Symlink .socket file to systemd
  local socket_symlink=/etc/systemd/system/$SERVICE_NAME.socket
  if [ ! -e "$socket_symlink" ]; then
    local socket_file="$SERVICE_SERVICE_DIR/$SERVICE_NAME.socket"
    if [ -f "$socket_file" ]; then
      _create_symlink "$socket_file" "$socket_symlink"
    fi
  else
    # If it already exists, need to replace it with new
    if ! sudo rm "$socket_symlink"; then
      echo ">>> ERROR: Failed to remove existing symlink: $socket_symlink" >&2
    fi

    _create_symlink "$socket_file" "$socket_symlink"
  fi

  # Check if ufw is installed
  if ! ufw --version >/dev/null; then
    return
  fi

  # Symlink firewall rules to ufw
  local firewall_symlink=/etc/ufw/applications.d/ufw-$SERVICE_NAME
  if [ ! -e "$firewall_symlink" ]; then
    local firewall_file="$SERVICE_SERVICE_DIR/ufw-$SERVICE_NAME"
    if [ -f "$firewall_file" ]; then
      _create_symlink "$firewall_file" "$firewall_symlink"
    fi
  else
    # If it already exists, need to replace it with new
    if ! sudo rm "$firewall_symlink"; then
      echo ">>> ERROR: Failed to remove existing symlink: $firewall_symlink" >&2
    fi

    _create_symlink "$firewall_file" "$firewall_symlink"
  fi
}

# shellcheck disable=SC1090
source "$OVERRIDES_SCRIPT" "$SERVICE_NAME" || exit 1

func_setup
