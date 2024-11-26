#!/bin/bash

function usage() {
  echo "Manages instance creation and gathers information post-creation

Usage:
  $(basename "$0") OPTION

Options:
  -h, --help                      Prints this message

  --generate-id <blueprint>       Create a unique instance identifier
  --list [blueprint]              Prints a list of all instances.
  --list --detailed [blueprint]   Print a list with detailed information about
                                  instances.
  --list --json [blueprint]       Prints a JSON formatted list of instances
  --list --json --detailed        Print a list with detailed information of
      [blueprint]                 instances.
                                  Optionally a blueprint name can be provided
                                  to show only instances of that blueprint.
  --logs <instance>               Prints a constant output of an instance's logs
  --status <instance>             Return a detailed running status.
  --is-active <instance>          Check if the instance is active.
  --start <instance>              Start the instance.
  --stop <instance>               Stop the instance.
  --save <instance>               Issue the save command to the instance.
  --restart <instance>            Restart the instance.
  --input <command>               Issue a command to the instance if it has an
                                  interactive console. Displays the last 10
                                  lines of the instance log after issuing the
                                  command.
  --create <blueprint>
    --install-dir <install_dir>   Creates a new instance for the given blueprint
                                  and returns the name of the instance config
                                  file.
                                  <blueprint> The blueprint file to create an
                                  instance from.
                                  <install_dir> Directory where the instance
                                  will be created.
    --id <identifier>             Optional: Specify an instance identifier
                                  instead of using an auto-generated one.
  --remove <instance>             Remove an instance's configuration
  --info <instance>               Print a detailed description of an instance
  --info <instance> --json        Print a detailed description of an instance in
                                  JSON format.

Examples:
  $(basename "$0") --create test.bp --install-dir /opt
  $(basename "$0") --logs test-0001
  $(basename "$0") --list test.bp
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
  CONFIG_FILE="$(find "$KGSM_ROOT" -type f -name config.ini -print -quit)"
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

module_common="$(find "$KGSM_ROOT" -type f -name common.sh -print -quit)"
[[ -z "$module_common" ]] && echo "${0##*/} ERROR: Failed to load module common.sh" >&2 && exit 1

# shellcheck disable=SC1090
source "$module_common" || exit 1

function _generate_unique_instance_name() {
  local service_name="$1"
  local instance_id
  local instance_full_name

  while :; do
    instance_id=$(tr -dc 0-9 </dev/urandom | head -c "${INSTANCE_RANDOM_CHAR_COUNT:-4}")
    instance_full_name="${service_name}-${instance_id}"

    if [[ ! -f "$INSTANCES_SOURCE_DIR/$service_name/${instance_full_name}.ini" ]]; then
      echo "$instance_full_name" && return
    fi
  done
}

function _create_instance() {
  local blueprint=$1
  local install_dir=$2
  local identifier=${3:-}

  local blueprint_abs_path
  blueprint_abs_path=$(__load_blueprint "$blueprint")
  local service_name
  service_name=$(grep "BP_NAME=" <"$blueprint_abs_path" | cut -d "=" -f2 | tr -d '"')

  export instance_name=$service_name

  instance_full_name=$identifier
  if [[ -z "$instance_full_name" ]]; then
    instance_full_name=$(_generate_unique_instance_name "$service_name")

    export instance_id=${instance_full_name##*-}
  else
    if [[ -f "$INSTANCES_SOURCE_DIR/$service_name/${instance_full_name}.ini" ]]; then
      __print_error "Instance with id \"$identifier\" already exists" && return 1
    fi

    instance_full_name="${identifier}"
  fi

  export instance_full_name

  # shellcheck disable=SC2155
  export instance_port=$(grep "BP_PORT=" <"$blueprint_abs_path" | cut -d "=" -f2 | tr -d '"')
  export instance_blueprint_file=$blueprint_abs_path
  # shellcheck disable=SC2155
  local instance_launch_bin=$(grep "BP_LAUNCH_BIN=" <"$blueprint_abs_path" | cut -d "=" -f2 | tr -d '"')

  # Servers launching using java
  if [[ "$instance_launch_bin" != "java" ]]; then
    instance_launch_bin="./${instance_launch_bin}"
  fi

  export instance_launch_bin

  # NOTE: cut -d "=" -f2-
  # The extra - after -f2 is necessary to get everything, otherwise it will cut
  # again if it finds the delimiter, extra - means cut after first until the end
  # shellcheck disable=SC2155
  export instance_launch_args="$(grep "BP_LAUNCH_ARGS=" <"$blueprint_abs_path" | cut -d "=" -f2-)"
  # shellcheck disable=SC2155
  export instance_level_name=$(grep "BP_LEVEL_NAME=" <"$blueprint_abs_path" | cut -d "=" -f2 | tr -d '"')

  export instance_working_dir=$install_dir/$instance_full_name

  instance_lifecycle_manager="standalone"
  if [[ "$USE_SYSTEMD" -eq 1 ]]; then
    instance_lifecycle_manager="systemd"
  fi
  export instance_lifecycle_manager

  # shellcheck disable=SC2155
  export instance_install_datetime=\"$(date +"%Y-%m-%dT%H:%M:%S")\"
  export instance_manage_file=$install_dir/$instance_full_name/$instance_full_name.manage.sh
  if [ -n "$USE_SYSTEMD" ] && [ "$USE_SYSTEMD" -eq 1 ]; then
    [[ -z "$SYSTEMD_DIR" ]] && __print_error "USE_SYSTEMD is enabled but SYSTEMD_DIR is not set" && return 1

    export instance_systemd_service_file=$SYSTEMD_DIR/$instance_full_name.service
    export instance_systemd_socket_file=$SYSTEMD_DIR/$instance_full_name.socket
  fi
  if [ -n "$USE_UFW" ] && [ "$USE_UFW" -eq 1 ]; then
    [[ -z "$UFW_RULES_DIR" ]] && __print_error "USE_UFW is enabled but UFW_RULES_DIR is not set" && return 1

    export instance_ufw_file=$UFW_RULES_DIR/kgsm-$instance_full_name
  fi

  local instance_template_file
  instance_template_file=$(__load_template instance.tp)

  local instance_dir_path=$INSTANCES_SOURCE_DIR/$service_name
  if [ ! -d "$instance_dir_path" ]; then
    if ! mkdir -p "$instance_dir_path"; then
      __print_error "Failed to create $instance_dir_path" && return 1
    fi
  fi

  local instance_config_file=$INSTANCES_SOURCE_DIR/$service_name/$instance_full_name.ini

  if ! eval "cat <<EOF
$(<"$instance_template_file")
EOF
" >"$instance_config_file" 2>/dev/null; then
    __print_error "Could not create instance file $instance_config_file" && return 1
  fi

  # shellcheck disable=SC2155
  local service_app_id=$(grep "BP_APP_ID=" <"$blueprint_abs_path" | cut -d "=" -f2 | tr -d '"')
  # shellcheck disable=SC2155
  local is_steam_account_needed=$(grep "BP_STEAM_AUTH_LEVEL=" <"$blueprint_abs_path" | cut -d "=" -f2 | tr -d '"')

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
  export instance_stop_command=$(grep "BP_STOP_COMMAND=" <"$blueprint_abs_path" | cut -d "=" -f2 | tr -d '"')
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
  export instance_save_command=$(grep "BP_SAVE_COMMAND=" <"$blueprint_abs_path" | cut -d "=" -f2 | tr -d '"')
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

  __emit_instance_created "$instance_full_name" "$blueprint"
  echo "$instance_full_name" >&1
}

function _remove() {
  local instance=$1
  local instance_abs_path
  instance_abs_path="$(__load_instance "$instance")"

  local instance_name
  instance_name=$(grep "INSTANCE_NAME=" <"$instance_abs_path" | cut -d "=" -f2 | tr -d '"')

  # Remove instance config file
  if ! rm "$instance_abs_path"; then
    __print_error "Failed to remove $instance_abs_path" && return 1
  fi

  # Remove directory if no other instances are found
  if [ -z "$(ls -A "$INSTANCES_SOURCE_DIR/$instance_name")" ]; then
    rmdir "$INSTANCES_SOURCE_DIR/$instance_name"
  fi

  __emit_instance_removed "${instance%.ini}"
  return 0
}

function _print_info() {
  local instance=$1

  # shellcheck disable=SC1090
  source "$(__load_instance "$instance")" || return 1

  {
    echo "Name:                $INSTANCE_FULL_NAME"
    echo "Lifecycle manager:   $INSTANCE_LIFECYCLE_MANAGER"

    local status=""
    if [[ "$INSTANCE_LIFECYCLE_MANAGER" == "systemd" ]]; then
      # systemctl return exit code 3 but it gives correct response
      set +eo pipefail
      status="$(systemctl is-active "$INSTANCE_FULL_NAME")"
      set -eo pipefail
    else
      status="$([[ -f "$INSTANCE_PID_FILE" ]] && echo "active" || echo "inactive")"
    fi

    echo "Status:              $status"

    if [[ -f "$INSTANCE_PID_FILE" ]]; then
    echo "PID:                 $(cat "$INSTANCE_PID_FILE")"
    fi
    if [[ "$INSTANCE_LIFECYCLE_MANAGER" == "standalone" ]]; then
    echo "Logs directory:      $INSTANCE_LOGS_DIR"
    fi
    echo "Directory:           $INSTANCE_WORKING_DIR"
    echo "Installation date:   $INSTANCE_INSTALL_DATETIME"
    echo "Version:             $INSTANCE_INSTALLED_VERSION"
    echo "Blueprint:           $INSTANCE_BLUEPRINT_FILE"

    if [[ "$INSTANCE_LIFECYCLE_MANAGER" == "systemd" ]]; then
      if [[ -f "$INSTANCE_SYSTEMD_SERVICE_FILE" ]]; then
        echo "Service file:        $INSTANCE_SYSTEMD_SERVICE_FILE"
      fi
      if [[ -n "$INSTANCE_SOCKET_FILE" ]]; then
        echo "Socket file:         $INSTANCE_SOCKET_FILE"
      fi
    fi

    if [[ "$USE_UFW" -eq 1 ]]; then
      if [[ -f "$INSTANCE_UFW_FILE" ]]; then
        echo "Firewall rule:       $INSTANCE_UFW_FILE"
      fi
    fi

    echo ""
  } >&1
}

function _print_info_json() {
  local instance=$1

  # shellcheck disable=SC1090
  source "$(__load_instance "$instance")" || return 1

  local status=""
  if [[ "$INSTANCE_LIFECYCLE_MANAGER" == "systemd" ]]; then
    set +eo pipefail
    status="$(systemctl is-active "$INSTANCE_FULL_NAME")"
    set -eo pipefail
  else
    status="$([[ -f "$INSTANCE_PID_FILE" ]] && echo "active" || echo "inactive")"
  fi

  local pid
  pid=$( [[ -f "$INSTANCE_PID_FILE" ]] && cat "$INSTANCE_PID_FILE" || echo "None" )
  local logs_dir
  logs_dir=$( [[ "$INSTANCE_LIFECYCLE_MANAGER" == "standalone" ]] && echo "$INSTANCE_LOGS_DIR" || echo "None" )
  local service_file
  service_file=$([[ "$INSTANCE_LIFECYCLE_MANAGER" == "systemd" && -f "$INSTANCE_SYSTEMD_SERVICE_FILE" ]] && echo "$INSTANCE_SYSTEMD_SERVICE_FILE" || echo "")
  local socket_file
  socket_file=$([[ "$INSTANCE_LIFECYCLE_MANAGER" == "systemd" && -n "$INSTANCE_SOCKET_FILE" ]] && echo "$INSTANCE_SOCKET_FILE" || echo "")
  local firewall_rule
  firewall_rule=$([[ "$USE_UFW" -eq 1 && -f "$INSTANCE_UFW_FILE" ]] && echo "$INSTANCE_UFW_FILE" || echo "")

  jq -n \
    --arg instance "$INSTANCE_FULL_NAME" \
    --arg lifecycleManager "$INSTANCE_LIFECYCLE_MANAGER" \
    --arg status "$status" \
    --arg pid "$pid" \
    --arg logsDir "$logs_dir" \
    --arg directory "$INSTANCE_WORKING_DIR" \
    --arg installDate "$INSTANCE_INSTALL_DATETIME" \
    --arg version "$INSTANCE_INSTALLED_VERSION" \
    --arg blueprint "$INSTANCE_BLUEPRINT_FILE" \
    --arg serviceFile "$service_file" \
    --arg socketFile "$socket_file" \
    --arg firewallRule "$firewall_rule" \
    '{
      Name: $instance,
      LifecycleManager: $lifecycleManager,
      Status: $status,
      PID: $pid,
      LogsDirectory: $logsDir,
      Directory: $directory,
      InstallationDate: $installDate,
      Version: $version,
      Blueprint: $blueprint,
      ServiceFile: $serviceFile,
      SocketFile: $socketFile,
      FirewallRule: $firewallRule
    }'
}

function _list_instances() {
  local blueprint=${1:-}
  local detailed=${2:-}

  shopt -s extglob nullglob

  local -a instances=()
  if [[ -z "$blueprint" ]]; then
    instances=("$INSTANCES_SOURCE_DIR"/**/*.ini)
  else
    # shellcheck disable=SC2034
    instances=("$INSTANCES_SOURCE_DIR/$blueprint"/*.ini)
  fi

  # Remove trailing directories from path, leave only filename
  for i in "${!instances[@]}"; do
    # instances["$i"]=$(basename "${instances[$i]}")
    local filename
    filename="$(basename "${instances[$i]}")"

    if [[ -z "$detailed" ]]; then
      echo "${filename%.ini}"
    else
      _print_info "$(basename "${instances[$i]}")"
    fi
  done
}

function _list_instances_json() {
  local blueprint=${1:-}
  local detailed=${2:-}

  shopt -s extglob nullglob

  local -a instances=()
  if [[ -z "$blueprint" ]]; then
    instances=("$INSTANCES_SOURCE_DIR"/**/*.ini)
  else
    # shellcheck disable=SC2034
    instances=("$INSTANCES_SOURCE_DIR/$blueprint"/*.ini)
  fi

  filenames=("${instances[@]##*/}") # Remove paths
  filenames=("${filenames[@]%.ini}") # Remove extensions

  if [[ -z "$detailed" ]]; then
    jq -n --argjson instances_list "$(printf '%s\n' "${filenames[@]}" | jq -R . | jq -s .)" '$instances_list'
  else
    # Build a JSON object with instance contents
    jq -n --argjson instances_list \
      "$(for instance in "${filenames[@]}"; do
        # Get the content of an instance as JSON
        local content
        content=$(_print_info_json "${instance##*/}")
        # Skip instances with invalid content
        if [[ $? -ne 0 || -z "$content" ]]; then
          continue
        fi
        jq -n --arg key "${instance##*/}" --argjson value "$content" '{"key": $key, "value": $value}'
      done | jq -s 'from_entries')" '$instances_list'
  fi
}

