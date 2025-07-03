#!/usr/bin/env bash

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

debug=
# shellcheck disable=SC2199
if [[ $@ =~ "--debug" ]]; then
  debug="--debug"
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

SELF_PATH="$(dirname "$(readlink -f "$0")")"

# Absolute path to this script file
if [ -z "$KGSM_ROOT" ]; then
  while [[ "$SELF_PATH" != "/" ]]; do
    [[ -f "$SELF_PATH/kgsm.sh" ]] && KGSM_ROOT="$SELF_PATH" && break
    SELF_PATH="$(dirname "$SELF_PATH")"
  done
  [[ -z "$KGSM_ROOT" ]] && echo "Error: Could not locate kgsm.sh. Ensure the directory structure is intact." && exit 1
  export KGSM_ROOT
fi

if [[ ! "$KGSM_COMMON_LOADED" ]]; then
  module_common="$(find "$KGSM_ROOT/lib" -type f -name common.sh -print -quit)"
  [[ -z "$module_common" ]] && echo "${0##*/} ERROR: Failed to load module common.sh" >&2 && exit 1
  # shellcheck disable=SC1090
  source "$module_common" || exit 1
fi

export kgsm="$KGSM_ROOT/kgsm.sh"

# =============================================================================
# VISUAL CONSTANTS
# =============================================================================

# Color codes for better visual hierarchy
readonly COLOR_HEADER="\033[1;36m"  # Bright cyan for headers
readonly COLOR_MENU="\033[1;32m"    # Bright green for menu items
readonly COLOR_INFO="\033[0;37m"    # White for info text
readonly COLOR_WARNING="\033[1;33m" # Yellow for warnings
readonly COLOR_ERROR="\033[1;31m"   # Red for errors
readonly COLOR_SUCCESS="\033[1;32m" # Green for success
readonly COLOR_PROMPT="\033[1;35m"  # Magenta for prompts
readonly COLOR_RESET="\033[0m"      # Reset to default

# Menu navigation constants
readonly MENU_BACK="← Back"
readonly MENU_MAIN="⌂ Main Menu"
readonly MENU_QUIT="✗ Quit"
readonly MENU_HELP="? Help"

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

