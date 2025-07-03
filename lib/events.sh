#!/usr/bin/env bash

# Starting creation process
export EVENT_INSTANCE_CREATED="instance_created"

# During creation process
export EVENT_INSTANCE_DIRECTORIES_CREATED="instance_directories_created"
export EVENT_INSTANCE_FILES_CREATED="instance_files_created"

export EVENT_INSTANCE_DOWNLOAD_STARTED="instance_download_started"
export EVENT_INSTANCE_DOWNLOAD_FINISHED="instance_download_finished"
export EVENT_INSTANCE_DOWNLOADED="instance_downloaded"

export EVENT_INSTANCE_DEPLOY_STARTED="instance_deploy_started"
export EVENT_INSTANCE_DEPLOY_FINISHED="instance_deploy_finished"
export EVENT_INSTANCE_DEPLOYED="instance_deployed"

export EVENT_INSTANCE_UPDATE_STARTED="instance_update_started"
export EVENT_INSTANCE_UPDATE_FINISHED="instance_update_finished"
export EVENT_INSTANCE_UPDATED="instance_updated"

export EVENT_INSTANCE_VERSION_UPDATED="instance_version_updated"

# Finished creation process
export EVENT_INSTANCE_INSTALLATION_STARTED="instance_installation_started"
export EVENT_INSTANCE_INSTALLATION_FINISHED="instance_installation_finished"
export EVENT_INSTANCE_INSTALLED="instance_installed"

# Lifecycle
export EVENT_INSTANCE_STARTED="instance_started"
export EVENT_INSTANCE_STOPPED="instance_stopped"
export EVENT_INSTANCE_BACKUP_CREATED="instance_backup_created"
export EVENT_INSTANCE_BACKUP_RESTORED="instance_backup_restored"

# Removal process
export EVENT_INSTANCE_FILES_REMOVED="instance_files_removed"
export EVENT_INSTANCE_DIRECTORIES_REMOVED="instance_directories_removed"
export EVENT_INSTANCE_REMOVED="instance_removed"

# Completely removed
export EVENT_INSTANCE_UNINSTALL_STARTED="instance_uninstall_started"
export EVENT_INSTANCE_UNINSTALL_FINISHED="instance_uninstall_finished"
export EVENT_INSTANCE_UNINSTALLED="instance_uninstalled"

function __emit_event() {
  local event=$1
  local data=$2
  # shellcheck disable=SC2154
  local socket_file=$KGSM_ROOT/$config_event_socket_filename

  if [[ -e "$socket_file" ]]; then
    set +eo pipefail
    message=$(
      jq -n \
        --arg eventType "$event" \
        --argjson eventData "$data" \
        '{
          EventType: $eventType,
          Data: $eventData
      }'
    )

    echo "$message" | socat - UNIX-CONNECT:"$socket_file",reuseaddr &>/dev/null
    set -eo pipefail
  fi
}

export -f __emit_event

function __emit_instance_created() {
  local instance=$1
  local blueprint=$2

  __emit_event $EVENT_INSTANCE_CREATED "$(
    jq -n \
      --arg instance_name "$instance" \
      --arg blueprint "$blueprint" \
      '{
      InstanceName: $instance_name,
      Blueprint: $blueprint
    }'
  )"
}

export -f __emit_instance_created

function __emit_instance_directories_created() {
  local instance=$1

  __emit_event $EVENT_INSTANCE_DIRECTORIES_CREATED "$(
    jq -n \
      --arg instance_name "$instance" \
      '{
      InstanceName: $instance_name
    }'
  )"
}

export -f __emit_instance_directories_created

function __emit_instance_files_created() {
  local instance=$1

  __emit_event $EVENT_INSTANCE_FILES_CREATED "$(
    jq -n \
      --arg instance_name "$instance" \
      '{
      InstanceName: $instance_name
    }'
  )"
}

export -f __emit_instance_files_created

