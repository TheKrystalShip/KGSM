#!/bin/bash

export EXITSTATUS_SUCCESS=0
export EXITSTATUS_ERROR=1

function func_exit_error() {
  printf "\t%s\n" "${*:- Update process cancelled}"
  exit "$EXITSTATUS_ERROR"
}

# Params
if [ $# == 0 ]; then
  func_exit_error ">>> ERROR: Game name not supplied. Run script like this: ./${0##*/} \"GAME\""
fi

# shellcheck disable=SC1091
source /opt/scripts/dialog.sh
# shellcheck disable=SC2034
DIALOG_TITLE="Backup Restorer v0.1"

SERVICE_WORKING_DIR=/opt
SERVICE_NAME=$1
SERVICE_BACKUPS_DIR=$SERVICE_WORKING_DIR/$SERVICE_NAME/backups
SERVICE_INSTALL_DIR=$SERVICE_WORKING_DIR/$SERVICE_NAME/install

function print_menu() {
  shopt -s extglob nullglob

  # Create array
  cdarray=("$SERVICE_BACKUPS_DIR"/*/)
  # shellcheck disable=SC2206

  # Make a copy of the directory array since it contains the absolute
  # directory path, used later on when restoring the backup
  cdarray_copy=(${cdarray[@]})
  # Remove trailing backslash
  cdarray_copy=("${cdarray_copy[@]%/}")

  # remove leading SERVICE_BACKUPS_DIR:
  cdarray=("${cdarray[@]#"$SERVICE_BACKUPS_DIR/"}")
  # remove trailing backslash
  cdarray=("${cdarray[@]%/}")

  # At this point you have a nice array cdarray, indexed from 0 (for Exit)
  # that contains Exit and all the subdirectories of $SERVICE_BACKUPS_DIR
  # (except the omitted ones)
  # You should check that you have at least one directory in there:
  if ((${#cdarray[@]} <= 1)); then
    printf 'No subdirectories found. Exiting.\n'
    exit $EXITSTATUS_SUCCESS
  fi

  options=()
  for i in "${!cdarray[@]}"; do
    options+=("$i" "${cdarray[$i]}")
  done

  # shellcheck disable=SC2155
  local choice_index=$(show_dialog options)

  echo "${cdarray_copy[$choice_index]}"
}

function restore() {
  local source=$1

  if [ -n "$(ls -A -I .gitignore "$SERVICE_INSTALL_DIR")" ]; then
    # $SERVICE_INSTALL_DIR is not empty
    read -r -p ">>> WARNING: $SERVICE_INSTALL_DIR is not empty, continue? (y/n): " confirm && [[ $confirm == [yY] ]] || exit 1
  fi

  # $SERVICE_INSTALL_DIR is empty/user confirmed continue, move the backup into it
  if ! mv -v "$source"/* "$SERVICE_INSTALL_DIR"/; then
    echo ">>> ERROR: Failed to move contents from $source into $SERVICE_INSTALL_DIR"
    return
  fi

  # Remove empty backup directory
  if ! rm -rf "${source:?}"; then
    echo "WARNING: Failed to remove empty backup directory $source"
  fi
}

# shellcheck disable=SC2155
choice=$(print_menu)
clear
# shellcheck disable=SC2155
restore "$choice"
