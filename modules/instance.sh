#!/bin/bash

function usage() {
  echo "
Options:
  --create <blueprint>
    --install-dir <install_dir>   Creates a new instance for the given blueprint
                                  and returns the name of the instance config
                                  file.
                                  <blueprint> The blueprint file to create an
                                  instance from.
                                  <install_dir> Directory where the instance
                                  will be created.

  --uninstall <instance>          Remove an instance's configuration
"
}

set -eo pipefail

# shellcheck disable=SC2199
if [[ $@ =~ "--debug" ]]; then
  export PS4='+(\033[0;33m${BASH_SOURCE}:${LINENO}\033[0m): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
  set -x
  for a; do
    shift
    case $a in
    --debug) continue ;;
    *) set -- "$@" "$a" ;;
    esac
  done
fi

[[ $# -eq 0 ]] && usage && exit 1

# Read the argument values
while [[ "$#" -gt 0 ]]; do
  case $1 in
  -h | --help)
    usage && exit 0
    ;;
  *)
    break
    ;;
  esac
done

# Check for KGSM_ROOT env variable
if [ -z "$KGSM_ROOT" ]; then
  echo "WARNING: KGSM_ROOT not found, sourcing /etc/environment." >&2
  # shellcheck disable=SC1091
  source /etc/environment
  [[ -z "$KGSM_ROOT" ]] && echo "${0##*/} ERROR: KGSM_ROOT not found, exiting." >&2 && exit 1
  echo "INFO: KGSM_ROOT found in /etc/environment, consider rebooting the system" >&2
  if ! declare -p KGSM_ROOT | grep -q 'declare -x'; then export KGSM_ROOT; fi
fi

