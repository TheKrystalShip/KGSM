#!/bin/bash

trap 'clear && exit' INT

COMMON_SCRIPT="$(find "$KGSM_ROOT" -type f -name common.sh)"
DIALOG_SCRIPT="$(find "$KGSM_ROOT" -type f -name dialog.sh)"
BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"

# shellcheck disable=SC1091
source /etc/environment

# shellcheck disable=SC1090
source "$COMMON_SCRIPT" || exit 1

# shellcheck disable=SC1090
source "$DIALOG_SCRIPT" || exit 1

BASE_DIR=/opt
VERSION_CHECK_SCRIPT="$(find "$KGSM_ROOT" -type f -name version_check.sh)"
CREATE_BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name create_blueprint.sh)"
BUILD_SCRIPT="$(find "$KGSM_ROOT" -type f -name create_from_blueprint.sh)"
UPDATE_SCRIPT="$(find "$KGSM_ROOT" -type f -name update.sh)"
CREATE_BACKUP_SCRIPT="$(find "$KGSM_ROOT" -type f -name create_backup.sh)"
RESTORE_BACKUP_SCRIPT="$(find "$KGSM_ROOT" -type f -name restore_backup.sh)"
SETUP_SCRIPT="$(find "$KGSM_ROOT" -type f -name setup.sh)"
DELETE_SCRIPT="$(find "$KGSM_ROOT" -type f -name delete.sh)"

# Load an array with all the game names from DB
# shellcheck disable=SC2207
declare -a SERVICES=()

function clear_exit() {
  clear && exit 0
}

DIALOG_TITLE="KGSM - manager.sh - v0.1"

function init() {
  get_services

  # Starting options
  # shellcheck disable=SC2034
  declare -a actions_options=(
    "Create blueprint"
    "Build blueprint"
    "Run Install"
    "Check for update"
    "Create backup"
    "Restore backup"
    "Run Setup"
    "Delete"
  )

  # Pick action
  # shellcheck disable=SC2155
  local action_index=$(show_dialog actions_options)

  # If dialog was cancelled
  if [ "$action_index" -eq -1 ]; then clear_exit; fi

  # Index 0 is "Create blueprint"
  if [ "$action_index" -eq 0 ]; then
    # At this point manager.sh has nothing else to do, so
    # switch to CREATE_BLUEPRINT_SCRIPT.
    clear
    exec "$CREATE_BLUEPRINT_SCRIPT"
  fi

  # Index 1 is "Build blueprint"
  if [ "$action_index" -eq 1 ]; then
    blueprint=$(select_blueprint_menu)
    clear
    exec "$BUILD_SCRIPT" "$blueprint"
  fi

  # Index 2 is "Run Install"
  if [ "$action_index" -eq 2 ]; then
    # shellcheck disable=SC2155
    local service_index=$(show_dialog SERVICES)
    clear
    if [ "$service_index" -eq -1 ]; then clear_exit; fi
    bash "$UPDATE_SCRIPT" "${SERVICES[$service_index]}"
  fi

  # Index 3 is "Check for update"
  if [ "$action_index" -eq 3 ]; then
    # shellcheck disable=SC2155
    local service_index=$(show_dialog SERVICES)
    clear
    if [ "$service_index" -eq -1 ]; then clear_exit; fi
    bash "$VERSION_CHECK_SCRIPT" "${SERVICES[$service_index]}"
  fi

  # Index 4 is "Create backup"
  if [ "$action_index" -eq 4 ]; then
    # shellcheck disable=SC2155
    local service_index=$(show_dialog SERVICES)
    clear
    if [ "$service_index" -eq -1 ]; then clear_exit; fi
    bash "$CREATE_BACKUP_SCRIPT" "${SERVICES[$service_index]}"
  fi

  # Index 5 is "Restore backup"
  if [ "$action_index" -eq 5 ]; then
    # shellcheck disable=SC2155
    local service_index=$(show_dialog SERVICES)
    local service="${SERVICES[$service_index]}"
    source_dir=$(restore_backup_menu "$service")
    clear
    if [ "$service_index" -eq -1 ]; then clear_exit; fi
    exec "$RESTORE_BACKUP_SCRIPT" "$service" "$source_dir"
  fi

  # Index 6 is "Run Setup"
  if [ "$action_index" -eq 6 ]; then
    # shellcheck disable=SC2155
    local service_index=$(show_dialog SERVICES)
    clear
    if [ "$service_index" -eq -1 ]; then clear_exit; fi
    exec "$SETUP_SCRIPT" "${SERVICES[$service_index]}"
  fi

  # Index 7 is "Delete"
  if [ "$action_index" -eq 7 ]; then
    # shellcheck disable=SC2155
    local service_index=$(show_dialog SERVICES)
    clear
    if [ "$service_index" -eq -1 ]; then clear_exit; fi
    exec "$DELETE_SCRIPT" "${SERVICES[$service_index]}"
  fi
}

