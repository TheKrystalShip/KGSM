#!/bin/bash

# Ensures symlinks for .service/.socket/ufw
# files exist and creates them if it can

# Params
if [ $# -eq 0 ]; then
  echo ">>> ERROR: Blueprint name not supplied. Run script like this: ./${0##*/} \"BLUEPRINT\" \"PORT\"" >&2
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

BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"

# shellcheck disable=SC1090
source "$BLUEPRINT_SCRIPT" "$BLUEPRINT" || exit 1

# INPUT:
# $1: Origin file
# $2: Destination file
function create_symlink() {
  local source=$1
  local dest=$2

  if [ ! -f "$source" ]; then
    echo ">>> ERROR: Could not find $source file" >&2
    return
  fi

  if [ ! -e "$source" ]; then
    if ! sudo ln -s "$source" "$dest"; then
      echo ">>> ERROR: Failed to link: $source -> $dest" >&2
    fi
  else
    if ! sudo rm "$dest"; then
      echo ">>> ERROR: Failed to remove existing symlink: $dest" >&2
    fi

    if ! sudo ln -s "$source" "$dest"; then
      echo ">>> ERROR: Failed to link: $source -> $dest" >&2
    fi
  fi
}

# Symlink .service file to systemd
service_symlink="/etc/systemd/system/$SERVICE_NAME.service"
service_file="$SERVICE_SERVICE_DIR/$SERVICE_NAME.service"

create_symlink "$service_file" "$service_symlink"

# Symlink .socket file to systemd
socket_symlink="/etc/systemd/system/$SERVICE_NAME.socket"
socket_file="$SERVICE_SERVICE_DIR/$SERVICE_NAME.socket"

create_symlink "$socket_file" "$socket_symlink"

# Check if ufw is installed
if ! command -v ufw &>/dev/null; then
  return
fi

# Symlink firewall rules to ufw
firewall_symlink="/etc/ufw/applications.d/ufw-$SERVICE_NAME"
firewall_file="$SERVICE_SERVICE_DIR/ufw-$SERVICE_NAME"

create_symlink "$firewall_file" "$firewall_symlink"
