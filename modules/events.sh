#!/usr/bin/env bash

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

# Disabling SC2016:
#
# This is a workaround for the fact that jq does not support single quotes in
# its syntax.
#
# We use single quotes in the data object to make it more readable.
#
# shellcheck disable=SC2016

# shellcheck disable=SC1091
source "$(dirname "$(readlink -f "$0")")/../lib/bootstrap.sh"

# Starting creation process
export EVENT_INSTANCE_CREATED="instance_created"
declare -g -r EVENT_INSTANCE_CREATED

# During creation process
export EVENT_INSTANCE_DIRECTORIES_CREATED="instance_directories_created"
declare -g -r EVENT_INSTANCE_DIRECTORIES_CREATED
export EVENT_INSTANCE_FILES_CREATED="instance_files_created"
declare -g -r EVENT_INSTANCE_FILES_CREATED

export EVENT_INSTANCE_DOWNLOAD_STARTED="instance_download_started"
declare -g -r EVENT_INSTANCE_DOWNLOAD_STARTED
export EVENT_INSTANCE_DOWNLOAD_FINISHED="instance_download_finished"
declare -g -r EVENT_INSTANCE_DOWNLOAD_FINISHED
export EVENT_INSTANCE_DOWNLOADED="instance_downloaded"
declare -g -r EVENT_INSTANCE_DOWNLOADED

export EVENT_INSTANCE_DEPLOY_STARTED="instance_deploy_started"
declare -g -r EVENT_INSTANCE_DEPLOY_STARTED
export EVENT_INSTANCE_DEPLOY_FINISHED="instance_deploy_finished"
declare -g -r EVENT_INSTANCE_DEPLOY_FINISHED
export EVENT_INSTANCE_DEPLOYED="instance_deployed"
declare -g -r EVENT_INSTANCE_DEPLOYED

export EVENT_INSTANCE_UPDATE_STARTED="instance_update_started"
declare -g -r EVENT_INSTANCE_UPDATE_STARTED
export EVENT_INSTANCE_UPDATE_FINISHED="instance_update_finished"
declare -g -r EVENT_INSTANCE_UPDATE_FINISHED
export EVENT_INSTANCE_UPDATED="instance_updated"
declare -g -r EVENT_INSTANCE_UPDATED

export EVENT_INSTANCE_VERSION_UPDATED="instance_version_updated"
declare -g -r EVENT_INSTANCE_VERSION_UPDATED

# Finished creation process
export EVENT_INSTANCE_INSTALLATION_STARTED="instance_installation_started"
declare -g -r EVENT_INSTANCE_INSTALLATION_STARTED
export EVENT_INSTANCE_INSTALLATION_FINISHED="instance_installation_finished"
declare -g -r EVENT_INSTANCE_INSTALLATION_FINISHED
export EVENT_INSTANCE_INSTALLED="instance_installed"
declare -g -r EVENT_INSTANCE_INSTALLED

# Lifecycle
export EVENT_INSTANCE_STARTED="instance_started"
declare -g -r EVENT_INSTANCE_STARTED
export EVENT_INSTANCE_STOPPED="instance_stopped"
declare -g -r EVENT_INSTANCE_STOPPED
export EVENT_INSTANCE_BACKUP_CREATED="instance_backup_created"
declare -g -r EVENT_INSTANCE_BACKUP_CREATED
export EVENT_INSTANCE_BACKUP_RESTORED="instance_backup_restored"
declare -g -r EVENT_INSTANCE_BACKUP_RESTORED

# Removal process
export EVENT_INSTANCE_FILES_REMOVED="instance_files_removed"
declare -g -r EVENT_INSTANCE_FILES_REMOVED
export EVENT_INSTANCE_DIRECTORIES_REMOVED="instance_directories_removed"
declare -g -r EVENT_INSTANCE_DIRECTORIES_REMOVED
export EVENT_INSTANCE_REMOVED="instance_removed"
declare -g -r EVENT_INSTANCE_REMOVED

# Completely removed
export EVENT_INSTANCE_UNINSTALL_STARTED="instance_uninstall_started"
declare -g -r EVENT_INSTANCE_UNINSTALL_STARTED
export EVENT_INSTANCE_UNINSTALL_FINISHED="instance_uninstall_finished"
declare -g -r EVENT_INSTANCE_UNINSTALL_FINISHED
export EVENT_INSTANCE_UNINSTALLED="instance_uninstalled"
declare -g -r EVENT_INSTANCE_UNINSTALLED

