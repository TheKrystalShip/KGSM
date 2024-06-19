#!/bin/bash

function usage() {
  echo "Creates the required *.service and *.socket files used by systemd
in order to run the service on installation.
Will remove the *.service and *.socket files on uninstall.
Reloads systemd when either options is executed.

Usage:
    Must be called with root privilages
    sudo ./systemd.sh <blueprint> <option>

Options:
    blueprint     Name of the blueprint file.
                  The .bp extension in the name is optional

    -h --help     Prints this message

    --install     Will create the required \$SERVICE_NAME.service
                  and \$SERVICE_NAME.socket files under \$SYSTEMD_DIR
                  Will also reaload systemd so that the newly installed
                  service & socket files can be used immediately

    --uninstall   Will remove the \$SERVICE_NAME.service and
                  \$SERVICE_NAME.socket files from \$SYSTEMD_DIR.
                  Will also reload systemd

Examples:
    sudo ./systemd.sh valheim --install

    sudo ./systemd.sh terraria --uninstall
"
}

if [ $# -eq 0 ]; then
  usage && exit 1
fi

#Read the argument values
while [ $# -gt 0 ]; do
  case "$1" in
  -h | --help)
    usage && exit 0
    shift
    ;;
  *)
    shift
    ;;
  esac
  shift
done

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root" >&2
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

# Trap CTRL-C
trap "echo "" && exit" INT

BLUEPRINT=$1

BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"

# shellcheck disable=SC1090
source "$BLUEPRINT_SCRIPT" "$BLUEPRINT" || exit 1

function _install() {
  # shellcheck disable=SC2155
  local service_template_file="$(find "$KGSM_ROOT" -type f -name service.tp)"

  if [ -z "$service_template_file" ]; then
    echo ">>> Error: Failed to locate service.tp template" >&2
    exit 1
  fi

  # shellcheck disable=SC2155
  local socket_template_file="$(find "$KGSM_ROOT" -type f -name socket.tp)"

  if [ -z "$socket_template_file" ]; then
    echo ">>> Error: Failed to locate socket.tp template" >&2
    exit 1
  fi

  # If either files already exist, uninstall first
  if [ -f "$SERVICE_SYSTEMD_SERVICE_FILE" ] || [ -f "$SERVICE_SYSTEMD_SOCKET_FILE" ]; then
    if ! _uninstall; then exit 1; fi
  fi

  # Create the service file
  if ! eval "cat <<EOF
$(<"$service_template_file")
EOF
" >"$SERVICE_SYSTEMD_SERVICE_FILE" 2>/dev/null; then
    echo ">>> ERROR: Could not copy $service_template_file to $SERVICE_SYSTEMD_SERVICE_FILE" >&2
    exit 1
  fi

  # Create the socket file
  if ! eval "cat <<EOF
$(<"$socket_template_file")
EOF
" >"$SERVICE_SYSTEMD_SOCKET_FILE" 2>/dev/null; then
    echo ">>> ERROR: Could not copy $socket_template_file to $SERVICE_SYSTEMD_SOCKET_FILE" >&2
    exit 1
  fi

  # Reload systemd
  if ! systemctl daemon-reload; then
    echo ">>> Error: Failed to reload systemd" >&2
    exit 1
  fi
}

function _uninstall() {
  # Remove service file
  if [ -f "$SERVICE_SYSTEMD_SERVICE_FILE" ]; then
    if ! rm "$SERVICE_SYSTEMD_SERVICE_FILE"; then
      echo ">>> Error: Failed to remove $SERVICE_SYSTEMD_SERVICE_FILE" >&2
      exit 1
    fi
  fi

  # Remove socket file
  if [ -f "$SERVICE_SYSTEMD_SOCKET_FILE" ]; then
    if ! rm "$SERVICE_SYSTEMD_SOCKET_FILE"; then
      echo ">>> Error: Failed to remove $SERVICE_SYSTEMD_SOCKET_FILE" >&2
      exit 1
    fi
  fi

  # Reload systemd
  if ! systemctl daemon-reload; then
    echo ">>> Error: Failed to reload systemd" >&2
    exit 1
  fi
}

#Read the argument values
while [ $# -gt 0 ]; do
  case "$2" in
  --install)
    _install
    shift
    ;;
  --uninstall)
    _uninstall
    shift
    ;;
  *)
    shift
    ;;
  esac
  shift
done