function __emit_instance_download_started() {
  local instance=$1

  __emit_event $EVENT_INSTANCE_DOWNLOAD_STARTED "$(
    jq -n \
      --arg instance_name "$instance" \
      '{
      InstanceName: $instance_name
    }'
  )"
}

export -f __emit_instance_download_started

function __emit_instance_download_finished() {
  local instance=$1

  __emit_event $EVENT_INSTANCE_DOWNLOAD_FINISHED "$(
    jq -n \
      --arg instance_name "$instance" \
      '{
      InstanceName: $instance_name
    }'
  )"
}

export -f __emit_instance_download_finished

function __emit_instance_downloaded() {
  local instance=$1

  __emit_event $EVENT_INSTANCE_DOWNLOADED "$(
    jq -n \
      --arg instance_name "$instance" \
      '{
      InstanceName: $instance_name
    }'
  )"
}

export -f __emit_instance_downloaded

function __emit_instance_deploy_started() {
  local instance=$1

  __emit_event $EVENT_INSTANCE_DEPLOY_STARTED "$(
    jq -n \
      --arg instance_name "$instance" \
      '{
      InstanceName: $instance_name
    }'
  )"
}

export -f __emit_instance_deploy_started

function __emit_instance_deploy_finished() {
  local instance=$1

  __emit_event $EVENT_INSTANCE_DEPLOY_FINISHED "$(
    jq -n \
      --arg instance_name "$instance" \
      '{
      InstanceName: $instance_name
    }'
  )"
}

export -f __emit_instance_deploy_finished

function __emit_instance_deployed() {
  local instance=$1

  __emit_event $EVENT_INSTANCE_DEPLOYED "$(
    jq -n \
      --arg instance_name "$instance" \
      '{
      InstanceName: $instance_name
    }'
  )"
}

export -f __emit_instance_deployed

function __emit_instance_update_started() {
  local instance=$1

  __emit_event $EVENT_INSTANCE_UPDATE_STARTED "$(
    jq -n \
      --arg instance_name "$instance" \
      '{
      InstanceName: $instance_name
    }'
  )"
}

export -f __emit_instance_update_started

function __emit_instance_update_finished() {
  local instance=$1

  __emit_event $EVENT_INSTANCE_UPDATE_FINISHED "$(
    jq -n \
      --arg instance_name "$instance" \
      '{
      InstanceName: $instance_name
    }'
  )"
}

export -f __emit_instance_update_finished

function __emit_instance_updated() {
  local instance=$1

  __emit_event $EVENT_INSTANCE_UPDATED "$(
    jq -n \
      --arg instance_name "$instance" \
      '{
      InstanceName: $instance_name
    }'
  )"
}

export -f __emit_instance_updated

function __emit_instance_version_updated() {
  local instance=$1
  local old_version=$2
  local new_version=$3

  __emit_event $EVENT_INSTANCE_VERSION_UPDATED "$(
    jq -n \
      --arg instance_name "$instance" \
      --arg oldVersion "$old_version" \
      --arg newVersion "$new_version" \
      '{
      InstanceName: $instance_name,
      OldVersion: $oldVersion,
      NewVersion: $newVersion
    }'
  )"
}

export -f __emit_instance_version_updated

function __emit_instance_installation_started() {
  local instance=$1
  local blueprint=$2

  __emit_event $EVENT_INSTANCE_INSTALLATION_STARTED "$(
    jq -n \
      --arg instance_name "$instance" \
      --arg blueprint "$blueprint" \
      '{
      InstanceName: $instance_name,
      Blueprint: $blueprint
    }'
  )"
}

export -f __emit_instance_installation_started

function __emit_instance_installation_finished() {
  local instance=$1
  local blueprint=$2

  __emit_event $EVENT_INSTANCE_INSTALLATION_FINISHED "$(
    jq -n \
      --arg instance_name "$instance" \
      --arg blueprint "$blueprint" \
      '{
      InstanceName: $instance_name,
      Blueprint: $blueprint
    }'
  )"
}

export -f __emit_instance_installation_finished