function usage() {
  local UNDERLINE="\e[4m"
  local END="\e[0m"

  echo -e "${UNDERLINE}Event System Management for Krystal Game Server Manager${END}

Manages KGSM's event broadcasting system with support for multiple transport methods.

${UNDERLINE}Usage:${END}
  $(basename "$0") [OPTIONS] [COMMAND]

${UNDERLINE}Options:${END}
  -h, --help                  Display this help information

${UNDERLINE}Commands:${END}
  --status                    Show comprehensive event system status
                              Displays configuration and transport health
  --test-all                  Test all configured event transports
                              Validates socket and webhook functionality
  --test-socket               Test Unix Domain Socket transport only
  --test-webhook              Test HTTP webhook transport only

${UNDERLINE}Transport Management:${END}
  --socket COMMAND            Manage Unix Domain Socket transport
                              Use --socket --help for available commands
  --webhook COMMAND           Manage HTTP webhook transport
                              Use --webhook --help for available commands

${UNDERLINE}Event Emission:${END}
  --emit EVENT_TYPE [PARAMS]  Emit specific event types with parameters
                              Available event types:

${UNDERLINE}Instance Lifecycle Events:${END}
  --instance-created INSTANCE [BLUEPRINT]
  --instance-installation-started INSTANCE [BLUEPRINT]
  --instance-installation-finished INSTANCE [BLUEPRINT]
  --instance-installed INSTANCE [BLUEPRINT]
  --instance-started INSTANCE
  --instance-stopped INSTANCE
  --instance-removed INSTANCE
  --instance-uninstall-started INSTANCE
  --instance-uninstall-finished INSTANCE
  --instance-uninstalled INSTANCE

${UNDERLINE}Instance Creation Process:${END}
  --instance-directories-created INSTANCE
  --instance-files-created INSTANCE
  --instance-download-started INSTANCE
  --instance-download-finished INSTANCE
  --instance-downloaded INSTANCE
  --instance-deploy-started INSTANCE
  --instance-deploy-finished INSTANCE
  --instance-deployed INSTANCE

${UNDERLINE}Instance Update Process:${END}
  --instance-update-started INSTANCE
  --instance-update-finished INSTANCE
  --instance-updated INSTANCE
  --instance-version-updated INSTANCE OLD_VERSION NEW_VERSION

${UNDERLINE}Instance Backup Events:${END}
  --instance-backup-created INSTANCE SOURCE VERSION
  --instance-backup-restored INSTANCE SOURCE VERSION

${UNDERLINE}Instance Removal Process:${END}
  --instance-files-removed INSTANCE
  --instance-directories-removed INSTANCE

${UNDERLINE}Examples:${END}
  $(basename "$0") --status
  $(basename "$0") --test-all
  $(basename "$0") --socket --enable
  $(basename "$0") --webhook --test
  $(basename "$0") --webhook --configure
  $(basename "$0") --emit --instance-created mygame
  $(basename "$0") --emit --instance-started mygame
  $(basename "$0") --emit --instance-version-updated mygame 1.0.0 1.1.0

${UNDERLINE}Notes:${END}
  • Multiple transports can be enabled simultaneously
  • Each transport has independent configuration and testing
  • Use --status to verify system health after configuration changes
  • Transport-specific help available via --socket --help or --webhook --help
  • Event emission delegates to configured transport modules
  • All events include timestamp, hostname, and KGSM version metadata
"
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
  -h | --help)
    usage && exit 0
    ;;
  *)
    break
    ;;
  esac
  shift
done

if [[ "$#" -eq 0 ]]; then
  __print_error "Missing arguments"
  exit ${EC_MISSING_ARG:-1}
fi

module_events_socket="$(__find_module events.socket.sh)"
module_events_webhook="$(__find_module events.webhook.sh)"

# Show comprehensive event system status
function _show_status() {
  local BOLD="\e[1m"
  local END="\e[0m"

  echo -e "${BOLD}KGSM Event System Status${END}"
  echo "=========================="
  echo ""

  # Socket transport status
  "$module_events_socket" --status

  echo ""

  # Webhook transport status
  "$module_events_webhook" --status
}

