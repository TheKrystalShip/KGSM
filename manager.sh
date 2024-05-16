#!/bin/bash

# shellcheck disable=SC1091
source /etc/environment

# shellcheck disable=SC1091
source /opt/scripts/db.sh

# shellcheck disable=SC1091
source /opt/scripts/dialog.sh

VERSION_CHECK_SCRIPT=/opt/scripts/version_check.sh
INSTALL_SCRIPT=/opt/scripts/install.sh
UPDATE_SCRIPT=/opt/scripts/update.sh
CREATE_BACKUP_SCRIPT=/opt/scripts/create_backup.sh
RESTORE_BACKUP_SCRIPT=/opt/scripts/restore_backup.sh
DELETE_SCRIPT=/opt/scripts/delete.sh

# Load an array with all the game names from DB
# shellcheck disable=SC2207
declare -a GAMES=($(db_get_all_names))

function init() {
  # Starting options
  # shellcheck disable=SC2034
  actions_options=(
    "Setup new service"
    "Check for update"
    "Update service"
    "Create backup"
    "Restore backup"
    "Delete service"
  )

  # Pick action
  # shellcheck disable=SC2155
  local action_index=$(show_dialog actions_options)

  # If dialog was cancelled
  if [ -z "$action_index" ]; then
    clear
    return 0
  fi

  case $action_index in
  0) # install
    exec "$INSTALL_SCRIPT" "$game"
    return 0
    ;;
  esac

  # Pick game
  # shellcheck disable=SC2155
  local game_index=$(show_dialog GAMES)

  # Clear the screen, otherwise the dialog background stays
  clear

  # Run
  process_choice "$action_index" "${GAMES[$game_index]}"
}

function process_choice() {
  local choice=$1
  local game=$2
  case $choice in
  0) # install
    bash "$INSTALL_SCRIPT" "$game"
    ;;
  1) # version_check
    bash "$VERSION_CHECK_SCRIPT" "$game"
    ;;
  2) # update
    bash "$UPDATE_SCRIPT" "$game"
    ;;
  3) # create_backup
    bash "$CREATE_BACKUP_SCRIPT" "$game"
    ;;
  4) # restore_backup
    bash "$RESTORE_BACKUP_SCRIPT" "$game"
    ;;
  5) # delete
    bash "$DELETE_SCRIPT" "$game"
    ;;
  esac
}

init "$@"
