#!/bin/bash

# Params
if [ $# -eq 0 ]; then
  echo ">>> ERROR: Service name not supplied. Run script like this: ./${0##*/} \"SERVICE\" \"PORT\""
  exit 1
fi
if [ $# -eq 1 ]; then
  echo ">>> ERROR: Service port not supplied. Run script like this: ./${0##*/} \"SERVICE\" \"PORT\""
  exit 1
fi

SERVICE=$1
PORT=$2


BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"

# shellcheck disable=SC1090
source "$BLUEPRINT_SCRIPT" "$SERVICE" || exit 1

FIREWALL_FILE="ufw-$SERVICE_NAME"
OUTPUT_FILE="$SERVICE_SERVICE_DIR/$FIREWALL_FILE"

function create_firewall_rule_file() {
  cat >"$OUTPUT_FILE" <<-EOF
[$SERVICE_NAME]
title=$SERVICE_NAME
description=$SERVICE_NAME
ports=$PORT
EOF
}

create_firewall_rule_file
