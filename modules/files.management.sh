#!/usr/bin/env bash

set -eo pipefail

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

function usage() {
  local UNDERLINE="\e[4m"
  local END="\e[0m"

  echo -e "${UNDERLINE}File Management for Krystal Game Server Manager${END}

Create and manage essential files for game server instances.

${UNDERLINE}Usage:${END}
  $(basename "$0") [OPTIONS] [COMMAND]

${UNDERLINE}Options:${END}
  -h, --help                  Display this help information
  -i, --instance=INSTANCE     Specify the target instance name (without .ini extension)
                              Must match the instance_name in the configuration

${UNDERLINE}Commands:${END}
  --create                    Generate a management file for the specified instance
                              Creates necessary configuration files for proper server operation

${UNDERLINE}Examples:${END}
  $(basename "$0") --instance factorio-space-age --create
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

function __inject_native_management_variables() {
  # UPnP ports on startup & disabled them on shutdown
  export config_enable_port_forwarding

  # shellcheck disable=SC2155
  local instance_install_subdir=$(grep "blueprint_executable_subdirectory=" <"$instance_blueprint_file" | cut -d "=" -f2 | tr -d '"')

  instance_launch_dir="$instance_install_dir"
  if [[ -n "$instance_install_subdir" ]]; then
    instance_launch_dir="$instance_install_dir/$instance_install_subdir"
  fi

  # Log redirection into file happens when the instance is launched
  # as a background process.
  # The log file is named after the instance and the current date/time.
  # It is stored in the instance logs directory.
  # shellcheck disable=SC2140
  stdout_file="\$instance_logs_dir/\$instance_name-\$(date +"%Y-%m-%dT%H:%M:%S").log"
  export instance_logs_redirect="$stdout_file"

  # Avoid evaluating instance_executable_arguments as it can contain variables that need
  # to just be passed along, not evaluated
  local instance_launch_args
  instance_launch_args="$(grep "instance_executable_arguments=" <"$instance_config_file" | cut -d '"' -f2 | tr -d '"')"
  export instance_launch_args

  local injected_config
  injected_config=$(
    cat <<EOF
# Log redirection into file
instance_logs_redirect="$instance_logs_redirect"

# Directory from which to launch the instance binary
instance_launch_dir="$instance_launch_dir"

$(<"$instance_config_file")
EOF
  )

  local marker="# === BEGIN INJECT CONFIG ==="

  # Replace the marker with the injected config
  if ! sed -i "/${marker}/{
      r /dev/stdin
      d
  }" "$instance_management_file" <<<"$injected_config"; then
    __print_error "Failed to inject config into $instance_management_file"
    return $EC_FAILED_TEMPLATE
  fi

  return 0
}

function __inject_docker_management_variables() {
  local injected_config
  injected_config=$(
    cat <<EOF
$(<"$instance_config_file")
EOF
  )

  local marker="# === BEGIN INJECT CONFIG ==="

  # Replace the marker with the injected config
  if ! sed -i "/${marker}/{
      r /dev/stdin
      d
  }" "$instance_management_file" <<<"$injected_config"; then
    __print_error "Failed to inject config into $instance_management_file"
    exit $EC_FAILED_TEMPLATE
  fi

  return 0
}