function get_services() {
  shopt -s extglob nullglob

  # You may omit the following subdirectories
  # the syntax is that of extended globs, e.g.,
  # omitdir="cmmdm|not_this_+([[:digit:]])|keep_away*"
  # If you don't want to omit any subdirectories, leave empty: omitdir=
  omitdir=(.vscode meta discord status-watchdog)

  # Create array
  service_names=("$BASE_DIR"/*/)
  # remove leading BASE_DIR:
  service_names=("${service_names[@]#"$BASE_DIR/"}")
  # remove trailing backslash and insert Exit choice
  service_names=("${service_names[@]%/}")

  # Remove $omitdir entries
  for del in "${omitdir[@]}"; do
    service_names=("${service_names[@]/$del/}") #Quotes when working with strings
  done

  # Remove empty entries left behind by $omitdir
  for service in "${service_names[@]}"; do
    if [ -n "$service" ]; then
      SERVICES+=("$service")
    fi
  done

  # At this point you have a nice array SERVICES, indexed from 0
  # that contains all the subdirectories of $BASE_DIR
  # (except the omitted ones)
  # You should check that you have at least one directory in there:
  if ((${#SERVICES[@]} < 1)); then
    printf 'No subdirectories found. Exiting.\n'
    exit 0
  fi
}

function restore_backup_menu() {
  local service=$1

  # shellcheck disable=SC1090
  source "$BLUEPRINT_SCRIPT" "$service" || exit 1
  shopt -s extglob nullglob

  # Create array
  backups=("$SERVICE_BACKUPS_DIR"/*/)
  # remove leading $SERVICE_BACKUPS_DIR:
  backups=("${backups[@]#"$SERVICE_BACKUPS_DIR/"}")
  # remove trailing backslash
  backups=("${backups[@]%/}")

  if ((${#backups[@]} < 1)); then
    printf 'No subdirectories found. Exiting.\n'
    exit 0
  fi

  # shellcheck disable=SC2034
  DIALOG_TITLE="KGSM - Backup Restore - v0.1"
  # shellcheck disable=SC2155
  local choice_index=$(show_dialog backups)

  echo "${backups[$choice_index]}"
}

function select_blueprint_menu() {
  shopt -s extglob nullglob

  # Create array
  blueprints=("$BLUEPRINTS_SOURCE_DIR"/*)
  # remove leading $BLUEPRINTS_SOURCE_DIR:
  blueprints=("${blueprints[@]#"$BLUEPRINTS_SOURCE_DIR/"}")

  if ((${#blueprints[@]} < 1)); then
    printf 'No blueprints found. Exiting.\n'
    exit 0
  fi

  # shellcheck disable=SC2034
  DIALOG_TITLE="KGSM - Blueprint builder - v0.1"
  # shellcheck disable=SC2155
  local blueprint_index=$(show_dialog blueprints)

  # If dialog was cancelled
  if [ "$blueprint_index" -eq -1 ]; then clear_exit; fi

  echo "${blueprints[$blueprint_index]}"
}

init "$@"
