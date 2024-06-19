#!/bin/bash

VERSION="0.1"

# Check for KGSM_ROOT env variable
if [ -z "$KGSM_ROOT" ]; then
  echo "WARNING: KGSM_ROOT environmental variable not found, sourcing /etc/environment." >&2
  # shellcheck disable=SC1091
  source /etc/environment

  # If not found in /etc/environment
  if [ -z "$KGSM_ROOT" ]; then
    echo ">>> ERROR: KGSM_ROOT environmental variable not found, exiting." >&2
    exit 1
  else
    echo "INFO: KGSM_ROOT found in /etc/environment, consider rebooting the system" >&2

    # Check if KGSM_ROOT is exported
    if ! declare -p KGSM_ROOT | grep -q 'declare -x'; then
      export KGSM_ROOT
    fi
  fi
fi

# Trap CTRL-C
trap "echo "" && exit" INT

COMMON_SCRIPT="$(find "$KGSM_ROOT" -type f -name common.sh)"

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

INSTALL_SCRIPT="$(find "$KGSM_ROOT" -type f -name install.sh)"
if [ -z "$INSTALL_SCRIPT" ]; then
  echo ">>> ERROR: Failed to load install.sh" >&2
  exit 1
fi

UPDATE_SCRIPT="$(find "$KGSM_ROOT" -type f -name update.sh)"
if [ -z "$UPDATE_SCRIPT" ]; then
  echo ">>> ERROR: Failed to load update.sh" >&2
  exit 1
fi

BACKUP_SCRIPT="$(find "$KGSM_ROOT" -type f -name backup.sh)"
if [ -z "$BACKUP_SCRIPT" ]; then
  echo ">>> ERROR: Failed to load backup.sh" >&2
  exit 1
fi

UNINSTALL_SCRIPT="$(find "$KGSM_ROOT" -type f -name uninstall.sh)"
if [ -z "$UNINSTALL_SCRIPT" ]; then
  echo ">>> ERROR: Failed to load uninstall.sh" >&2
  exit 1
fi

function _create_blueprint() {
  echo "KGSM - Create blueprint - v$VERSION"

  ("$CREATE_BLUEPRINT_SCRIPT")
}

function _install_blueprint() {
  echo "KGSM - Install blueprint - v$VERSION"
  PS3="Choose a blueprint: "

  declare -a blueprints
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

      local blueprint_abs_path="$BLUEPRINTS_SOURCE_DIR/$blueprint"
      # shellcheck disable=SC2155
      local service_name=$(cat "$blueprint_abs_path" | grep "SERVICE_NAME=" | cut -d "=" -f2 | tr -d '"')
      local install_dir=""

      while true; do
        read -rp "Install directory: " install_dir

        # If the path doesn't contain the service name, append it
        if [[ "$install_dir" != *$service_name ]]; then
          if [[ "$install_dir" == *\/ ]]; then
            install_dir="${install_dir}${service_name}"
          else
            install_dir="$install_dir/$service_name"
          fi
        fi

        if [ ! -d "$install_dir" ]; then
          if ! mkdir -p "$install_dir"; then
            echo ">>> ERROR: Failed to create directory $install_dir" >&2
          fi
        fi

        if [ -w "$install_dir" ]; then
          break
        else
          echo ">>> ERROR: You don't have write permissions for $install_dir, specify a differente directory" >&2
        fi
      done

      # If SERVICE_WORKING_DIR already exists in the blueprint, replace the value
      if cat "$blueprint_abs_path" | grep -q "SERVICE_WORKING_DIR="; then
        sed -i "/SERVICE_WORKING_DIR=*/c\SERVICE_WORKING_DIR=\"$install_dir\"" "$blueprint_abs_path" >/dev/null
      # Othwewise just append to the blueprint
      else
        {
          echo ""
          echo "# Directory where service is installed"
          echo "SERVICE_WORKING_DIR=\"$install_dir\""
        } >>"$blueprint_abs_path"
      fi

      ("$INSTALL_SCRIPT" "$blueprint")
      ("$UPDATE_SCRIPT" "$service_name")
      return
    fi
  done
}

