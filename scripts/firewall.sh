#!/bin/bash

function usage() {
  echo "Creates the required UFW firewall rule file and enables said rule on
installation.
Will remove the rule and file on uninstall.

Usage:
    Must be called with root privilages
    sudo ./firewall.sh <blueprint> <option>

Options:
    blueprint     Name of the blueprint file.
                  The .bp extension in the name is optional

    -h --help     Prints this message

    --install     Generates the firewall rule file for
                  the specified blueprint and enables said
                  rule in UFW

    --uninstall   Removes the firewall rule file for
                  the specified blueprint and also disables
                  said rule from UFW

Examples:
    sudo ./firewall.sh valheim --install

    sudo ./firewall.sh terraria --uninstall
"
}

# Params
if [ $# -le 1 ]; then
  usage && exit 1
fi

if [ "$EUID" -ne 0 ]; then
  echo "${0##*/} Please run as root" >&2
  exit 1
fi

# Check for KGSM_ROOT env variable
if [ -z "$KGSM_ROOT" ]; then
  echo "${0##*/} WARNING: KGSM_ROOT environmental variable not found, sourcing /etc/environment." >&2
  # shellcheck disable=SC1091
  source /etc/environment

  # If not found in /etc/environment
  if [ -z "$KGSM_ROOT" ]; then
    echo ">>> ${0##*/} ERROR: KGSM_ROOT environmental variable not found, exiting." >&2
    exit 1
  else
    echo "${0##*/} INFO: KGSM_ROOT found in /etc/environment, consider rebooting the system" >&2

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
  # If firewall rule file already exists, remove it
  if [ -f "$SERVICE_UFW_FIREWALL_FILE" ]; then
    # echo "${0##*/} WARNING: UFW rule for $SERVICE_NAME already exists, removing" >&2
    if ! _uninstall; then exit 1; fi
  fi

  # shellcheck disable=SC2155
  local ufw_template_file="$(find "$KGSM_ROOT" -type f -name ufw.tp)"

  if [ -z "$ufw_template_file" ]; then
    echo ">>> ${0##*/} ERROR: Could not load ufw.tp template" >&2
    exit 1
  fi

  # Create file
  if ! touch "$SERVICE_UFW_FIREWALL_FILE"; then
    echo ">>> ${0##*/} ERROR: Failed to create file $SERVICE_UFW_FIREWALL_FILE" >&2
    exit 1
  fi

  # Create firewall rule file from template
  if ! eval "cat <<EOF
$(<"$ufw_template_file")
EOF
" >"$SERVICE_UFW_FIREWALL_FILE"; then
    echo ">>> ${0##*/} ERROR: Failed writing rules to $SERVICE_UFW_FIREWALL_FILE" >&2
    exit 1
  fi

  # Enable firewall rule
  if ! ufw allow "$SERVICE_NAME" &>>/dev/null; then
    echo ">>> ${0##*/} ERROR: Failed to allow UFW rule for $SERVICE_NAME" >&2
    exit 1
  fi
}

function _uninstall() {
  # Remove ufw rule
  if ! ufw delete allow "$SERVICE_NAME" &>>/dev/null; then
    echo ">>> ${0##*/} ERROR: Failed to remove UFW rule for $SERVICE_NAME" >&2
    exit 1
  fi

  if [ -f "$SERVICE_UFW_FIREWALL_FILE" ]; then
    # Delete firewall rule file
    if ! rm "$SERVICE_UFW_FIREWALL_FILE"; then
      echo ">>> ${0##*/} ERROR: Failed to remove $SERVICE_UFW_FIREWALL_FILE" >&2
      exit 1
    fi
  fi
}

#Read the argument values
while [ $# -gt 0 ]; do
  case "$2" in
  -h | --help)
    usage && exit
    shift
    ;;
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
