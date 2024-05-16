#!/bin/bash

SERVICE_NAME=""
SERVICE_PORT=""
SERVICE_APP_ID=""
SERVICE_STEAM_AUTH_LEVEL="0"

# shellcheck disable=SC1091
source /opt/scripts/dialog.sh

# shellcheck disable=SC1091
source /opt/scripts/db.sh

# shellcheck disable=SC2034
DIALOG_TITLE="Service installer v0.1"
# shellcheck disable=SC2034
TITLE="Creating new service"

DIALOG_INPUT_BOX="Service name:"
SERVICE_NAME=$(show_input)

if [ -z "$SERVICE_NAME" ]; then
  clear
  exit 0
fi

DIALOG_INPUT_BOX="Service port number:"
SERVICE_PORT=$(show_input)

if [ -z "$SERVICE_PORT" ]; then
  clear
  exit 0
fi

DIALOG_INPUT_BOX="Service APP_ID (0 for none):"
SERVICE_APP_ID=$(show_input)

if [ -z "$SERVICE_APP_ID" ]; then
  clear
  exit 0
fi

if [ "$SERVICE_APP_ID" != "0" ]; then
  # shellcheck disable=SC2034
  DIALOG_INPUT_BOX="Service Steam Auth Level\n(0 for none, 1 for account):"
  SERVICE_STEAM_AUTH_LEVEL=$(show_input)

  if [ -z "$SERVICE_STEAM_AUTH_LEVEL" ]; then
    clear
    exit 0
  fi
fi

clear

db_query "INSERT INTO \
            services(name, working_dir, installed_version, app_id, steam_auth_level) \
          VALUES \
            ('$SERVICE_NAME', '/opt/$SERVICE_NAME', '0', $SERVICE_APP_ID, $SERVICE_STEAM_AUTH_LEVEL);"

# shellcheck disable=SC1091
source /opt/scripts/service_vars.sh "$SERVICE_NAME"

/opt/scripts/create_dir_structure.sh "$SERVICE_NAME"
/opt/scripts/create_service_files.sh --name "$SERVICE_NAME" --port "$SERVICE_PORT"

cp /opt/scripts/examples/manage.sh.example "$SERVICE_MANAGE_SCRIPT_FILE"

if [ "$SERVICE_APP_ID" = "0" ]; then
  cp /opt/scripts/examples/overrides.sh.example "$SERVICE_OVERRIDES_SCRIPT_FILE"
fi