function __manage_instance() {
  local instance=$1
  local action=$2
  local command=${3:-}

  instance_config_file=$(__load_instance "$instance")

  local instance_lifecycle_manager
  instance_lifecycle_manager=$(grep "INSTANCE_LIFECYCLE_MANAGER=" <"$instance_config_file" | cut -d "=" -f2 | tr -d '"')

  local instance_manage_file
  instance_manage_file=$(grep "INSTANCE_MANAGE_FILE=" <"$instance_config_file" | cut -d "=" -f2 | tr -d '"')
  [[ -z "$instance_manage_file" ]] && echo "${0##*/} ERROR: Could not find INSTANCE_MANAGE_FILE for $instance" >&2 && return 1

  local instance_copy
  instance_copy=$instance
  if [[ "$instance" == *.ini ]]; then
    instance_copy=${instance//.ini}
  fi

  local instance_is_managed_by_systemd
  if [[ "$instance_lifecycle_manager" == "systemd" ]]; then
    instance_is_managed_by_systemd=1
  fi

  case "$action" in
    start)
      if [[ "$instance_is_managed_by_systemd" ]]; then
        $SUDO systemctl start "$instance_copy" --no-pager
      else
        "$instance_manage_file" --start --background
      fi

      __emit_instance_started "${instance%.ini}" "$instance_lifecycle_manager"
    ;;
    stop)
      if [[ "$instance_is_managed_by_systemd" ]]; then
        $SUDO systemctl stop "$instance_copy" --no-pager
      else
        "$instance_manage_file" --stop
      fi

      __emit_instance_stopped "${instance%.ini}" "$instance_lifecycle_manager"
    ;;
    restart)
      if [[ "$instance_is_managed_by_systemd" ]]; then
        $SUDO systemctl stop "$instance_copy" --no-pager
        __emit_instance_stopped "${instance%.ini}" "$instance_lifecycle_manager"
        $SUDO systemctl start "$instance_copy" --no-pager
        __emit_instance_started "${instance%.ini}" "$instance_lifecycle_manager"
      else
        "$instance_manage_file" --stop
        __emit_instance_stopped "${instance%.ini}" "$instance_lifecycle_manager"
        "$instance_manage_file" --start --background
        __emit_instance_started "${instance%.ini}" "$instance_lifecycle_manager"
      fi
    ;;
    save)
      "$instance_manage_file" --save
    ;;
    input)
      [[ -z "$command" ]] && __print_error "Missing argument <command>" && return 1
      "$instance_manage_file" --input "$command"
    ;;
    status)
      if [[ "$instance_is_managed_by_systemd" ]]; then
        # systemctl status doesn't require sudo
        systemctl status "$instance_copy" --no-pager
        # systemctl status returns exit code 3, but it prints everything we need
        # so just return 0 afterwords to exit the function
        return 0
      else
        _print_info "$instance"
      fi
    ;;
    is-active)
      if [[ "$instance_is_managed_by_systemd" ]]; then
        local is_active
        is_active=$(systemctl "$action" "$instance_copy" --no-pager)
        [[ "$is_active" == "active" ]] && return 0
        return 1
      else
        set +eo pipefail
        local instance_pid_file
        instance_pid_file=$(grep "INSTANCE_PID_FILE=" <"$instance_config_file" | cut -d "=" -f2 | tr -d '"')
        set -eo pipefail
        [[ -z "$instance_pid_file" ]] && return 1
        [[ ! -f "$instance_pid_file" ]] && return 1
        [[ -n $(cat "$instance_pid_file") ]] && return 0

        return 1
      fi
    ;;
    *) __print_error "Unknown action $action" && return 1
  esac
}