# Read configuration file
if [ -z "$KGSM_CONFIG_LOADED" ]; then
  CONFIG_FILE="$(find "$KGSM_ROOT" -type f -name config.ini)"
  [[ -z "$CONFIG_FILE" ]] && echo "${0##*/} ERROR: Failed to load config.ini file" >&2 && exit 1
  while IFS= read -r line || [ -n "$line" ]; do
    # Ignore comment lines and empty lines
    if [[ "$line" =~ ^#.*$ ]] || [[ -z "$line" ]]; then continue; fi
    export "${line?}"
  done <"$CONFIG_FILE"
  export KGSM_CONFIG_LOADED=1
fi

# Trap CTRL-C
trap "echo "" && exit" INT

COMMON_SCRIPT="$(find "$KGSM_ROOT" -type f -name common.sh)"
[[ -z "$COMMON_SCRIPT" ]] && echo "${0##*/} ERROR: Failed to load common.sh" >&2 && exit 1

# shellcheck disable=SC1090
source "$COMMON_SCRIPT" || exit 1

function _create_instance() {
  local blueprint=$1
  local install_dir=$2

  if [[ "$blueprint" != *.bp ]]; then
    blueprint=${blueprint}.bp
  fi

  # shellcheck disable=SC2155
  local blueprint_abs_path="$(find "$BLUEPRINTS_SOURCE_DIR" -type f -name "$blueprint" -print -quit)"
  [[ -z "$blueprint_abs_path" ]] && echo "${0##*/} ERROR: Failed to load blueprint: $blueprint" >&2 && return 1

  # shellcheck disable=SC2155
  local service_name=$(grep "SERVICE_NAME=" <"$blueprint_abs_path" | cut -d "=" -f2 | tr -d '"')

  # shellcheck disable=SC2155
  export instance_id=$(tr -dc 0-9 </dev/urandom | head -c "${INSTANCE_RANDOM_CHAR_COUNT:-6}")
  export instance_name=$service_name
  export instance_full_name=$service_name-$instance_id
  # shellcheck disable=SC2155
  export instance_port=$(grep "SERVICE_PORT=" <"$blueprint_abs_path" | cut -d "=" -f2 | tr -d '"')
  export instance_blueprint_file=$blueprint_abs_path
  # shellcheck disable=SC2155
  local instance_launch_bin=$(grep "SERVICE_LAUNCH_BIN=" <"$blueprint_abs_path" | cut -d "=" -f2 | tr -d '"')

  # Servers launching using java
  if [[ "$instance_launch_bin" != "java" ]]; then
    instance_launch_bin="./${instance_launch_bin}"
  fi

  export instance_launch_bin

  # NOTE: cut -d "=" -f2-
  # The extra - after -f2 is necessary to get everything, otherwise it will cut
  # again if it finds the delimiter, extra - means cut after first until the end
  # shellcheck disable=SC2155
  export instance_launch_args="$(grep "SERVICE_LAUNCH_ARGS=" <"$blueprint_abs_path" | cut -d "=" -f2-)"
  # shellcheck disable=SC2155
  export instance_level_name=$(grep "SERVICE_LEVEL_NAME=" <"$blueprint_abs_path" | cut -d "=" -f2 | tr -d '"')

  export instance_working_dir=$install_dir/$instance_full_name

  # shellcheck disable=SC2155
  export instance_install_datetime=\"$(exec date +"%Y-%m-%d %T")\"
  export instance_manage_file=$install_dir/$instance_full_name/$instance_full_name.manage.sh
  if [ -n "$USE_SYSTEMD" ] && [ "$USE_SYSTEMD" -eq 1 ]; then
    [[ -z "$SYSTEMD_DIR" ]] && echo "${0##*/} ERROR: USE_SYSTEMD is enabled but SYSTEMD_DIR is not set" >&2 && return 1

    export instance_systemd_service_file=$SYSTEMD_DIR/$instance_full_name.service
    export instance_systemd_socket_file=$SYSTEMD_DIR/$instance_full_name.socket
  fi
  if [ -n "$USE_UFW" ] && [ "$USE_UFW" -eq 1 ]; then
    [[ -z "$UFW_RULES_DIR" ]] && echo "${0##*/} ERROR: USE_UFW is enabled but UFW_RULES_DIR is not set" >&2 && return 1

    export instance_ufw_file=$UFW_RULES_DIR/kgsm-$instance_full_name
  fi

  local instance_template_file=$TEMPLATES_SOURCE_DIR/instance.tp
  [[ ! -f "$instance_template_file" ]] && echo "${0##*/} ERROR: Failed to locate instance template file" >&2 && return 1

  local instance_dir_path=$INSTANCES_SOURCE_DIR/$service_name
  if [ ! -d "$instance_dir_path" ]; then
    if ! mkdir -p "$instance_dir_path"; then
      echo "${0##*/} ERROR: Failed to create $instance_dir_path" >&2 && return 1
    fi
  fi

  local instance_config_file=$INSTANCES_SOURCE_DIR/$service_name/$instance_full_name.ini

  if ! eval "cat <<EOF
$(<"$instance_template_file")
EOF
" >"$instance_config_file" 2>/dev/null; then
    echo "${0##*/} ERROR: Could not create instance file $instance_config_file" >&2 && return 1
  fi

  # shellcheck disable=SC2155
  local service_app_id=$(grep "SERVICE_APP_ID=" <"$blueprint_abs_path" | cut -d "=" -f2 | tr -d '"')
  # shellcheck disable=SC2155
  local is_steam_account_needed=$(grep "SERVICE_STEAM_AUTH_LEVEL=" <"$blueprint_abs_path" | cut -d "=" -f2 | tr -d '"')

  if [[ $service_app_id -ne 0 ]]; then
    if grep -q "INSTANCE_APP_ID=" <"$instance_config_file"; then
      sed -i "/INSTANCE_APP_ID=*/c\INSTANCE_APP_ID=$service_app_id" "$instance_config_file" >/dev/null
    else
      {
        echo ""
        echo "# Steam APP_ID"
        echo "INSTANCE_APP_ID=$service_app_id"
      } >>"$instance_config_file"
    fi

    if [[ -n "$is_steam_account_needed" ]]; then
      if grep -q "INSTANCE_STEAM_ACCOUNT_NEEDED=" <"$instance_config_file"; then
        sed -i "/INSTANCE_STEAM_ACCOUNT_NEEDED=*/c\INSTANCE_STEAM_ACCOUNT_NEEDED=$is_steam_account_needed" "$instance_config_file" >/dev/null
      else
        {
          echo ""
          echo "# If a Steam account is needed for downloading"
          echo "# Values:"
          echo "#   0 (false)"
          echo "#   1 (true)"
          echo "INSTANCE_STEAM_ACCOUNT_NEEDED=$is_steam_account_needed"
        } >>"$instance_config_file"
      fi
    fi
  fi

  # shellcheck disable=SC2155
  export instance_stop_command=$(grep "SERVICE_SOCKET_STOP_COMMAND=" <"$blueprint_abs_path" | cut -d "=" -f2 | tr -d '"')
  if [[ -n "$instance_stop_command" ]]; then
    if grep -q "INSTANCE_STOP_COMMAND=" <"$instance_config_file"; then
      sed -i "/INSTANCE_STOP_COMMAND=*/c\INSTANCE_STOP_COMMAND=$instance_stop_command" "$instance_config_file" >/dev/null
    else
      {
        echo ""
        echo "# Stop command sent to the console"
        echo "INSTANCE_STOP_COMMAND=$instance_stop_command"
      } >>"$instance_config_file"
    fi
  fi

  # shellcheck disable=SC2155
  export instance_save_command=$(grep "SERVICE_SOCKET_SAVE_COMMAND=" <"$blueprint_abs_path" | cut -d "=" -f2 | tr -d '"')
  if [[ -n "$instance_save_command" ]]; then
    if grep -q "INSTANCE_SAVE_COMMAND=" <"$instance_config_file"; then
      sed -i "/INSTANCE_SAVE_COMMAND=*/c\INSTANCE_SAVE_COMMAND=$instance_save_command" "$instance_config_file" >/dev/null
    else
      {
        echo ""
        echo "# Save command sent to the console"
        echo "INSTANCE_SAVE_COMMAND=$instance_save_command"
      } >>"$instance_config_file"
    fi
  fi

  echo "$instance_full_name" >&1
}

function _uninstall() {
  local instance=$1
  if [[ "$instance" != *.ini ]]; then
    instance="${instance}.ini"
  fi

  instance_abs_path="$(find "$KGSM_ROOT" -type f -name "$instance")"
  [[ -z "$instance_abs_path" ]] && echo "${0##*/} ERROR: Could not find $instance" >&2 && return 1

  if ! rm "$instance_abs_path"; then
    echo "${0##*/} ERROR: Failed to remove $instance_abs_path" >&2 && return 1
  fi

  return 0
}

function _print_info() {
  local instance=$1

  if [[ $instance != *.ini ]]; then
    instance="${instance}.ini"
  fi

  instance_config_file="$(find "$KGSM_ROOT" -type f -name "$instance")"
  [[ -z "$instance_config_file" ]] && echo "${0##*/} ERROR: Could not find $instance" >&2 && return 1

  # shellcheck disable=SC1090
  source "$instance_config_file" || return 1

  {
    echo "Instance:            $INSTANCE_FULL_NAME"

    local status=""
    if [[ "$USE_SYSTEMD" -eq 1 ]]; then
      status=$(systemctl is-active "$INSTANCE_FULL_NAME")
    else
      status=$([[ -f "$INSTANCE_PID_FILE" ]] && echo "active" || echo "inactive")
    fi

    echo "Status:              $status"

    if [[ -f "$INSTANCE_PID_FILE" ]]; then
    echo "PID:                 $(cat "$INSTANCE_PID_FILE")"
    fi
    if [[ "$USE_SYSTEMD" -eq 0 ]]; then
    echo "Logs directory:      $INSTANCE_LOGS_DIR"
    fi
    echo "Directory:           $INSTANCE_WORKING_DIR"
    echo "Installation date:   $INSTANCE_INSTALL_DATETIME"
    echo "Version:             $INSTANCE_INSTALLED_VERSION"
    echo "Blueprint:           $INSTANCE_BLUEPRINT_FILE"

    if [[ "$USE_SYSTEMD" -eq 1 ]]; then
      if [[ -f "$INSTANCE_SYSTEMD_SERVICE_FILE" ]]; then
        echo "Service file:        $INSTANCE_SYSTEMD_SERVICE_FILE"
      fi
      if [[ -n "$INSTANCE_SOCKET_FILE" ]]; then
        echo "Socket file:        $INSTANCE_SOCKET_FILE"
      fi
    fi

  } >&1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --create)
    blueprint=
    install_dir=
    shift
    [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument <blueprint>" && exit 1
    blueprint=$1
    shift
    case "$1" in
    --install-dir)
      shift
      [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument <install_dir>" >&2 && exit 1
      install_dir=$1
      ;;
    *) echo "${0##*/} ERROR: Invalid argument $1" >&2 && exit 1 ;;
    esac
    _create_instance $blueprint $install_dir && exit $?
    ;;
  --uninstall)
    shift
    [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument <instance>" >&2 && exit 1
    _uninstall "$1" && exit $?
    ;;
  --print-info)
    shift
    [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument <instance>" >&2 && exit 1
    _print_info "$1"
    ;;
  *) echo "${0##*/} ERROR: Invalid argument $1" >&2 && exit 1 ;;
  esac
  shift
done