function __emit_instance_installed() {
  local instance=$1
  local blueprint=$2

  __emit_event $EVENT_INSTANCE_INSTALLED "$(
    jq -n \
      --arg instance_name "$instance" \
      --arg blueprint "$blueprint" \
      '{
      InstanceName: $instance_name,
      Blueprint: $blueprint
    }'
  )"
}

export -f __emit_instance_installed

function __emit_instance_started() {
  local instance=$1

  __emit_event $EVENT_INSTANCE_STARTED "$(
    jq -n \
      --arg instance_name "$instance" \
      '{ InstanceName: $instance_name }'
  )"
}

export -f __emit_instance_started

function __emit_instance_stopped() {
  local instance=$1

  __emit_event $EVENT_INSTANCE_STOPPED "$(
    jq -n \
      --arg instance_name "$instance" \
      '{ InstanceName: $instance_name }'
  )"
}

export -f __emit_instance_stopped

function __emit_instance_backup_created() {
  local instance=$1
  local source=$2
  local version=$3

  __emit_event $EVENT_INSTANCE_BACKUP_CREATED "$(
    jq -n \
      --arg instance_name "$instance" \
      --arg source "$source" \
      --arg version "$version" \
      '{
      InstanceName: $instance_name,
      Source: $source,
      Version: $version
    }'
  )"
}

export -f __emit_instance_backup_created

function __emit_instance_backup_restored() {
  local instance=$1
  local source=$2
  local version=$3

  __emit_event $EVENT_INSTANCE_BACKUP_RESTORED "$(
    jq -n \
      --arg instance_name "$instance" \
      --arg source "$source" \
      --arg version "$version" \
      '{
      InstanceName: $instance_name,
      Source: $source,
      Version: $version
    }'
  )"
}

export -f __emit_instance_backup_restored

function __emit_instance_files_removed() {
  local instance=$1

  __emit_event $EVENT_INSTANCE_FILES_REMOVED "$(
    jq -n \
      --arg instance_name "$instance" \
      '{
      InstanceName: $instance_name
    }'
  )"
}

export -f __emit_instance_files_removed

function __emit_instance_directories_removed() {
  local instance=$1

  __emit_event $EVENT_INSTANCE_DIRECTORIES_REMOVED "$(
    jq -n \
      --arg instance_name "$instance" \
      '{
      InstanceName: $instance_name
    }'
  )"
}

export -f __emit_instance_directories_removed

function __emit_instance_removed() {
  local instance=$1

  __emit_event $EVENT_INSTANCE_REMOVED "$(
    jq -n \
      --arg instance_name "$instance" \
      '{
      InstanceName: $instance_name
    }'
  )"
}

export -f __emit_instance_removed

function __emit_instance_uninstall_started() {
  local instance=$1

  __emit_event $EVENT_INSTANCE_UNINSTALL_STARTED "$(
    jq -n \
      --arg instance_name "$instance" \
      '{
      InstanceName: $instance_name
    }'
  )"
}

export -f __emit_instance_uninstall_started

function __emit_instance_uninstall_finished() {
  local instance=$1

  __emit_event $EVENT_INSTANCE_UNINSTALL_FINISHED "$(
    jq -n \
      --arg instance_name "$instance" \
      '{
      InstanceName: $instance_name
    }'
  )"
}

export -f __emit_instance_uninstall_finished

function __emit_instance_uninstalled() {
  local instance=$1

  __emit_event $EVENT_INSTANCE_UNINSTALLED "$(
    jq -n \
      --arg instance_name "$instance" \
      '{
      InstanceName: $instance_name
    }'
  )"
}

export -f __emit_instance_uninstalled

# Replace all event functions with dummy ones in order to not break the calls
if [[ "$config_enable_event_broadcasting" == "false" ]]; then
  # List all functions defined and extract function names
  declare -F |
    grep -E '^declare -f __emit_' |
    sed 's/^declare -f //g' |
    while read -r func; do
      # For each function name, create a no-op function definition
      eval "$func() { return; }"
    done
fi

export KGSM_EVENTS_LOADED=1