function __draw_box() {
  local title="$1"
  local width=${2:-75}

  # Top border
  echo -e "${COLOR_HEADER}$(printf "%*s" $width | tr ' ' '=')${COLOR_RESET}" >&2

  if [[ -n "$title" ]]; then
    local title_len=${#title}
    local padding=$(((width - title_len) / 2))
    printf "%*s${COLOR_HEADER}${title}${COLOR_RESET}\n" $padding "" >&2
    echo -e "${COLOR_HEADER}$(printf "%*s" $width | tr ' ' '=')${COLOR_RESET}" >&2
  fi
}

function __close_box() {
  local width=75
  echo -e "${COLOR_HEADER}$(printf "%*s" $width | tr ' ' '=')${COLOR_RESET}" >&2
}

function __print_menu_item() {
  local number="$1"
  local text="$2"
  local description="$3"

  printf "  ${COLOR_MENU}%s)${COLOR_RESET} %-20s" "$number" "$text" >&2
  if [[ -n "$description" ]]; then
    printf " ${COLOR_INFO}%s${COLOR_RESET}" "$description" >&2
  fi
  echo >&2
}

function __print_box_line() {
  local text="$1"
  local color="${2:-$COLOR_INFO}"
  printf "  ${color}%s${COLOR_RESET}\n" "$text" >&2
}

function __print_empty_line() {
  echo >&2
}

function __prompt_user() {
  local prompt="$1"
  local default="$2"
  local response

  echo -e "${COLOR_PROMPT}${prompt}${COLOR_RESET}" >&2
  if [[ -n "$default" ]]; then
    echo -e "${COLOR_INFO}(Press Enter for default: $default)${COLOR_RESET}" >&2
  fi
  echo -n "> " >&2
  read -r response

  if [[ -z "$response" && -n "$default" ]]; then
    echo "$default"
  else
    echo "$response"
  fi
}

function __confirm_action() {
  local message="$1"
  local response

  echo -e "${COLOR_WARNING}${message}${COLOR_RESET}" >&2
  echo -e "${COLOR_PROMPT}Are you sure? (y/N)${COLOR_RESET}" >&2
  echo -n "> " >&2
  read -r response

  [[ "$response" =~ ^[Yy]$ ]]
}

function __wait_for_key() {
  local message="${1:-Press any key to continue...}"
  echo -e "${COLOR_INFO}${message}${COLOR_RESET}" >&2
  read -n 1 -s
}

function __clear_screen() {
  # Use ANSI escape sequences for clearing screen (works better in all contexts)
  printf "\033[2J\033[H" >&2
}

# =============================================================================
# SYSTEM INFORMATION FUNCTIONS
# =============================================================================

function __get_kgsm_version() {
  "$KGSM_ROOT/installer.sh" --version $debug 2>/dev/null || echo "Unknown"
}

function __get_system_overview() {
  local instances_count blueprints_count

  # Get counts safely
  instances_count=$("$kgsm" --instances $debug 2>/dev/null | wc -l)
  blueprints_count=$("$kgsm" --blueprints $debug 2>/dev/null | wc -l)

  echo "instances:$instances_count"
  echo "blueprints:$blueprints_count"
}

function __display_system_status() {
  local overview_data
  local instances_count=0
  local blueprints_count=0

  overview_data=$(__get_system_overview)
  instances_count=$(echo "$overview_data" | grep "instances:" | cut -d: -f2)
  blueprints_count=$(echo "$overview_data" | grep "blueprints:" | cut -d: -f2)

  __draw_box "KGSM System Overview"
  __print_box_line "Version: $(__get_kgsm_version)"
  __print_box_line "Instances: $instances_count installed"
  __print_box_line "Blueprints: $blueprints_count available"
  __print_empty_line

  # Show running instances if any exist
  if [[ $instances_count -gt 0 ]]; then
    __print_box_line "Recent Instance Activity:" "$COLOR_WARNING"
    local instances
    instances=$("$kgsm" --instances $debug 2>/dev/null | head -3)
    if [[ -n "$instances" ]]; then
      while IFS= read -r instance; do
        [[ -n "$instance" ]] && __print_box_line "  • $instance"
      done <<<"$instances"
      [[ $instances_count -gt 3 ]] && __print_box_line "  ... and $((instances_count - 3)) more"
    fi
  else
    __print_box_line "No instances installed yet" "$COLOR_WARNING"
    __print_box_line "Use 'Install New Server' to get started"
  fi

  __print_empty_line
  __close_box
}

# =============================================================================
# MENU FUNCTIONS
# =============================================================================

function __show_main_menu() {
  __clear_screen
  __display_system_status
  echo

  __draw_box "Main Menu"
  __print_menu_item "1" "Server Management" "Install, start, stop, manage servers"
  __print_menu_item "2" "Information" "View blueprints, instances, status"
  __print_menu_item "3" "Maintenance" "Update, backup, restore operations"
  __print_menu_item "4" "System Tools" "Configuration and utilities"
  __print_empty_line
  __print_menu_item "h" "$MENU_HELP" "Show detailed help information"
  __print_menu_item "q" "$MENU_QUIT" "Exit KGSM Interactive Mode"
  __close_box
}

function __show_server_management_menu() {
  __clear_screen
  __draw_box "Server Management"
  __print_menu_item "1" "Install New Server" "Deploy a game server from blueprint"
  __print_menu_item "2" "Start Server" "Launch an installed server instance"
  __print_menu_item "3" "Stop Server" "Gracefully shutdown a running server"
  __print_menu_item "4" "Restart Server" "Stop and start a server instance"
  __print_menu_item "5" "Uninstall Server" "Remove a server instance completely"
  __print_menu_item "6" "Modify Server" "Change server integrations"
  __print_empty_line
  __print_menu_item "b" "$MENU_BACK" "Return to main menu"
  __print_menu_item "m" "$MENU_MAIN" "Jump to main menu"
  __print_menu_item "q" "$MENU_QUIT" "Exit KGSM"
  __close_box
}

function __show_information_menu() {
  __clear_screen
  __draw_box "Information & Monitoring"
  __print_menu_item "1" "List All Blueprints" "Show available server types"
  __print_menu_item "2" "List All Instances" "Show installed server instances"
  __print_menu_item "3" "Server Status" "Detailed status of an instance"
  __print_menu_item "4" "View Server Logs" "Show recent log entries"
  __print_empty_line
  __print_menu_item "b" "$MENU_BACK" "Return to main menu"
  __print_menu_item "m" "$MENU_MAIN" "Jump to main menu"
  __print_menu_item "q" "$MENU_QUIT" "Exit KGSM"
  __close_box
}

function __show_maintenance_menu() {
  __clear_screen
  __draw_box "Maintenance & Updates"
  __print_menu_item "1" "Check for Updates" "Check if server updates available"
  __print_menu_item "2" "Update Server" "Update a server to latest version"
  __print_menu_item "3" "Create Backup" "Backup server data and config"
  __print_menu_item "4" "Restore Backup" "Restore from a previous backup"
  __print_empty_line
  __print_menu_item "b" "$MENU_BACK" "Return to main menu"
  __print_menu_item "m" "$MENU_MAIN" "Jump to main menu"
  __print_menu_item "q" "$MENU_QUIT" "Exit KGSM"
  __close_box
}

function __show_system_tools_menu() {
  __clear_screen
  __draw_box "System Tools & Configuration"
  __print_menu_item "1" "View Configuration" "Show current KGSM settings"
  __print_menu_item "2" "System Information" "Display system details"
  __print_menu_item "3" "Update KGSM" "Update KGSM itself"
  __print_empty_line
  __print_menu_item "b" "$MENU_BACK" "Return to main menu"
  __print_menu_item "m" "$MENU_MAIN" "Jump to main menu"
  __print_menu_item "q" "$MENU_QUIT" "Exit KGSM"
  __close_box
}

# =============================================================================
# INPUT HANDLING FUNCTIONS
# =============================================================================

function __get_menu_choice() {
  local valid_choices="$1"
  local choice

  echo -e "${COLOR_PROMPT}Choose an option:${COLOR_RESET}" >&2
  echo -n "> " >&2
  read -r choice

  # Convert to lowercase for consistency
  choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

  # Validate choice - check if choice is in the space-separated list
  if [[ " $valid_choices " == *" $choice "* ]]; then
    echo "$choice" # Only the choice goes to stdout
    return 0
  else
    echo -e "${COLOR_ERROR}Invalid choice: '$choice'${COLOR_RESET}" >&2
    echo -e "${COLOR_INFO}Valid options: $valid_choices${COLOR_RESET}" >&2
    return 1
  fi
}

function __select_from_list() {
  local title="$1"
  local -n items_ref=$2
  local allow_back="${3:-true}"
  local selected_item

  if [[ ${#items_ref[@]} -eq 0 ]]; then
    echo -e "${COLOR_WARNING}No items available.${COLOR_RESET}" >&2
    __wait_for_key
    return 1
  fi

  while true; do
    __clear_screen
    __draw_box "$title"

    local i=1
    for item in "${items_ref[@]}"; do
      __print_menu_item "$i" "$item"
      ((i++))
    done

    __print_empty_line
    if [[ "$allow_back" == "true" ]]; then
      __print_menu_item "b" "$MENU_BACK" "Return to previous menu"
    fi
    __print_menu_item "q" "$MENU_QUIT" "Exit KGSM"
    __close_box

    local valid_choices="q"
    [[ "$allow_back" == "true" ]] && valid_choices="${valid_choices} b"
    for ((j = 1; j < i; j++)); do
      valid_choices="$valid_choices $j"
    done

    local choice
    if choice=$(__get_menu_choice "$valid_choices"); then
      case "$choice" in
      q) return 2 ;;                                  # Quit
      b) [[ "$allow_back" == "true" ]] && return 1 ;; # Back
      [0-9]*)
        if [[ $choice -ge 1 && $choice -lt $i ]]; then
          selected_item="${items_ref[$((choice - 1))]}"
          echo "$selected_item"
          return 0
        fi
        ;;
      esac
    fi

    __wait_for_key "Invalid selection. Press any key to try again..."
  done
}

# =============================================================================
# ACTION FUNCTIONS
# =============================================================================

function __action_install_server() {
  local blueprints
  local selected_blueprint
  local install_dir
  local version
  local instance_name

  # Get available blueprints
  mapfile -t blueprints < <("$kgsm" --blueprints $debug 2>/dev/null)

  if [[ ${#blueprints[@]} -eq 0 ]]; then
    echo -e "${COLOR_ERROR}No blueprints available.${COLOR_RESET}" >&2
    __wait_for_key
    return 1
  fi

  # Select blueprint
  selected_blueprint=$(__select_from_list "Select Blueprint to Install" blueprints)
  case $? in
  1) return 0 ;; # Back
  2) return 2 ;; # Quit
  esac

  # Get installation directory
  install_dir=${config_default_install_directory:-}
  if [[ -z "$install_dir" ]]; then
    install_dir=$(__prompt_user "Installation directory:")
    if [[ -z "$install_dir" ]]; then
      echo -e "${COLOR_ERROR}Installation directory is required.${COLOR_RESET}" >&2
      __wait_for_key
      return 1
    fi
  else
    install_dir=$(__prompt_user "Installation directory:" "$install_dir")
  fi

  # Get version (optional)
  version=$(__prompt_user "Version (leave empty for latest):")

  # Get instance name (optional)
  instance_name=$(__prompt_user "Instance name (leave empty for default):")

  # Confirm installation
  __clear_screen
  __draw_box "Installation Summary"
  __print_box_line "Blueprint: $selected_blueprint"
  __print_box_line "Directory: $install_dir"
  __print_box_line "Version: ${version:-latest}"
  __print_box_line "Name: ${instance_name:-default}"
  __close_box

  if ! __confirm_action "Proceed with installation?"; then
    echo -e "${COLOR_INFO}Installation cancelled.${COLOR_RESET}" >&2
    __wait_for_key
    return 0
  fi

  # Execute installation
  echo -e "${COLOR_INFO}Installing server instance...${COLOR_RESET}" >&2

  local cmd_args=("$kgsm" --create "$selected_blueprint" --install-dir "$install_dir")
  [[ -n "$version" ]] && cmd_args+=(--version "$version")
  [[ -n "$instance_name" ]] && cmd_args+=(--name "$instance_name")
  [[ -n "$debug" ]] && cmd_args+=("$debug")

  if "${cmd_args[@]}"; then
    echo -e "${COLOR_SUCCESS}Installation completed successfully!${COLOR_RESET}" >&2
  else
    echo -e "${COLOR_ERROR}Installation failed. Check the output above for details.${COLOR_RESET}" >&2
  fi

  __wait_for_key
}

function __action_server_operation() {
  local operation="$1"
  local operation_name="$2"
  local instances
  local selected_instance

  # Get available instances
  mapfile -t instances < <("$kgsm" --instances $debug 2>/dev/null)

  if [[ ${#instances[@]} -eq 0 ]]; then
    echo -e "${COLOR_WARNING}No server instances found.${COLOR_RESET}" >&2
    echo -e "${COLOR_INFO}Install a server first using the 'Install New Server' option.${COLOR_RESET}" >&2
    __wait_for_key
    return 1
  fi

  # Select instance
  selected_instance=$(__select_from_list "Select Instance to $operation_name" instances)
  case $? in
  1) return 0 ;; # Back
  2) return 2 ;; # Quit
  esac

  # Confirm operation for destructive actions
  if [[ "$operation" == "--uninstall" ]]; then
    if ! __confirm_action "This will permanently remove '$selected_instance' and all its data."; then
      echo -e "${COLOR_INFO}Operation cancelled.${COLOR_RESET}" >&2
      __wait_for_key
      return 0
    fi
  fi

  # Execute operation
  echo -e "${COLOR_INFO}${operation_name^} server instance...${COLOR_RESET}" >&2

  if [[ "$operation" == "--uninstall" ]]; then
    "$kgsm" --uninstall "$selected_instance" $debug
  else
    "$kgsm" --instance "$selected_instance" "$operation" $debug
  fi

  local result=$?
  if [[ $result -eq 0 ]]; then
    echo -e "${COLOR_SUCCESS}Operation completed successfully!${COLOR_RESET}" >&2
  else
    echo -e "${COLOR_ERROR}Operation failed with exit code $result.${COLOR_RESET}" >&2
  fi

  __wait_for_key
}

function __action_modify_server() {
  local instances
  local selected_instance

  # Get available instances
  mapfile -t instances < <("$kgsm" --instances $debug 2>/dev/null)

  if [[ ${#instances[@]} -eq 0 ]]; then
    echo -e "${COLOR_WARNING}No server instances found.${COLOR_RESET}" >&2
    __wait_for_key
    return 1
  fi

  # Select instance
  selected_instance=$(__select_from_list "Select Instance to Modify" instances)
  case $? in
  1) return 0 ;; # Back
  2) return 2 ;; # Quit
  esac

  # Load instance configuration to determine current state
  __source_instance "$selected_instance" || {
    echo -e "${COLOR_ERROR}Failed to load instance configuration.${COLOR_RESET}" >&2
    __wait_for_key
    return 1
  }

  # Build modification options based on current state
  local modify_options=()
  local modify_commands=()

  if [[ "$instance_enable_systemd" == "true" ]]; then
    modify_options+=("Disable systemd service")
    modify_commands+=("--remove systemd")
  else
    modify_options+=("Enable systemd service")
    modify_commands+=("--add systemd")
  fi

  if [[ "$instance_enable_firewall_management" == "true" ]]; then
    modify_options+=("Disable firewall rules")
    modify_commands+=("--remove ufw")
  else
    modify_options+=("Enable firewall rules")
    modify_commands+=("--add ufw")
  fi

  if [[ "$instance_enable_command_shortcuts" == "true" ]]; then
    modify_options+=("Remove command shortcuts")
    modify_commands+=("--remove symlink")
  else
    modify_options+=("Create command shortcuts")
    modify_commands+=("--add symlink")
  fi

  if [[ "${instance_enable_port_forwarding:-false}" == "true" ]]; then
    modify_options+=("Disable UPnP port forwarding")
    modify_commands+=("--remove upnp")
  else
    modify_options+=("Enable UPnP port forwarding")
    modify_commands+=("--add upnp")
  fi

  # Select modification
  local selected_option
  selected_option=$(__select_from_list "Select Modification for $selected_instance" modify_options)
  case $? in
  1) return 0 ;; # Back
  2) return 2 ;; # Quit
  esac

  # Find the corresponding command
  local selected_command=""
  local i=0
  for option in "${modify_options[@]}"; do
    if [[ "$option" == "$selected_option" ]]; then
      selected_command="${modify_commands[$i]}"
      break
    fi
    ((i++))
  done

  if [[ -z "$selected_command" ]]; then
    echo -e "${COLOR_ERROR}Internal error: Could not find command for selected option.${COLOR_RESET}" >&2
    __wait_for_key
    return 1
  fi

  # Execute modification
  echo -e "${COLOR_INFO}Modifying server instance...${COLOR_RESET}" >&2

  if "$kgsm" --instance "$selected_instance" --modify $selected_command $debug; then
    echo -e "${COLOR_SUCCESS}Modification completed successfully!${COLOR_RESET}" >&2
  else
    echo -e "${COLOR_ERROR}Modification failed. Check the output above for details.${COLOR_RESET}" >&2
  fi

  __wait_for_key
}

function __action_list_items() {
  local list_type="$1"
  local title="$2"

  __clear_screen
  __draw_box "$title"
  __print_empty_line

  if [[ "$list_type" == "--blueprints" ]]; then
    "$kgsm" --blueprints $debug
  else
    "$kgsm" --instances $debug
  fi

  __print_empty_line
  __close_box
  __wait_for_key
}

function __action_restore_backup() {
  local instances
  local selected_instance
  local backups
  local selected_backup

  # Get available instances
  mapfile -t instances < <("$kgsm" --instances $debug 2>/dev/null)

  if [[ ${#instances[@]} -eq 0 ]]; then
    echo -e "${COLOR_WARNING}No server instances found.${COLOR_RESET}" >&2
    __wait_for_key
    return 1
  fi

  # Select instance
  selected_instance=$(__select_from_list "Select Instance to Restore" instances)
  case $? in
  1) return 0 ;; # Back
  2) return 2 ;; # Quit
  esac

  # Load instance configuration
  __source_instance "$selected_instance" || {
    echo -e "${COLOR_ERROR}Failed to load instance configuration.${COLOR_RESET}" >&2
    __wait_for_key
    return 1
  }

  # Get available backups
  mapfile -t backups < <("$instance_management_file" --list-backups $debug 2>/dev/null)

  if [[ ${#backups[@]} -eq 0 ]]; then
    echo -e "${COLOR_WARNING}No backups found for instance '$selected_instance'.${COLOR_RESET}" >&2
    echo -e "${COLOR_INFO}Create a backup first using the 'Create Backup' option.${COLOR_RESET}" >&2
    __wait_for_key
    return 1
  fi

  # Select backup
  selected_backup=$(__select_from_list "Select Backup to Restore" backups)
  case $? in
  1) return 0 ;; # Back
  2) return 2 ;; # Quit
  esac

  # Confirm restoration
  if ! __confirm_action "This will overwrite current data for '$selected_instance' with backup '$selected_backup'."; then
    echo -e "${COLOR_INFO}Restore cancelled.${COLOR_RESET}" >&2
    __wait_for_key
    return 0
  fi

  # Execute restoration
  echo -e "${COLOR_INFO}Restoring backup...${COLOR_RESET}" >&2

  if "$kgsm" --instance "$selected_instance" --restore-backup "$selected_backup" $debug; then
    echo -e "${COLOR_SUCCESS}Backup restored successfully!${COLOR_RESET}" >&2
  else
    echo -e "${COLOR_ERROR}Backup restoration failed.${COLOR_RESET}" >&2
  fi

  __wait_for_key
}

# =============================================================================
# HELP FUNCTIONS
# =============================================================================

function __show_detailed_help() {
  __clear_screen
  __draw_box "KGSM Interactive Mode - Help"
  __print_box_line "Navigation:"
  __print_box_line "  • Use numbers to select menu options"
  __print_box_line "  • Use 'b' to go back to previous menu"
  __print_box_line "  • Use 'm' to jump to main menu"
  __print_box_line "  • Use 'q' to quit KGSM"
  __print_box_line "  • Use 'h' for help (where available)"
  __print_empty_line
  __print_box_line "Server Management:"
  __print_box_line "  • Install: Deploy new game servers"
  __print_box_line "  • Start/Stop/Restart: Control server lifecycle"
  __print_box_line "  • Modify: Add/remove system integrations"
  __print_box_line "  • Uninstall: Remove servers completely"
  __print_empty_line
  __print_box_line "Information & Monitoring:"
  __print_box_line "  • List: View available blueprints and instances"
  __print_box_line "  • Status: Check detailed server information"
  __print_box_line "  • Logs: View recent server activity"
  __print_empty_line
  __print_box_line "Maintenance:"
  __print_box_line "  • Updates: Keep servers current"
  __print_box_line "  • Backups: Protect your server data"
  __print_box_line "  • Restore: Recover from backups"
  __print_empty_line
  __print_box_line "For more information, visit:"
  __print_box_line "  https://github.com/TheKrystalShip/KGSM"
  __close_box
  __wait_for_key
}

# =============================================================================
# MAIN MENU LOOP FUNCTIONS
# =============================================================================

function __handle_main_menu() {
  while true; do
    __show_main_menu

    local choice
    if choice=$(__get_menu_choice "1 2 3 4 h q"); then
      case "$choice" in
      1)
        __handle_server_management_menu
        local result=$?
        [[ $result -eq 2 ]] && return 0 # Quit signal
        ;;
      2)
        __handle_information_menu
        local result=$?
        [[ $result -eq 2 ]] && return 0 # Quit signal
        ;;
      3)
        __handle_maintenance_menu
        local result=$?
        [[ $result -eq 2 ]] && return 0 # Quit signal
        ;;
      4)
        __handle_system_tools_menu
        local result=$?
        [[ $result -eq 2 ]] && return 0 # Quit signal
        ;;
      h) __show_detailed_help ;;
      q) return 0 ;;
      esac
    else
      __wait_for_key "Invalid selection. Press any key to try again..."
    fi
  done
}