# Test all configured transports
function _test_all() {
  # shellcheck disable=SC2154
  local socket_enabled="$config_enable_event_broadcasting"
  # shellcheck disable=SC2154
  local webhook_enabled="$config_enable_webhook_events"
  local overall_result=0

  echo "Testing all configured event transports..."
  echo ""

  if [[ "$socket_enabled" == "true" ]]; then
    echo "Testing Unix Domain Socket transport..."
    "$(__find_module events.socket.sh)" --test
    local socket_result=$?
    if [[ $socket_result -eq 0 ]]; then
      __print_success "Socket transport test passed"
    else
      __print_error "Socket transport test failed"
      overall_result=1
    fi
    echo ""
  fi

  if [[ "$webhook_enabled" == "true" ]]; then
    echo "Testing HTTP webhook transport..."
    "$(__find_module events.webhook.sh)" --test
    local webhook_result=$?
    if [[ $webhook_result -eq 0 ]]; then
      __print_success "Webhook transport test passed"
    else
      __print_error "Webhook transport test failed"
      overall_result=1
    fi
    echo ""
  fi

  if [[ "$socket_enabled" != "true" && "$webhook_enabled" != "true" ]]; then
    __print_warning "No event transports are enabled"
    __print_info "Use --socket --enable or --webhook --enable to configure transports"
    return 1
  fi

  if [[ $overall_result -eq 0 ]]; then
    __print_success "All active transports passed testing"
  else
    __print_error "One or more transport tests failed"
  fi

  return $overall_result
}

# Event type configurations
declare -A EVENT_CONFIGS=(
  ["$EVENT_INSTANCE_CREATED"]="instance blueprint"
  ["$EVENT_INSTANCE_DIRECTORIES_CREATED"]="instance"
  ["$EVENT_INSTANCE_FILES_CREATED"]="instance"
  ["$EVENT_INSTANCE_DOWNLOAD_STARTED"]="instance"
  ["$EVENT_INSTANCE_DOWNLOAD_FINISHED"]="instance"
  ["$EVENT_INSTANCE_DOWNLOADED"]="instance"
  ["$EVENT_INSTANCE_DEPLOY_STARTED"]="instance"
  ["$EVENT_INSTANCE_DEPLOY_FINISHED"]="instance"
  ["$EVENT_INSTANCE_DEPLOYED"]="instance"
  ["$EVENT_INSTANCE_UPDATE_STARTED"]="instance"
  ["$EVENT_INSTANCE_UPDATE_FINISHED"]="instance"
  ["$EVENT_INSTANCE_UPDATED"]="instance"
  ["$EVENT_INSTANCE_VERSION_UPDATED"]="instance old_version new_version"
  ["$EVENT_INSTANCE_INSTALLATION_STARTED"]="instance blueprint"
  ["$EVENT_INSTANCE_INSTALLATION_FINISHED"]="instance blueprint"
  ["$EVENT_INSTANCE_INSTALLED"]="instance blueprint"
  ["$EVENT_INSTANCE_STARTED"]="instance"
  ["$EVENT_INSTANCE_STOPPED"]="instance"
  ["$EVENT_INSTANCE_BACKUP_CREATED"]="instance source version"
  ["$EVENT_INSTANCE_BACKUP_RESTORED"]="instance source version"
  ["$EVENT_INSTANCE_FILES_REMOVED"]="instance"
  ["$EVENT_INSTANCE_DIRECTORIES_REMOVED"]="instance"
  ["$EVENT_INSTANCE_REMOVED"]="instance"
  ["$EVENT_INSTANCE_UNINSTALL_STARTED"]="instance"
  ["$EVENT_INSTANCE_UNINSTALL_FINISHED"]="instance"
  ["$EVENT_INSTANCE_UNINSTALLED"]="instance"
)