function _get_logs() {
  local instance=$1

  # shellcheck disable=SC1090
  source "$(__load_instance "$instance")" || return 1

  if [[ "$INSTANCE_LIFECYCLE_MANAGER" == "systemd" ]]; then
    [[ "$instance" == *.ini ]] && instance=${instance//.ini}
    journalctl -fu "$instance"
  fi

  while true; do
    local latest_log_file
    latest_log_file="$(ls "$INSTANCE_LOGS_DIR" -t | head -1)"

    if [[ -z "$latest_log_file" ]]; then
      sleep 2
      continue
    fi

    __print_info "Following logs from $latest_log_file"

    tail -F "$INSTANCE_LOGS_DIR/$latest_log_file" &
    tail_pid=$!

    # Wait for tail process to finish or the log file to be replaced
    inotifywait -e create -e moved_to "$INSTANCE_LOGS_DIR" >/dev/null 2>&1

    # New log file detected; kill current tail and loop back to follow the new file
    kill "$tail_pid"
    __print_info "Detected new log file. Switching to the latest log..."
    sleep 1
  done
}

# shellcheck disable=SC2199
if [[ $@ =~ "--json" ]]; then
  json_format=1
  for a; do
    shift
    case $a in
    --json) continue ;;
    *) set -- "$@" "$a" ;;
    esac
  done
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
  --list)
    shift
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --detailed)
          detailed=1
        ;;
        *)
          blueprint=$1
          ;;
      esac
    shift
    done
    if [[ -z "$json_format" ]]; then
      _list_instances "$blueprint" "$detailed"; exit $?
    else
      _list_instances_json "$blueprint" "$detailed"; exit $?
    fi
    ;;
  --generate-id)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <blueprint>" && exit 1
    _generate_unique_instance_name "$1"; exit $?
    ;;
  --logs)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <instance>" && exit 1
    _get_logs "$1"; exit $?
    ;;
  --status)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <instance>" && exit 1
    __manage_instance "$1" "status"; exit $?
    ;;
  --is-active)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <instance>" && exit 1
    __manage_instance "$1" "is-active"; exit $?
    ;;
  --start)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <instance>" && exit 1
    __manage_instance "$1" "start"; exit $?
    ;;
  --stop)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <instance>" && exit 1
    __manage_instance "$1" "stop"; exit $?
    ;;
  --restart)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <instance>" && exit 1
    __manage_instance "$1" "restart"; exit $?
    ;;
  --save)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <instance>" && exit 1
    __manage_instance "$1" "save"; exit $?
    ;;
  --input)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <instance>" && exit 1
    instance=$1
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <command>" && exit 1
    command=$1
    __manage_instance "$instance" "input" "$command"; exit $?
    ;;
  --create)
    blueprint=
    install_dir=
    identifier=
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <blueprint>" && exit 1
    blueprint=$1
    shift
    if [[ -n "$1" ]]; then
      while [[ $# -ne 0 ]]; do
        case "$1" in
        --install-dir)
          shift
          [[ -z "$1" ]] && __print_error "Missing argument <install_dir>" && exit 1
          install_dir=$1
          ;;
        --id)
          shift
          [[ -z "$1" ]] && __print_error "Missing argument <id>" && exit 1
          identifier=$1
          ;;
        *) __print_error "Invalid argument $1" && exit 1 ;;
        esac
        shift
      done
    fi
    _create_instance "$blueprint" "$install_dir" $identifier; exit $?
    ;;
  --remove)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <instance>" && exit 1
    _remove "$1"; exit $?
    ;;
  --info)
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <instance>" && exit 1
    if [[ -z "$json_format" ]]; then
      _print_info "$1"; exit $?
    else
      _print_info_json "$1"; exit $?
    fi
    ;;
  *) __print_error "Invalid argument $1" && exit 1 ;;
  esac
  shift
done