function __handle_server_management_menu() {
  while true; do
    __show_server_management_menu

    local choice
    if choice=$(__get_menu_choice "1 2 3 4 5 6 b m q"); then
      case "$choice" in
      1) __action_install_server ;;
      2) __action_server_operation "--start" "start" ;;
      3) __action_server_operation "--stop" "stop" ;;
      4) __action_server_operation "--restart" "restart" ;;
      5) __action_server_operation "--uninstall" "uninstall" ;;
      6) __action_modify_server ;;
      b | m) return 0 ;;
      q) return 2 ;;
      esac

      # Handle quit signal from sub-actions
      [[ $? -eq 2 ]] && return 2
    else
      __wait_for_key "Invalid selection. Press any key to try again..."
    fi
  done
}

function __handle_information_menu() {
  while true; do
    __show_information_menu

    local choice
    if choice=$(__get_menu_choice "1 2 3 4 b m q"); then
      case "$choice" in
      1) __action_list_items "--blueprints" "Available Blueprints" ;;
      2) __action_list_items "--instances" "Installed Instances" ;;
      3) __action_server_operation "--status" "view status" ;;
      4) __action_server_operation "--logs" "view logs" ;;
      b | m) return 0 ;;
      q) return 2 ;;
      esac

      # Handle quit signal from sub-actions
      [[ $? -eq 2 ]] && return 2
    else
      __wait_for_key "Invalid selection. Press any key to try again..."
    fi
  done
}