# Generic event emission function
function _emit_event() {
  local event_type="$1"
  shift
  local params=("$@")

  # Validate event type
  if [[ -z "$event_type" ]]; then
    __print_error "Event type is required"
    return 1
  fi

  # Check if event type is supported
  if [[ -z "${EVENT_CONFIGS[$event_type]}" ]]; then
    __print_error "Unsupported event type: $event_type"
    return 1
  fi

  # Parse required parameters
  local required_params=(${EVENT_CONFIGS[$event_type]})
  local param_names=()
  local param_values=()

  # Validate parameter count
  if [[ ${#params[@]} -lt ${#required_params[@]} ]]; then
    __print_error "Insufficient parameters for $event_type. Required: ${required_params[*]}"
    return 1
  fi

  # Build parameter arrays for jq
  for i in "${!required_params[@]}"; do
    local param_name="${required_params[$i]}"
    local param_value="${params[$i]}"

    # Validate required parameters
    if [[ -z "$param_value" ]]; then
      __print_error "Parameter '$param_name' is required for $event_type"
      return 1
    fi

    param_names+=("--arg" "$param_name" "$param_value")
  done

  # Generate JSON payload
  local jq_args=("${param_names[@]}"
    --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    --arg hostname "$(hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || echo "${HOSTNAME:-localhost}")"
    --arg kgsm_version "$(get_version 2>/dev/null || echo 'unknown')")

  # Build data object based on event type
  local data_object=""
  case "$event_type" in
  "$EVENT_INSTANCE_CREATED" | "$EVENT_INSTANCE_INSTALLATION_STARTED" | "$EVENT_INSTANCE_INSTALLATION_FINISHED" | "$EVENT_INSTANCE_INSTALLED")
    data_object='{
        InstanceName: $instance,
        Blueprint: $blueprint
      }'
    ;;
  "$EVENT_INSTANCE_VERSION_UPDATED")
    data_object='{
        InstanceName: $instance,
        OldVersion: $old_version,
        NewVersion: $new_version
      }'
    ;;
  "$EVENT_INSTANCE_BACKUP_CREATED" | "$EVENT_INSTANCE_BACKUP_RESTORED")
    data_object='{
        InstanceName: $instance,
        Source: $source,
        Version: $version
      }'
    ;;
  *)
    data_object='{
        InstanceName: $instance
      }'
    ;;
  esac

  local payload
  payload=$(jq -n "${jq_args[@]}" "{
    EventType: \"$event_type\",
    Data: $data_object,
    Timestamp: \$timestamp,
    Hostname: \$hostname,
    KGSMVersion: \$kgsm_version
  }")

  # Delegate to transport modules
  if [[ "$config_enable_event_broadcasting" == "true" ]]; then
    "$module_events_socket" --emit "$payload"  &
  fi

  if [[ "$config_enable_webhook_events" == "true" ]]; then
    "$module_events_webhook" --emit "$payload"  &
  fi

  wait
}

# Individual event functions (now just wrappers for backward compatibility)
function _emit_instance_created() {
  _emit_event "$EVENT_INSTANCE_CREATED" "$@"
}

function _emit_instance_directories_created() {
  _emit_event "$EVENT_INSTANCE_DIRECTORIES_CREATED" "$@"
}

function _emit_instance_files_created() {
  _emit_event "$EVENT_INSTANCE_FILES_CREATED" "$@"
}

function _emit_instance_download_started() {
  _emit_event "$EVENT_INSTANCE_DOWNLOAD_STARTED" "$@"
}

function _emit_instance_download_finished() {
  _emit_event "$EVENT_INSTANCE_DOWNLOAD_FINISHED" "$@"
}

function _emit_instance_downloaded() {
  _emit_event "$EVENT_INSTANCE_DOWNLOADED" "$@"
}

function _emit_instance_deploy_started() {
  _emit_event "$EVENT_INSTANCE_DEPLOY_STARTED" "$@"
}

function _emit_instance_deploy_finished() {
  _emit_event "$EVENT_INSTANCE_DEPLOY_FINISHED" "$@"
}

function _emit_instance_deployed() {
  _emit_event "$EVENT_INSTANCE_DEPLOYED" "$@"
}

function _emit_instance_update_started() {
  _emit_event "$EVENT_INSTANCE_UPDATE_STARTED" "$@"
}

function _emit_instance_update_finished() {
  _emit_event "$EVENT_INSTANCE_UPDATE_FINISHED" "$@"
}

function _emit_instance_updated() {
  _emit_event "$EVENT_INSTANCE_UPDATED" "$@"
}

function _emit_instance_version_updated() {
  _emit_event "$EVENT_INSTANCE_VERSION_UPDATED" "$@"
}

function _emit_instance_installation_started() {
  _emit_event "$EVENT_INSTANCE_INSTALLATION_STARTED" "$@"
}

function _emit_instance_installation_finished() {
  _emit_event "$EVENT_INSTANCE_INSTALLATION_FINISHED" "$@"
}

function _emit_instance_installed() {
  _emit_event "$EVENT_INSTANCE_INSTALLED" "$@"
}

function _emit_instance_started() {
  _emit_event "$EVENT_INSTANCE_STARTED" "$@"
}

function _emit_instance_stopped() {
  _emit_event "$EVENT_INSTANCE_STOPPED" "$@"
}

function _emit_instance_backup_created() {
  _emit_event "$EVENT_INSTANCE_BACKUP_CREATED" "$@"
}

function _emit_instance_backup_restored() {
  _emit_event "$EVENT_INSTANCE_BACKUP_RESTORED" "$@"
}

function _emit_instance_files_removed() {
  _emit_event "$EVENT_INSTANCE_FILES_REMOVED" "$@"
}

