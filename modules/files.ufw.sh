#!/usr/bin/env bash

set -eo pipefail

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

function usage() {
  echo "Usage: $(basename "$0") [OPTION]... [COMMAND] [FLAGS]

Manage UFW firewall rules for game server instances.

Options:
  -h, --help                  Display this help and exit
  -i, --instance=INSTANCE     Specify the instance name (without .ini extension)
                              Equivalent to instance_name in the config

Commands:
  --install                   Generate and enable UFW firewall rule
  --uninstall                 Remove UFW firewall rules

Examples:
  $(basename "$0") --instance factorio-space-age --install
  $(basename "$0") -i 7dtd-32 --uninstall
"
}

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

if [ "$#" -eq 0 ]; then usage && return 1; fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
  -h | --help)
    usage && exit 0
    ;;
  -i | --instance)
    shift
    [[ -z "$1" ]] && echo "${0##*/} ERROR: Missing argument <instance>" >&2 && exit 1
    instance=$1
    ;;
  *)
    break
    ;;
  esac
  shift
done

SELF_PATH="$(dirname "$(readlink -f "$0")")"

# Check for KGSM_ROOT
if [ -z "$KGSM_ROOT" ]; then
  while [[ "$SELF_PATH" != "/" ]]; do
    [[ -f "$SELF_PATH/kgsm.sh" ]] && KGSM_ROOT="$SELF_PATH" && break
    SELF_PATH="$(dirname "$SELF_PATH")"
  done
  [[ -z "$KGSM_ROOT" ]] && echo "Error: Could not locate kgsm.sh. Ensure the directory structure is intact." && exit 1
  export KGSM_ROOT
fi

if [[ ! "$KGSM_COMMON_LOADED" ]]; then
  module_common="$(find "$KGSM_ROOT/modules" -type f -name common.sh -print -quit)"
  [[ -z "$module_common" ]] && echo "${0##*/} ERROR: Failed to load module common.sh" >&2 && exit 1
  # shellcheck disable=SC1090
  source "$module_common" || exit 1
fi

function _ufw_uninstall() {

  __print_info "Removing UFW integration..."

  [[ -z "$config_firewall_rules_dir" ]] && __print_error "config_firewall_rules_dir is expected but it's not set" && return "$EC_MISSING_ARG"
  [[ -z "$instance_ufw_file" ]] && return 0
  [[ ! -f "$instance_ufw_file" ]] && return 0

  # Remove ufw rule
  __print_info "Deleting UFW rule"
  if ! $SUDO ufw delete allow "$instance_name" &>/dev/null; then
    __print_error "Failed to remove UFW rule for $instance_name"
    return $EC_UFW
  fi

  if [ -f "$instance_ufw_file" ]; then
    # Delete firewall rule file
    __print_info "Deleting rule definition file"
    if ! $SUDO rm "$instance_ufw_file"; then
      __print_error "Failed to remove $instance_ufw_file"
      return $EC_FAILED_RM
    fi
  fi

  # Remove UFW entries from the instance config file
  __add_or_update_config "$instance_config_file" "instance_enable_firewall_management" "false"
  __remove_config "$instance_config_file" "instance_ufw_file"

  # Management file might have been deleted already if the instance is in the
  # process of being uninstalled.
  if [[ -f "$instance_management_file" ]]; then
    # Remove the firewall rule file path from the management file
    __remove_config "$instance_management_file" "instance_enable_firewall_management"
    __remove_config "$instance_management_file" "instance_ufw_file"
  fi

  __print_success "UFW integration removed"

  return 0
}

function _ufw_install() {

  __print_info "Adding UFW integration..."

  if [[ -z "$config_firewall_rules_dir" ]]; then
    __print_error "'firewall_rules_dir' is expected but it's not set"
    return $EC_MISSING_ARG
  fi

  local instance_ufw_file=${config_firewall_rules_dir}/kgsm-${instance_name}
  local temp_ufw_file=/tmp/kgsm-${instance_name}

  # If firewall rule file already exists, remove it
  if [[ -f "$instance_ufw_file" ]]; then
    __print_error "A UFW rule definition file for this instance already exists at '${instance_ufw_file}'. Manually remove it before trying again"
    return $EC_GENERAL
  fi

  # shellcheck disable=SC2155
  local ufw_template_file="$(__find_template ufw.tp)"

  __print_info "Creating UFW rule definition file"
  # Create firewall rule file from template
  if ! eval "cat <<EOF
$(<"$ufw_template_file")
EOF
" >"$temp_ufw_file"; then
    __print_error "Failed writing rules to $temp_ufw_file" && return "$EX_FAILED_TEMPLATE"
  fi

  if ! $SUDO mv "$temp_ufw_file" "$instance_ufw_file"; then
    __print_error "Failed to move $temp_ufw_file into $instance_ufw_file" && return "$EC_FAILED_MV"
  fi

  # UFW expect the rule file to belong to root
  if ! $SUDO chown root:root "$instance_ufw_file"; then
    __print_error "Failed to assign root user ownership to $instance_ufw_file" && return "$EC_PERMISSION"
  fi

  # Enable firewall rule
  __print_info "Allowing UFW rule"
  if ! $SUDO ufw allow "$instance_name" &>/dev/null; then
    __print_error "Failed to allow UFW rule for $instance_name" && return "$EC_UFW"
  fi

  # Enable firewall management in the instance config file
  __add_or_update_config "$instance_config_file" "instance_enable_firewall_management" "true"
  __add_or_update_config "$instance_config_file" "instance_ufw_file" \""$instance_ufw_file"\"

  local marker="=== END INJECT CONFIG ==="
  __add_or_update_config "$instance_management_file" "instance_enable_firewall_management" "true" "$marker"
  __add_or_update_config "$instance_management_file" "instance_ufw_file" \""$instance_ufw_file"\" "$marker"

  __print_success "UFW integration complete"

  return 0
}

# Load the instance configuration
instance_config_file=$(__find_instance_config "$instance")
# shellcheck disable=SC1090
source "$instance_config_file" || exit $EC_FAILED_SOURCE

[[ "$EUID" -ne 0 ]] && SUDO="sudo -E"

while [ $# -gt 0 ]; do
  case "$1" in
  --install)
    _ufw_install
    exit $?
    ;;
  --uninstall)
    _ufw_uninstall
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
