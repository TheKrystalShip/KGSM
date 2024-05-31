#!/bin/bash

# Params
if [ $# -eq 0 ]; then
  echo ">>> ERROR: Service name not supplied. Run script like this: ./${0##*/} \"SERVICE\" \"PORT\"" >&2
  exit 1
fi
if [ $# -eq 1 ]; then
  echo ">>> ERROR: Service port not supplied. Run script like this: ./${0##*/} \"SERVICE\" \"PORT\"" >&2
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
PORT=$2

BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"

# shellcheck disable=SC1090
source "$BLUEPRINT_SCRIPT" "$SERVICE" || exit 1

FIREWALL_FILE="ufw-$SERVICE_NAME"
OUTPUT_FILE="$SERVICE_SERVICE_DIR/$FIREWALL_FILE"

function create_firewall_rule_file() {
  sudo touch "$OUTPUT_FILE"

  cat >"$OUTPUT_FILE" <<-EOF
[$SERVICE_NAME]
title=$SERVICE_NAME
description=$SERVICE_NAME
ports=$PORT
EOF
}

create_firewall_rule_file