function _emit_instance_directories_removed() {
  _emit_event "$EVENT_INSTANCE_DIRECTORIES_REMOVED" "$@"
}

function _emit_instance_removed() {
  _emit_event "$EVENT_INSTANCE_REMOVED" "$@"
}

function _emit_instance_uninstall_started() {
  _emit_event "$EVENT_INSTANCE_UNINSTALL_STARTED" "$@"
}

function _emit_instance_uninstall_finished() {
  _emit_event "$EVENT_INSTANCE_UNINSTALL_FINISHED" "$@"
}

function _emit_instance_uninstalled() {
  _emit_event "$EVENT_INSTANCE_UNINSTALLED" "$@"
}

# Main argument processing
while [[ $# -gt 0 ]]; do
  case "$1" in
  --status)
    _show_status
    exit $?
    ;;
  --test-all)
    _test_all
    exit $?
    ;;
  --test-socket)
    "$(__find_module events.socket.sh)" --test
    exit $?
    ;;
  --test-webhook)
    "$(__find_module events.webhook.sh)" --test
    exit $?
    ;;
  --socket)
    shift
    "$(__find_module events.socket.sh)" "$@"
    exit $?
    ;;
  --webhook)
    shift
    "$(__find_module events.webhook.sh)" "$@"
    exit $?
    ;;
  --emit)
    shift
    [[ -z "$1" ]] && __print_error "Missing arguments" && exit $EC_MISSING_ARG
    while [[ "$#" -gt 0 ]]; do
      case "$1" in
      --instance-created)
        shift
        _emit_instance_created "$1" "$2"
        shift 2
        ;;
      --instance-directories-created)
        shift
        _emit_instance_directories_created "$1"
        shift
        ;;
      --instance-files-created)
        shift
        _emit_instance_files_created "$1"
        shift
        ;;
      --instance-download-started)
        shift
        _emit_instance_download_started "$1"
        shift
        ;;
      --instance-download-finished)
        shift
        _emit_instance_download_finished "$1"
        shift
        ;;
      --instance-downloaded)
        shift
        _emit_instance_downloaded "$1"
        shift
        ;;
      --instance-deploy-started)
        shift
        _emit_instance_deploy_started "$1"
        shift
        ;;
      --instance-deploy-finished)
        shift
        _emit_instance_deploy_finished "$1"
        shift
        ;;
      --instance-deployed)
        shift
        _emit_instance_deployed "$1"
        shift
        ;;
      --instance-update-started)
        shift
        _emit_instance_update_started "$1"
        shift
        ;;
      --instance-update-finished)
        shift
        _emit_instance_update_finished "$1"
        shift
        ;;
      --instance-updated)
        shift
        _emit_instance_updated "$1"
        shift
        ;;
      --instance-version-updated)
        shift
        _emit_instance_version_updated "$1" "$2" "$3"
        shift 3
        ;;
      --instance-installation-started)
        shift
        _emit_instance_installation_started "$1" "$2"
        shift 2
        ;;
      --instance-installation-finished)
        shift
        _emit_instance_installation_finished "$1" "$2"
        shift 2
        ;;
      --instance-installed)
        shift
        _emit_instance_installed "$1" "$2"
        shift 2
        ;;
      --instance-started)
        shift
        _emit_instance_started "$1"
        shift
        ;;
      --instance-stopped)
        shift
        _emit_instance_stopped "$1"
        shift
        ;;
      --instance-backup-created)
        shift
        _emit_instance_backup_created "$1" "$2" "$3"
        shift 3
        ;;
      --instance-backup-restored)
        shift
        _emit_instance_backup_restored "$1" "$2" "$3"
        shift 3
        ;;
      --instance-files-removed)
        shift
        _emit_instance_files_removed "$1"
        shift
        ;;
      --instance-directories-removed)
        shift
        _emit_instance_directories_removed "$1"
        shift
        ;;
      --instance-removed)
        shift
        _emit_instance_removed "$1"
        shift
        ;;
      --instance-uninstall-started)
        shift
        _emit_instance_uninstall_started "$1"
        shift
        ;;
      --instance-uninstall-finished)
        shift
        _emit_instance_uninstall_finished "$1"
        shift
        ;;
      --instance-uninstalled)
        shift
        _emit_instance_uninstalled "$1"
        shift
        ;;
      *)
        __print_error "Invalid argument $1"
        exit $EC_INVALID_ARG
        ;;
      esac
    done
    exit $?
    ;;
  *)
    __print_error "Invalid argument $1"
    exit $EC_INVALID_ARG
    ;;
  esac
  shift
done

exit $?
