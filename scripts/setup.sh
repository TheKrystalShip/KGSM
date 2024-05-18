#!/bin/bash

# Params
if [ $# -eq 0 ]; then
  echo ">>> ERROR: Service NAME not supplied. Run script like this: ./${0##*/} \"NAME\" \"PORT\""
  exit 1
fi

SERVICE=$1

# shellcheck disable=SC1091
source /opt/scripts/includes/service_vars.sh "$SERVICE"

# Safe to run multiple times.
# Ensures symlinks for .service/.socket/ufw
# files exist and creates them if it can
function func_setup() {
  # Symlink .service file to systemd
  local service_symlink=/etc/systemd/system/$SERVICE_NAME.service
  if [ ! -e "$service_symlink" ]; then
    local service_file="$SERVICE_WORKING_DIR/service/$SERVICE_NAME.service"
    if [ -f "$service_file" ]; then
      if sudo ln -s "$service_file" "$service_symlink"; then
        echo "$service_file -> $service_symlink"
      fi
    fi
  fi

  # Symlink .socket file to systemd
  local socket_symlink=/etc/systemd/system/$SERVICE_NAME.socket
  if [ ! -e "$socket_symlink" ]; then
    local socket_file="$SERVICE_WORKING_DIR/service/$SERVICE_NAME.socket"
    if [ -f "$socket_file" ]; then
      if sudo ln -s "$socket_file" "$socket_symlink"; then
        echo "$socket_file -> $socket_symlink"
      fi
    fi
  fi

  # Symlink firewall rules to ufw
  local firewall_symlink=/etc/ufw/applications.d/ufw-$SERVICE_NAME
  if [ ! -e "$firewall_symlink" ]; then
    local firewall_file="$SERVICE_WORKING_DIR/service/ufw-$SERVICE_NAME"
    if [ -f "$firewall_file" ]; then
      if sudo ln -s "$firewall_file" "$firewall_symlink"; then
        echo "$firewall_file -> $firewall_symlink"
      fi
    fi
  fi
}

# shellcheck disable=SC1091
source /opt/scripts/includes/overrides.sh "$SERVICE_NAME"

func_setup
