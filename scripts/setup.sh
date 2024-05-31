#!/bin/bash

# Params
if [ $# -eq 0 ]; then
  echo ">>> ERROR: Service NAME not supplied. Run script like this: ./${0##*/} \"NAME\" \"PORT\"" >&2
  exit 1
fi

if [ -z "$KGSM_ROOT" ] && [ -z "$KGSM_ROOT_FOUND" ]; then
  echo "WARNING: KGSM_ROOT environmental variable not found, sourcing /etc/environment." >&2
  # shellcheck disable=SC1091
  source /etc/environment

  if [ -z "$KGSM_ROOT" ]; then
    echo ">>> ERROR: KGSM_ROOT environmental variable not found, exiting." >&2
    exit 1
  else
    if [ -z "$KGSM_ROOT_FOUND" ]; then
      echo "INFO: KGSM_ROOT found in /etc/environment, consider rebooting the system" >&2
      export KGSM_ROOT_FOUND=1
    fi
  fi
fi

SERVICE=$1

BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"
OVERRIDES_SCRIPT="$(find "$KGSM_ROOT" -type f -name overrides.sh)"

# shellcheck disable=SC1090
source "$BLUEPRINT_SCRIPT" "$SERVICE" || exit 1

# Safe to run multiple times.
# Ensures symlinks for .service/.socket/ufw
# files exist and creates them if it can
function func_setup() {
  # Symlink .service file to systemd
  local service_symlink=/etc/systemd/system/$SERVICE_NAME.service
  if [ ! -e "$service_symlink" ]; then
    local service_file="$SERVICE_SERVICE_DIR/$SERVICE_NAME.service"
    if [ -f "$service_file" ]; then
      if sudo ln -s "$service_file" "$service_symlink"; then
        echo "$service_file -> $service_symlink"
      fi
    fi
  fi

  # Symlink .socket file to systemd
  local socket_symlink=/etc/systemd/system/$SERVICE_NAME.socket
  if [ ! -e "$socket_symlink" ]; then
    local socket_file="$SERVICE_SERVICE_DIR/$SERVICE_NAME.socket"
    if [ -f "$socket_file" ]; then
      if sudo ln -s "$socket_file" "$socket_symlink"; then
        echo "$socket_file -> $socket_symlink"
      fi
    fi
  fi

  # Symlink firewall rules to ufw
  local firewall_symlink=/etc/ufw/applications.d/ufw-$SERVICE_NAME
  if [ ! -e "$firewall_symlink" ]; then
    local firewall_file="$SERVICE_SERVICE_DIR/ufw-$SERVICE_NAME"
    if [ -f "$firewall_file" ]; then
      if sudo ln -s "$firewall_file" "$firewall_symlink"; then
        echo "$firewall_file -> $firewall_symlink"
      fi
    fi
  fi
}

# shellcheck disable=SC1090
source "$OVERRIDES_SCRIPT" "$SERVICE_NAME" || exit 1

func_setup