function __handle_maintenance_menu() {
  while true; do
    __show_maintenance_menu

    local choice
    if choice=$(__get_menu_choice "1 2 3 4 b m q"); then
      case "$choice" in
      1) __action_server_operation "--check-update" "check for updates" ;;
      2) __action_server_operation "--update" "update" ;;
      3) __action_server_operation "--create-backup" "create backup" ;;
      4) __action_restore_backup ;;
      b | m) return 0 ;;
      q) return 2 ;;
      esac

      # Handle quit signal from sub-actions
      [[ $? -eq 2 ]] && return 2
    else
      __wait_for_key "Invalid selection. Press any key to try again..."
    fi
  done
}

function __handle_system_tools_menu() {
  while true; do
    __show_system_tools_menu

    local choice
    if choice=$(__get_menu_choice "1 2 3 b m q"); then
      case "$choice" in
      1)
        __clear_screen
        __draw_box "KGSM Configuration"
        __print_empty_line
        [[ -f "$KGSM_ROOT/config.ini" ]] && cat "$KGSM_ROOT/config.ini" || echo "No configuration file found."
        __print_empty_line
        __close_box
        __wait_for_key
        ;;
      2)
        __clear_screen
        __draw_box "System Information"
        __print_box_line "KGSM Version: $(__get_kgsm_version)"
        __print_box_line "KGSM Root: $KGSM_ROOT"
        __print_box_line "System: $(uname -s) $(uname -r)"
        __print_box_line "Architecture: $(uname -m)"
        __print_box_line "User: $(whoami)"
        __print_box_line "Shell: $SHELL"
        __close_box
        __wait_for_key
        ;;
      3)
        echo -e "${COLOR_INFO}Updating KGSM...${COLOR_RESET}" >&2
        "$kgsm" --update $debug
        __wait_for_key
        ;;
      b | m) return 0 ;;
      q) return 2 ;;
      esac
    else
      __wait_for_key "Invalid selection. Press any key to try again..."
    fi
  done
}