function _run_install() {
  echo "KGSM - Install - v$VERSION"

  declare -a services
  get_services services

  # shellcheck disable=SC2155
  local choice=$(choose_service services)

  ("$UPDATE_SCRIPT" "$choice")
}

function _check_for_update() {
  echo "KGSM - Check for update - v$VERSION"

  declare -a services
  get_installed_services services

  # shellcheck disable=SC2155
  local choice=$(choose_service services)

  ("$VERSION_CHECK_SCRIPT" "$choice")
}

function _create_backup() {
  echo "KGSM - Create backup - v$VERSION"
  PS3="Choose a service: "

  declare -a services
  get_installed_services services

  # shellcheck disable=SC2155
  local choice=$(choose_service services)

  ("$BACKUP_SCRIPT" "$choice" --create)
}

function _restore_backup() {
  echo "KGSM - Restore backup - v$VERSION"
  PS3="Choose a service: "

  declare -a services
  get_services services

  # shellcheck disable=SC2155
  local choice=$(choose_service services)

  ("$BACKUP_SCRIPT" "$choice" --restore)
}

function _uninstall() {
  echo "KGSM - Uninstall - v$VERSION"
  PS3="Choose a service: "

  declare -a services
  get_installed_services services

  if [ "${#services[@]}" -eq 0 ]; then
    echo "INFO: No services installed" >&2
    return
  fi

  # shellcheck disable=SC2155
  local choice=$(choose_service services)

  ("$UNINSTALL_SCRIPT" "$choice")
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
    # shellcheck disable=SC2002
    service_name=$(cat "$BLUEPRINTS_SOURCE_DIR/$bp" | grep "SERVICE_NAME=" | cut -d "=" -f2 | tr -d '"')
    # shellcheck disable=SC2002
    service_working_dir=$(cat "$BLUEPRINTS_SOURCE_DIR/$bp" | grep "SERVICE_WORKING_DIR=" | cut -d "=" -f2 | tr -d '"')

    # If there's no $service_working_dir, skip
    if [ ! -d "$service_working_dir" ]; then
      continue
    fi

    ref_services_array+=("$service_name")
  done
}

function get_installed_services() {
  # shellcheck disable=SC2178
  local -n ref_services_array=$1
  declare -a blueprints=()
  get_blueprints blueprints

  for bp in "${blueprints[@]}"; do
    service_name=$(cat "$BLUEPRINTS_SOURCE_DIR/$bp" | grep "SERVICE_NAME=" | cut -d "=" -f2 | tr -d '"')
    service_working_dir=$(cat "$BLUEPRINTS_SOURCE_DIR/$bp" | grep "SERVICE_WORKING_DIR=" | cut -d "=" -f2 | tr -d '"')
    service_version_file="$service_working_dir/$service_name.version"

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
    if [ -z "$service_version" ] || [[ "$service_version" == "0" ]]; then
      continue
    fi

    ref_services_array+=("$service_name")
  done
}

function init() {
  echo "KGSM - Main menu - v$VERSION"
  echo "Press CTRL+C to exit at any time."
  PS3="Choose an action: "

  declare -A services=()
  get_installed_services services

  declare -a menu_options=(
    "Create new blueprint"
    "Install"
    "Run Install"
    "Check for update"
    "Create backup"
    "Restore backup"
    "Uninstall"
  )

  declare -A menu_options_functions=(
    ["Create new blueprint"]=_create_blueprint
    ["Install"]=_install_blueprint
    ["Run Install"]=_run_install
    ["Check for update"]=_check_for_update
    ["Create backup"]=_create_backup
    ["Restore backup"]=_restore_backup
    ["Uninstall"]=_uninstall
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
