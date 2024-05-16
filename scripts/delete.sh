#!/bin/bash

# Params
if [ $# -eq 0 ]; then
  echo ">>> ERROR: Service name not supplied. Run script like this: ./${0##*/} \"SERVICE\""
  exit 1
fi

SERVICE=$1

# shellcheck disable=SC1091
source /opt/scripts/service_vars.sh "$SERVICE"

# shellcheck disable=SC1091
source /opt/scripts/db.sh

db_delete_by_name "$SERVICE_NAME"

rm -rf "${SERVICE_WORKING_DIR:?}"
