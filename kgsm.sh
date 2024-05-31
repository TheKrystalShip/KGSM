#!/bin/bash

VERSION="0.1"

COMMON_SCRIPT="$(find "$KGSM_ROOT" -type f -name common.sh)"

# shellcheck disable=SC1091
source /etc/environment

# shellcheck disable=SC1090
source "$COMMON_SCRIPT" || exit 1

VERSION_CHECK_SCRIPT="$(find "$KGSM_ROOT" -type f -name version_check.sh)"
if [ -z "$VERSION_CHECK_SCRIPT" ]; then
  echo ">>> ERROR: Failed to load version_check.sh" >&2
  exit 1
fi

CREATE_BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name create_blueprint.sh)"
if [ -z "$CREATE_BLUEPRINT_SCRIPT" ]; then
  echo ">>> ERROR: Failed to load create_blueprint.sh" >&2
  exit 1
fi

BUILD_SCRIPT="$(find "$KGSM_ROOT" -type f -name create_from_blueprint.sh)"
if [ -z "$BUILD_SCRIPT" ]; then
  echo ">>> ERROR: Failed to load create_from_blueprint.sh" >&2
  exit 1
fi

UPDATE_SCRIPT="$(find "$KGSM_ROOT" -type f -name update.sh)"
if [ -z "$UPDATE_SCRIPT" ]; then
  echo ">>> ERROR: Failed to load update.sh" >&2
  exit 1
fi

CREATE_BACKUP_SCRIPT="$(find "$KGSM_ROOT" -type f -name create_backup.sh)"
if [ -z "$CREATE_BACKUP_SCRIPT" ]; then
  echo ">>> ERROR: Failed to load create_backup.sh" >&2
  exit 1
fi

RESTORE_BACKUP_SCRIPT="$(find "$KGSM_ROOT" -type f -name restore_backup.sh)"
if [ -z "$RESTORE_BACKUP_SCRIPT" ]; then
  echo ">>> ERROR: Failed to load restore_backup.sh" >&2
  exit 1
fi

SETUP_SCRIPT="$(find "$KGSM_ROOT" -type f -name setup.sh)"
if [ -z "$SETUP_SCRIPT" ]; then
  echo ">>> ERROR: Failed to load setup.sh" >&2
  exit 1
fi

DELETE_SCRIPT="$(find "$KGSM_ROOT" -type f -name delete.sh)"
if [ -z "$DELETE_SCRIPT" ]; then
  echo ">>> ERROR: Failed to load delete.sh" >&2
  exit 1
fi

function _create_blueprint() {
  title="KGSM - Create blueprint - v$VERSION"

  echo "$title"

  "$CREATE_BLUEPRINT_SCRIPT"
}