function _inject_management_overrides() {
  # shellcheck disable=SC1090

  source "$(__find_module overrides.sh)" "$instance" || {
    __print_error "Failed to source module overrides.sh"
    return 1
  }

  # Check for function definitions and replace defaults with overrides
  __print_info "Checking for overrides..."

  # Overrides are located in $KGSM_ROOT/overrides/${INSTANCE_BP_NAME}.overrides.sh

  # $instance_blueprint_file is the absolute path to the blueprint file, we just need the name
  local instance_bp_name
  instance_bp_name=$(basename "$instance_blueprint_file" | sed 's/\.bp$//')

  local instance_overrides_file="${OVERRIDES_SOURCE_DIR}/${instance_bp_name}.overrides.sh"
  # Check if the overrides file exists
  if [[ ! -f "$instance_overrides_file" ]]; then
    __print_info "No overrides file found for ${instance_bp_name}, skipping."
    return 0
  fi

  # For each function name declared in the overrides file…
  grep -Po '^function \K[[:alnum:]_]+' "${instance_overrides_file}" | while read -r fn; do

    # Check if the function is defined in the overrides file
    # Since the overrides file is sourced, we can check if the function exists
    if ! declare -F "${fn}" &>/dev/null; then
      __print_warning "Function '${fn}' not found in overrides file '${instance_overrides_file}', skipping."
      continue
    fi

    func_def=$(declare -f "${fn}")

    __print_info "Found function '${fn}' in overrides file, injecting into ${instance_management_file}"

    # Create a temporary file to hold the new function body
    tmp=$(mktemp)
    printf '%s\n' "${func_def}" | sed '1 s|^|function |' >"${tmp}"

    # In-place sed:
    #   1. On the "function NAME" line, `r tmp` will read/insert the new body *below* that line.
    #   2. Then the range delete `/^function NAME.../,/^}/ d` removes the entire old block,
    #      including that matched "function" line and its closing `}`.
    #   The net effect is that your new body (from the tmp file) ends up in place of the old.
    sed -i \
      -e "/^function ${fn}[[:space:]]*(/ r ${tmp}" \
      -e "/^function ${fn}[[:space:]]*(/,/^}/ d" \
      "${instance_management_file}"

    # shellcheck disable=SC2181
    if [[ $? -ne 0 ]]; then
      __print_error "Failed to inject function '${fn}' into ${instance_management_file}"
      rm -f "${tmp}" # Clean up the temporary file
      return $EC_FAILED_TEMPLATE
    fi

    __print_success "Injected function '${fn}' into ${instance_management_file}"

    # Clean up the temporary file
    rm -f "${tmp}"
  done

  return 0
}

function _create_manage_file() {

  # Prepare source file
  local manage_template_file

  __print_info "Generating management file..."

  # Choose appropriate template based on runtime
  if ! manage_template_file="$(__find_template "manage.${instance_runtime}")"; then
    __print_error "Failed to manage template for $instance_name"
    return $EC_FILE_NOT_FOUND
  fi

  # Create the new management file
  if ! cp -f "$manage_template_file" "$instance_management_file"; then
    __print_error "Failed to generate management template for $instance_management_file"
    return $EC_FAILED_TEMPLATE
  fi

  # Inject config
  case "$instance_runtime" in
  native)
    __inject_native_management_variables || {
      __print_error "Failed to inject native management variables into $instance_management_file"
      return $EC_FAILED_TEMPLATE
    }
    ;;
  docker)
    __inject_docker_management_variables || {
      __print_error "Failed to inject docker management variables into $instance_management_file"
      return $EC_FAILED_TEMPLATE
    }
    ;;
  *)
    __print_error "Invalid instance runtime: $instance_runtime"
    return $EC_GENERAL
    ;;
  esac

  # Inject overrides
  _inject_management_overrides || {
    __print_error "Failed to inject overrides into $instance_management_file"
    return $EC_FAILED_TEMPLATE
  }

  # File permissions
  instance_user=$USER
  if [ "$EUID" -eq 0 ]; then
    instance_user=$SUDO_USER
  fi

  # Make sure file is owned by the user and not root
  if ! chown "$instance_user":"$instance_user" "$instance_management_file"; then
    __print_error "Failed to assing $instance_management_file to user $instance_user"
    return $EC_PERMISSION
  fi

  # Make sure it's executable
  if ! chmod +x "$instance_management_file"; then
    __print_error "Failed to add +x permission to $instance_management_file"
    return $EC_PERMISSION
  fi

  __print_success "Management file created"

  return 0
}

# Load the instance configuration
instance_config_file=$(__find_instance_config "$instance")
# shellcheck disable=SC1090
source "$instance_config_file" || exit $EC_FAILED_SOURCE

[[ "$EUID" -ne 0 ]] && SUDO="sudo -E"

while [ $# -gt 0 ]; do
  case "$1" in
  --create)
    _create_manage_file
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
