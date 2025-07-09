#!/usr/bin/env bash

# shellcheck disable=SC1091
source "$(dirname "$(readlink -f "$0")")/../lib/bootstrap.sh"

function usage() {
  local UNDERLINE="\e[4m"
  local END="\e[0m"

  echo -e "${UNDERLINE}Systemd Service Lifecycle Management for KGSM${END}

Controls game server instances that are managed through systemd services.

${UNDERLINE}Usage:${END}
  $(basename "$0") [OPTIONS] <instance>

${UNDERLINE}Options:${END}
  -h, --help                      Display this help information

${UNDERLINE}Service Management:${END}
  --start <instance>              Start the systemd service for the game server
                                  Uses systemctl start command
  --stop <instance>               Stop the systemd service gracefully
                                  Uses systemctl stop command
  --restart <instance>            Restart the systemd service
                                  Uses systemctl restart command

${UNDERLINE}Monitoring:${END}
  --logs <instance>               Display the service logs through journalctl
    [--follow]                    Continuously monitor new log entries in real-time
  --is-active <instance>          Check if the systemd service is active
                                  Uses systemctl is-active command

${UNDERLINE}Examples:${END}
  $(basename "$0") --start valheim-03
  $(basename "$0") --logs factorio-space-age-01 --follow
  $(basename "$0") --restart minecraft-survival
"
}

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

[[ "$EUID" -ne 0 ]] && SUDO="sudo -E"

module_events=$(__find_module events.sh)

function _start_instance() {
  local instance=$1

  $SUDO systemctl start "${instance%.ini}" --no-pager

  "$module_events" --emit --instance-started "${instance%.ini}" "$instance_lifecycle_manager"
}

function _stop_instance() {
  local instance=$1

  $SUDO systemctl stop "${instance%.ini}" --no-pager

  "$module_events" --emit --instance-stopped "${instance%.ini}" "$instance_lifecycle_manager"
}

function _restart_instance() {
  local instance=$1

  _stop_instance "$instance"
  _start_instance "$instance"
}

function _is_instance_active() {
  local instance=$1

  local is_active
  is_active=$(systemctl is-active "${instance%.ini}" --no-pager)
  [[ "$is_active" == "active" ]] && return 0
  return 1
}

function _get_logs() {
  local instance=$1
  local follow=${2:-false}

  if [[ "$follow" == "true" ]]; then
    journalctl -fu "${instance%.ini}"
  else
    journalctl -n 10 -u "${instance%.ini}" --no-pager
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --logs | --is-active | --start | --stop | --restart)
    command=$1
    shift
    [[ -z "$1" ]] && __print_error "Missing argument <instance>" && exit $EC_MISSING_ARG
    instance=$1
    case "$command" in
    --logs)
      shift
      follow="false"
      if [[ "$1" == "--follow" || "$1" == "-f" ]]; then
        follow="true"
        shift
      fi
      _get_logs "$instance" "$follow"
      ;;
    --is-active)
      _is_instance_active "$instance"
      exit $?
      ;;
    --start)
      _start_instance "$instance"
      exit $?
      ;;
    --stop)
      _stop_instance "$instance"
      exit $?
      ;;
    --restart)
      _restart_instance "$instance"
      exit $?
      ;;
    *)
      __print_error "Invalid argument $1"
      exit $EC_INVALID_ARG
      ;;
    esac
    ;;
  *)
    __print_error "Invalid argument $1"
    exit $EC_INVALID_ARG
    ;;
  esac
  shift
done

exit $?