function _build_blueprint() {
  title="KGSM - Build blueprint - v$VERSION"
  prompt="Choose a blueprint:"

  echo "$title"
  PS3="$prompt "

  declare -a blueprints=()
  get_blueprints blueprints

  if ((${#blueprints[@]} < 1)); then
    printf 'No blueprints found. Exiting.\n'
    return
  fi

  select blueprint in "${blueprints[@]}"; do
    if [[ -z $blueprint ]]; then
      echo "Didn't understand \"$REPLY\" " >&2
      REPLY=
    else
      "$BUILD_SCRIPT" "$blueprint"
      local service=${blueprint::-3}
      "$UPDATE_SCRIPT" "$service"
      return
    fi
  done
}

function _run_install() {
  title="KGSM - Install - v$VERSION"

  echo "$title"

  declare -A services=()
  get_services services

  declare -a service_names=()
  for i in "${!services[@]}"; do
    service_names+=("$i")
  done

  local choice=$(choose_service service_names)

  "$UPDATE_SCRIPT" "$choice"
}

function _check_for_update() {
  title="KGSM - Check for update - v$VERSION"

  echo "$title"

  declare -A services=()
  get_installed_services services

  declare -a service_names=()
  for i in "${!services[@]}"; do
    service_names+=("$i")
  done

  local choice=$(choose_service service_names)

  "$VERSION_CHECK_SCRIPT" "$choice"
}

function _create_backup() {
  title="KGSM - Create backup - v$VERSION"
  prompt="Choose a service:"

  echo "$title"
  PS3="$prompt "

  declare -A services=()
  get_installed_services services

  declare -a service_names=()
  for i in "${!services[@]}"; do
    service_names+=("$i")
  done

  local choice=$(choose_service service_names)
  if [ "$choice" = "-1" ]; then return; fi

  "$CREATE_BACKUP_SCRIPT" "$choice"
}

function _restore_backup() {
  title="KGSM - Restore backup - v$VERSION"
  prompt="Choose a service:"

  echo "$title"
  PS3="$prompt "

  declare -A services=()
  get_services services

  declare -a service_names=()
  for i in "${!services[@]}"; do
    service_names+=("$i")
  done

  local service=$(choose_service service_names)

  local service_backup_dir="${services[$service]}/backups"

  shopt -s extglob nullglob

  prompt="Choose a backup to restore:"
  # Create array
  backups_array=("$service_backup_dir"/*)
  # remove leading $BLUEPRINTS_SOURCE_DIR:
  backups_array=("${backups_array[@]#"$service_backup_dir/"}")

  if ((${#backups_array[@]} < 1)); then
    printf 'No backups found. Exiting.\n'
    return
  fi

  select backup in "${backups_array[@]}"; do
    if [[ -z $backup ]]; then
      echo "Didn't understand \"$REPLY\" " >&2
      REPLY=
    else
      "$RESTORE_BACKUP_SCRIPT" "$service" "$backup"
      return
    fi
  done
}

function _run_setup() {
  title="KGSM - Setup - v$VERSION"
  prompt="Choose a service:"

  echo "$title"
  PS3="$prompt "

  declare -A services=()
  get_installed_services services

  declare -a service_names=()
  for i in "${!services[@]}"; do
    service_names+=("$i")
  done

  local choice=$(choose_service service_names)

  "$SETUP_SCRIPT" "$choice"
}

function _delete() {
  title="KGSM - Delete - v$VERSION"
  prompt="Choose a service:"

  echo "$title"
  PS3="$prompt "

  declare -A services=()
  get_installed_services services

  declare -a service_names=()
  for i in "${!services[@]}"; do
    service_names+=("$i")
  done

  local choice=$(choose_service service_names)

  "$DELETE_SCRIPT" "$choice"
}

function choose_service() {
  local -n ref_services=$1

  select choice in "${ref_services[@]}"; do
    if [[ -z $choice ]]; then
      echo "Didn't understand \"$REPLY\" " >&2
      REPLY=
    else
      echo "$choice"
      return
    fi
  done
}

function get_blueprints() {
  local -n ref_blueprints_array=$1

  shopt -s extglob nullglob

  # Create array
  ref_blueprints_array=("$BLUEPRINTS_SOURCE_DIR"/*)
  # remove leading $BLUEPRINTS_SOURCE_DIR:
  ref_blueprints_array=("${ref_blueprints_array[@]#"$BLUEPRINTS_SOURCE_DIR/"}")
}

function get_services() {
  local -n ref_services_array=$1
  declare -a blueprints=()
  get_blueprints blueprints

  for bp in "${blueprints[@]}"; do
    service_name=$(cat "$BLUEPRINTS_SOURCE_DIR/$bp" | grep "SERVICE_NAME=" | cut -d "=" -f2 | tr -d '"')
    service_working_dir=$(cat "$BLUEPRINTS_SOURCE_DIR/$bp" | grep "SERVICE_WORKING_DIR=" | cut -d "=" -f2 | tr -d '"')

    # If there's no $service_working_dir, skip
    if [ ! -d "$service_working_dir" ]; then
      continue
    fi

    ref_services_array["$service_name"]="$service_working_dir"
  done
}

function get_installed_services() {
  local -n ref_services_array=$1
  declare -a blueprints=()
  get_blueprints blueprints

  for bp in "${blueprints[@]}"; do
    service_name=$(cat "$BLUEPRINTS_SOURCE_DIR/$bp" | grep "SERVICE_NAME=" | cut -d "=" -f2 | tr -d '"')
    service_working_dir=$(cat "$BLUEPRINTS_SOURCE_DIR/$bp" | grep "SERVICE_WORKING_DIR=" | cut -d "=" -f2 | tr -d '"')
    service_version_file="$service_working_dir/.version"

    # If there's no $service_working_dir, skip
    if [ ! -d "$service_working_dir" ]; then
      continue
    fi

    # If there's no .version file, skip
    if [ ! -f "$service_version_file" ]; then
      continue
    fi

    service_version=$(cat "$service_version_file")

    # Check if there's a version number stored in the file
    if [ -z "$service_version" ] || [ "$service_version" = "0" ]; then
      continue
    fi

    ref_services_array["$service_name"]="$service_working_dir"
  done
}

function init() {
  title="KGSM - Main menu - v$VERSION"
  prompt="Choose an action:"

  echo "$title"
  PS3="$prompt "

  declare -A services=()
  get_installed_services services

  declare -a menu_options=(
    "Create blueprint"
    "Build blueprint"
    "Run Install"
    "Check for update"
    "Create backup"
    "Restore backup"
    "Run Setup"
    "Delete"
  )

  declare -A menu_options_functions=(
    ["Create blueprint"]=_create_blueprint
    ["Build blueprint"]=_build_blueprint
    ["Run Install"]=_run_install
    ["Check for update"]=_check_for_update
    ["Create backup"]=_create_backup
    ["Restore backup"]=_restore_backup
    ["Run Setup"]=_run_setup
    ["Delete"]=_delete
  )

  select opt in "${menu_options[@]}"; do
    if [[ -z $opt ]]; then
      echo "Didn't understand \"$REPLY\" " >&2
      REPLY=
    else
      # Here we check that the option is in the associative array
      if [[ -z "${menu_options_functions[$opt]}" ]]; then
        echo "Invalid option. Try another one." >&2
      else
        # Here we execute the function
        "${menu_options_functions[$opt]}"
        break
      fi
    fi
  done
}

init "$@"