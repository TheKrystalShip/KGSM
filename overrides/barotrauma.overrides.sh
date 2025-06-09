#!/usr/bin/env bash

################################################################################
# Uncomment and use any of the following functions, they will be used to
# override the default function when generating a instance's management file
################################################################################
#
# Brief description of each:
#
# INPUT:
# - void
#
# OUTPUT:
# - echo "$version": Success
# - exit 1: Error
# _get_latest_version           Should always return the latest available
#                               version, or 1 in case there's any problem.
#
# INPUT:
# - $1: Version
#
# OUTPUT:
# - exit 0: Success
# - exit 1: Error
# _download                     In charge of downloading all the required files
#                               for the service, extract any zips, move, copy,
#                               rename, remove, etc. It should leave the $2
#                               with a fully working setup that can be called
#                               and executed as if it was a full install.
#
# INPUT:
# - void
#
# OUTPUT:
# - exit 0: Success
# - exit 1: Error
# _deploy                       Will move everything from $1 into $2 and do any
#                               cleanup that couldn't be done by func_download.
#
################################################################################
#
# Available global vars:
#
# instance_name
# instance_working_dir
# instance_install_dir
# instance_saves_dir
# instance_temp_dir
# instance_backups_dir
# instance_logs_dir
# instance_install_datetime
# instance_blueprint_file
# instance_level_name
# instance_ports
# instance_executable_file
# instance_executable_arguments
# instance_lifecycle_manager
# instance_management_file
#
# (Optional) instance_stop_command
# (Optional) instance_save_command
# (Optional) instance_pid_file
# (Optional) instance_ufw_file
# (Optional) instance_systemd_service_file
# (Optional) instance_systemd_socket_file
################################################################################

# INPUT:
# - void
#
# OUTPUT:
# - void: Success (echo "$new_version")
# - 1: Error
# function _get_latest_version() {
#   echo ""
# }

# INPUT:
# - $1: Version
#
# OUTPUT:
# - 0: Success
# - 1: Error
# function _download() {
#   local version=$1
#
#   return 0
# }

# INPUT:
# - Void
#
# OUTPUT:
# - 0: Success
# - 1: Error
function _deploy() {
  local source=${1:-$instance_temp_dir}
  local dest=${2:-$instance_install_dir}

  __print_info "Deploying $instance_name..."

  if [[ -z "$source" || -z "$dest" ]]; then
    __print_error "Source or destination directory is not set"
    return 1
  fi

  if ! cp -r "$source"/* "$dest"; then
    __print_error "Failed to copy $source into $dest"
    return 1
  fi

  if ! rm -rf "${source:?}/*"; then
    __print_error "Failed to clear $source"
    return 1
  fi

  # Ensure HOME is set to the user's home directory
  if [[ -z "$HOME" ]]; then
    __print_error "HOME environment variable is not set"
    return 1
  fi

  local config_dir="${HOME}/.local/share/Daedalic Entertainment GmbH/Barotrauma"

  # https://barotraumagame.com/wiki/Hosting_a_Dedicated_Server#Linux_Dedicated_Server_Hosting
  if ! mkdir -p "${config_dir}"; then
    __print_error "Failed to create required directory: ${config_dir}"
    return 1
  fi

  __print_success "Deployed $instance_name successfully"

  return 0
}
