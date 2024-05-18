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

# shellcheck disable=SC1091
source /opt/scripts/includes/service_vars.sh "$SERVICE"

FIREWALL_FILE="ufw-$SERVICE_NAME"
OUTPUT_FILE="$SERVICE_WORKING_DIR/service/$FIREWALL_FILE"

function create_firewall_rule_file() {
  cat >"$OUTPUT_FILE" <<-EOF
[$SERVICE_NAME]
title=$SERVICE_NAME
description=$SERVICE_NAME
ports=$PORT
EOF
}

create_firewall_rule_file
