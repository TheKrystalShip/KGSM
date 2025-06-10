#!/usr/bin/env bash

## Colored output
# Check if stdout is tty
if test -t 1; then
  ncolors=0

  # Check for availability of tput
  if command -v tput >/dev/null 2>&1; then
    ncolors="$(tput colors)"
  fi

  # More than 8 means it supports colors
  if [[ $ncolors ]] && [[ "$ncolors" -gt 8 ]]; then
    export COLOR_RED="\033[0;31m"
    export COLOR_GREEN="\033[0;32m"
    export COLOR_ORANGE="\033[0;33m"
    export COLOR_BLUE="\033[0;34m"
    export COLOR_END="\033[0m"
  fi
fi

export LOG_LEVEL_SUCCESS="SUCCESS"
export LOG_LEVEL_INFO="INFO"
export LOG_LEVEL_WARNING="WARNING"
export LOG_LEVEL_ERROR="ERROR"

export LOGS_SOURCE_DIR=$KGSM_ROOT/logs
export LOG_FILE="$LOGS_SOURCE_DIR/kgsm.log"

# Don't call directly, use the __print_* functions instead
function __log_message() {
  local log_level="$1"

  # $message should contain as much information about the caller as possible,
  # so we can trace back the error or log entry.
  # BASH_SOURCE[-1] gives us the name of the script that called this function,
  # BASH_LINENO[1] gives us the line number in that script where this function was called.
  local message="${BASH_SOURCE[-1]##*/}:${BASH_LINENO[1]} $2"

  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

  # This works if declared in here but not if declared outside
  # of the function... why?
  declare -A LOG_LEVEL_COLOR_MAP=(
    ["$LOG_LEVEL_SUCCESS"]="$COLOR_GREEN"
    ["$LOG_LEVEL_INFO"]="$COLOR_BLUE"
    ["$LOG_LEVEL_WARNING"]="$COLOR_ORANGE"
    ["$LOG_LEVEL_ERROR"]="$COLOR_RED"
  )

  # Get the color for the log level
  local colored_log_level="${LOG_LEVEL_COLOR_MAP[$log_level]:-$COLOR_END}"

  local printable_log_entry="[${colored_log_level}${log_level}${COLOR_END}] $message"
  local log_entry="[$timestamp] [$log_level] $message"

  __create_dir "$LOGS_SOURCE_DIR"

  # Rotate log file if it reaches the size limit
  # shellcheck disable=SC2154
  if [[ -f "$LOG_FILE" ]] && [[ "$(stat --format=%s "$LOG_FILE")" -ge "$config_log_max_size_kb" ]]; then
    mv "$LOG_FILE" "$LOG_FILE.$(date '+%Y%m%d%H%M%S')"
  fi

  if [[ "$config_enable_logging" == "true" ]]; then
    echo "$log_entry" >>"$LOG_FILE"
  fi

  if [[ "$log_level" = "$LOG_LEVEL_ERROR" ]]; then
    echo -e "$printable_log_entry" >&2
  else
    echo -e "$printable_log_entry"
  fi
}

export -f __log_message

function __print_error() {
  __log_message "$LOG_LEVEL_ERROR" "$1"
}

export -f __print_error

function __print_success() {
  __log_message "$LOG_LEVEL_SUCCESS" "$1"
}

export -f __print_success

function __print_warning() {
  __log_message "$LOG_LEVEL_WARNING" "$1"
}

export -f __print_warning

function __print_info() {
  __log_message "$LOG_LEVEL_INFO" "$1"
}

export -f __print_info

export KGSM_LOGGING_LOADED=1
