#!/bin/bash

# shellcheck disable=SC1091
source /etc/environment

# shellcheck disable=SC1091
source /opt/scripts/includes/db.sh

# shellcheck disable=SC1091
source /opt/scripts/includes/dialog.sh

VERSION_CHECK_SCRIPT=/opt/scripts/version_check.sh
INSTALL_SCRIPT=/opt/scripts/install.sh
UPDATE_SCRIPT=/opt/scripts/update.sh
CREATE_BACKUP_SCRIPT=/opt/scripts/create_backup.sh
RESTORE_BACKUP_SCRIPT=/opt/scripts/restore_backup.sh
DELETE_SCRIPT=/opt/scripts/delete.sh
SETUP_SCRIPT=/opt/scripts/setup.sh

# Load an array with all the game names from DB
# shellcheck disable=SC2207
declare -a SERVICES=($(db_get_all_names))

function init() {
  # Starting options
  # shellcheck disable=SC2034
  actions_options=(
    "New"
    "Check for update"
    "Update"
    "Create backup"
    "Restore backup"
    "Delete"
    "Setup"
  )

  # Pick action
  # shellcheck disable=SC2155
  local action_index=$(show_dialog actions_options)

  # If dialog was cancelled
  if [ -z "$action_index" ]; then
    clear
    return 0
  fi

  # Index 0 is "Create new"
  if [ "$action_index" -eq 0 ]; then
    # At this point manager.sh has nothing else to do, so
    # switch to install script.
    exec "$INSTALL_SCRIPT"
  fi

  # Pick game
  # shellcheck disable=SC2155
  local service_index=$(show_dialog SERVICES)

  # If dialog was cancelled
  if [ -z "$service_index" ]; then
    clear
    return 0
  fi

  local service="${SERVICES[$service_index]}"

  # Index 4 is "Restore backup"
  if [ "$action_index" -eq 4 ]; then
    # "Restore backup" requires more parameters, so show another
    # list menu to select which backup to restore, then switch
    # to the restore backup script.
    source_dir=$(restore_backup_menu "$service")
    exec "$RESTORE_BACKUP_SCRIPT" "$service" "$source_dir"
  fi

  # Clear the screen, otherwise the dialog background stays
  clear

  # All choices that haven't been accounted for until this point
  # get passed onto the process_choice function
  process_choice "$action_index" "$service"
}

function process_choice() {
  local action=$1
  local service=$2

  # Some actions are taken care of before reaching this section
  # so there will be some missing cases, all okay
  case $action in
  1) # version_check
    bash "$VERSION_CHECK_SCRIPT" "$service"
    ;;
  2) # update
    bash "$UPDATE_SCRIPT" "$service"
    ;;
  3) # create_backup
    bash "$CREATE_BACKUP_SCRIPT" "$service"
    ;;
  5) # delete
    bash "$DELETE_SCRIPT" "$service"
    ;;
  6) # setup
    bash "$SETUP_SCRIPT" "$service"
    ;;
  esac
}

function restore_backup_menu() {
  local service=$1
  source /opt/scripts/includes/service_vars.sh "$service"
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
  DIALOG_TITLE="Backup Restore v0.1"
  # shellcheck disable=SC2155
  local choice_index=$(show_dialog backups)

  echo "${backups[$choice_index]}"
}

init "$@"
