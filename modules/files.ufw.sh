#!/usr/bin/env bash

set -eo pipefail

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

function usage() {
  local UNDERLINE="\e[4m"
  local END="\e[0m"

  echo -e "${UNDERLINE}Firewall Integration for Krystal Game Server Manager${END}

Manages UFW (Uncomplicated Firewall) rules for game server instances, ensuring proper network connectivity.

${UNDERLINE}Usage:${END}
  $(basename "$0") [OPTIONS] [COMMAND]

${UNDERLINE}Options:${END}
  -h, --help                  Display this help information
  -i, --instance=INSTANCE     Specify the target instance name (without .ini extension)
                              Must match the instance_name in the configuration

${UNDERLINE}Commands:${END}
  --enable                    Enable UFW firewall integration for the instance
                              Creates UFW rules and updates instance configuration
  --disable                   Disable UFW firewall integration for the instance
                              Removes UFW rules and updates instance configuration

${UNDERLINE}Legacy Commands (deprecated):${END}
  --install                   Alias for --enable (maintained for compatibility)
  --uninstall                 Alias for --disable (maintained for compatibility)

${UNDERLINE}Examples:${END}
  $(basename "$0") --instance factorio-space-age --enable
  $(basename "$0") -i 7dtd-32 --disable
  $(basename "$0") -i factorio-space-age --uninstall

${UNDERLINE}Notes:${END}
  • --enable/--install: Creates integration and marks it as enabled
  • --disable/--uninstall: Removes integration and marks it as disabled
  • All operations require a loaded instance configuration
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

# Core function: Remove UFW integration from external systems
function __ufw_remove_external() {
  local instance_name="$1"
  local firewall_rule_file="${2:-${config_firewall_rules_dir}/kgsm-${instance_name}}"

  [[ -z "$config_firewall_rules_dir" ]] && __print_error "config_firewall_rules_dir is expected but it's not set" && return $EC_MISSING_ARG
  [[ -z "$instance_name" ]] && __print_error "instance_name is required" && return $EC_MISSING_ARG

  # Remove ufw rule (may not exist, ignore errors)
  __print_info "Deleting UFW rule"
  $SUDO ufw delete allow "$instance_name" &>/dev/null || true

  # Delete firewall rule file if it exists
  if [[ -f "$firewall_rule_file" ]]; then
    __print_info "Deleting rule definition file"
    if ! $SUDO rm "$firewall_rule_file"; then
      __print_error "Failed to remove $firewall_rule_file"
      return $EC_FAILED_RM
    fi
  fi

  return 0
}

# Core function: Create UFW integration in external systems (requires loaded instance config)
function __ufw_create_external() {

  [[ -z "$config_firewall_rules_dir" ]] && __print_error "config_firewall_rules_dir is expected but it's not set" && return $EC_MISSING_ARG
  [[ -z "$instance_name" ]] && __print_error "instance_name is required" && return $EC_MISSING_ARG

  local instance_firewall_rule_file="${config_firewall_rules_dir}/kgsm-${instance_name}"
  local temp_ufw_file="/tmp/kgsm-${instance_name}"

  # If firewall rule file already exists, remove it
  if [[ -f "$instance_firewall_rule_file" ]]; then
    __print_error "A UFW rule definition file for this instance already exists at '${instance_firewall_rule_file}'. Remove it before trying again"
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
    __print_error "Failed writing rules to $temp_ufw_file"
    return $EC_FAILED_TEMPLATE
  fi

  if ! $SUDO mv "$temp_ufw_file" "$instance_firewall_rule_file"; then
    __print_error "Failed to move $temp_ufw_file into $instance_firewall_rule_file"
    return $EC_FAILED_MV
  fi

  # UFW expect the rule file to belong to root
  if ! $SUDO chown root:root "$instance_firewall_rule_file"; then
    __print_error "Failed to assign root user ownership to $instance_firewall_rule_file"
    return $EC_PERMISSION
  fi

  # Enable firewall rule
  __print_info "Allowing UFW rule"
  if ! $SUDO ufw allow "$instance_name" &>/dev/null; then
    __print_error "Failed to allow UFW rule for $instance_name"
    return $EC_UFW
  fi

  return 0
}

# Config-dependent operation: Disable UFW and update instance config
function _ufw_disable() {

  __print_info "Disabling UFW integration..."

  [[ -z "$instance_firewall_rule_file" ]] && return 0
  [[ ! -f "$instance_firewall_rule_file" ]] && return 0

  if ! __ufw_remove_external "$instance_name" "$instance_firewall_rule_file"; then
    return $?
  fi

  # Disable firewall management in the instance config file
  __add_or_update_config "$instance_config_file" "enable_firewall_management" "false"
  __add_or_update_config "$instance_config_file" "firewall_rule_file" ""

  __print_success "UFW integration disabled"
  return 0
}

# Config-dependent operation: Enable UFW and update instance config
function _ufw_enable() {

  __print_info "Enabling UFW integration..."

  [[ -z "$config_firewall_rules_dir" ]] && __print_error "config_firewall_rules_dir is expected but it's not set" && return "$EC_MISSING_ARG"

  # If instance_firewall_rule_file is already defined, nothing to do
  if [[ -n "$instance_firewall_rule_file" ]] && [[ -f "$instance_firewall_rule_file" ]]; then
    __print_success "UFW integration already enabled"
    return 0
  fi

  local instance_firewall_rule_file="${config_firewall_rules_dir}/kgsm-${instance_name}"

  if ! __ufw_create_external; then
    return $?
  fi

  # Enable firewall management in the instance config file
  __add_or_update_config "$instance_config_file" "enable_firewall_management" "true"
  __add_or_update_config "$instance_config_file" "firewall_rule_file" "$instance_firewall_rule_file"

  __print_success "UFW integration enabled"

  return 0
}

[[ "$EUID" -ne 0 ]] && SUDO="sudo -E"

# Load instance configuration
instance_config_file=$(__find_instance_config "$instance")
# Use __source_instance to load the config with proper prefixing
__source_instance "$instance"

while [ $# -gt 0 ]; do
  case "$1" in
  --enable | --install)
    _ufw_enable
    exit $?
    ;;
  --disable | --uninstall)
    _ufw_disable
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