# =============================================================================
# MAIN ENTRY POINT
# =============================================================================

function usage() {
  local UNDERLINE="\e[4m"
  local END="\e[0m"

  echo -e "${UNDERLINE}Interactive Mode for Krystal Game Server Manager${END}

This module provides a user-friendly menu-driven interface for managing game servers.

${UNDERLINE}Usage:${END}
  $(basename "$0") [OPTIONS]

${UNDERLINE}Options:${END}
  -h, --help              Display this help information
  -i, --interactive       Launch the interactive menu interface
  --description           Show the KGSM description header used in the interactive menu
"
}

function __get_description() {
  local version
  version=$(__get_kgsm_version)

  echo "Krystal Game Server Manager - $version

Create, install, and manage game servers on Linux.

If you have any problems while using KGSM, please don't hesitate to create an
issue on GitHub: https://github.com/TheKrystalShip/KGSM/issues"
}

function start_interactive() {
  # Welcome message
  __clear_screen
  __draw_box "Welcome to KGSM Interactive Mode"
  __print_box_line "Krystal Game Server Manager - $(__get_kgsm_version)"
  __print_empty_line
  __print_box_line "Create, install, and manage game servers on Linux."
  __print_empty_line
  __print_box_line "Navigation Tips:"
  __print_box_line "  • Use numbers to select options"
  __print_box_line "  • Use 'b' to go back, 'q' to quit"
  __print_box_line "  • Use 'h' for help when available"
  __print_box_line "  • Press Ctrl+C to exit at any time"
  __close_box

  __wait_for_key "Press any key to continue..."

  # Start main menu loop
  __handle_main_menu

  # Exit message
  __clear_screen
  echo -e "${COLOR_SUCCESS}Thank you for using KGSM!${COLOR_RESET}" >&2
  echo -e "${COLOR_INFO}For command-line usage, run: ./kgsm.sh --help${COLOR_RESET}" >&2
  echo >&2
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

while [[ "$#" -gt 0 ]]; do
  case $1 in
  -h | --help)
    usage
    exit 0
    ;;
  -i | --interactive)
    start_interactive
    exit $?
    ;;
  --description)
    __get_description
    exit 0
    ;;
  *)
    __print_error "Invalid argument $1"
    exit $EC_INVALID_ARG
    ;;
  esac
  shift
done

# By default, start interactive mode if no arguments provided
start_interactive
exit $?
