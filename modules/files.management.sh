#!/usr/bin/env bash

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

# shellcheck disable=SC1091
source "$(dirname "$(readlink -f "$0")")/../lib/bootstrap.sh"

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
  --remove                    Remove the management file and the copied configuration file

${UNDERLINE}Examples:${END}
  $(basename "$0") --instance factorio-space-age --create
"
}

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

function __create_container_file_template() {
  # Fetch the container blueprint file, which will be a docker-compose file with some
  # placeholder variables that need replacing with variables from the instance config file.

  if [[ ! -f "$instance_blueprint_file" ]]; then
    __print_error "Container blueprint file '$instance_blueprint_file' does not exist."
    return $EC_FILE_NOT_FOUND
  fi

  # The instance config file should already be sourced, so we can use the variables directly
  # to create the container file template.
  # The output file must be in the same directory as the instance management file,
  # so we can use the same variables as in the instance management file.
  local container_file="${instance_working_dir}/${instance_name}.docker-compose.yml"
  if ! eval "cat <<EOF
$(<"$instance_blueprint_file")
EOF
" >"$container_file" 2>/dev/null; then
    __print_error "Could not generate $instance_blueprint_file to $container_file"
    return $EC_FAILED_TEMPLATE
  fi

  return $?
}

function _inject_management_overrides() {
  # shellcheck disable=SC1090

  # Check for function definitions and replace defaults with overrides
  __print_info "Checking for overrides..."

  # shellcheck disable=SC1090
  source "$(__find_library overrides.sh)" "$instance" || {
    __print_error "Failed to source module overrides.sh"
    return 1
  }

  # $instance_blueprint_file is the absolute path to the blueprint file, we just need the name
  local instance_bp_name
  instance_bp_name=$(basename "$instance_blueprint_file" | sed 's/\.bp$//')

  local instance_overrides_file="${OVERRIDES_SOURCE_DIR}/${instance_bp_name}.overrides.sh"
  # Check if the overrides file exists
  if [[ ! -f "$instance_overrides_file" ]]; then
    # Skip if no overrides file is found
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
    # Do nothing
    ;;
  container)
    __create_container_file_template "$instance_blueprint_file" || {
      __print_error "Failed to create container file template for $instance_blueprint_file"
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

function _remove_manage_file() {
  # Remove the management file
  if [[ -f "$instance_management_file" ]]; then
    if ! rm -f "$instance_management_file"; then
      __print_error "Failed to remove management file: $instance_management_file"
      return $EC_FAILED_RM
    fi
  fi

  return 0
}

# Load the instance configuration
instance_config_file=$(__find_instance_config "$instance")
# Use __source_instance to load the config with proper prefixing
__source_instance "$instance"

[[ "$EUID" -ne 0 ]] && SUDO="sudo -E"

while [ $# -gt 0 ]; do
  case "$1" in
  --create)
    _create_manage_file
    exit $?
    ;;
  --remove)
    _remove_manage_file
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
