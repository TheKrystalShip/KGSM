#!/usr/bin/env bash

# Exit codes
EC_OKAY=0
EC_GENERAL=1
EC_KGSM_ROOT=2
EC_FAILED_CONFIG=3
EC_INVALID_CONFIG=4
EC_FILE_NOT_FOUND=5
EC_FAILED_SOURCE=6
EC_MISSING_ARG=7
EC_INVALID_ARG=8
EC_FAILED_CD=9
EC_FAILED_CP=10
EC_FAILED_RM=11
EC_FAILED_TEMPLATE=12
EC_FAILED_DOWNLOAD=13
EC_FAILED_DEPLOY=14
EC_FAILED_MKDIR=15
EC_PERMISSION=16
EC_FAILED_SED=17
EC_SYSTEMD=18
EC_UFW=19
EC_MALFORMED_INSTANCE=20
EC_MISSING_DEPENDENCY=21
EC_FAILED_LN=22
EC_FAILED_UPDATE_CONFIG=23
EC_KEY_NOT_FOUND=24
EC_NOT_FOUND=25
EC_FAILED_VERSION_SAVE=26
EC_BLUEPRINT_NOT_FOUND=27
EC_INVALID_BLUEPRINT=28
EC_INVALID_INSTANCE=29
EC_FAILED_MV=30
EC_ERROR=31
EC_FAILED_TOUCH=32
EC_FAILURE=33
EC_MISSING_ARGS=34
EC_SKIP=35
EC_SUCCESS=36

declare -A EXIT_CODES=(
  [$EC_OKAY]="No error"
  [$EC_GENERAL]="General error"
  [$EC_KGSM_ROOT]="KGSM_ROOT not set"
  [$EC_FAILED_CONFIG]="Failed to load config.ini file"
  [$EC_INVALID_CONFIG]="Invalid configuration"
  [$EC_FILE_NOT_FOUND]="File not found"
  [$EC_FAILED_SOURCE]="Failed to source file"
  [$EC_MISSING_ARG]="Missing argument"
  [$EC_INVALID_ARG]="Invalid argument"
  [$EC_FAILED_CD]="Failed to move into directory"
  [$EC_FAILED_CP]="Failed to copy"
  [$EC_FAILED_RM]="Failed to remove"
  [$EC_FAILED_TEMPLATE]="Failed to generate template"
  [$EC_FAILED_DOWNLOAD]="Failed to download"
  [$EC_FAILED_DEPLOY]="Failed to deploy"
  [$EC_FAILED_MKDIR]="Failed mkdir"
  [$EC_PERMISSION]="Permission issue"
  [$EC_FAILED_SED]="Error with 'sed' command"
  [$EC_SYSTEMD]="Error with 'systemctl' command"
  [$EC_UFW]="Error with 'ufw' command"
  [$EC_MALFORMED_INSTANCE]="Malformed instance config file"
  [$EC_MISSING_DEPENDENCY]="Missing required dependency"
  [$EC_FAILED_LN]="Failed to create symlink"
  [$EC_FAILED_UPDATE_CONFIG]="Failed to update config file"
  [$EC_KEY_NOT_FOUND]="Configuration key not found"
  [$EC_NOT_FOUND]="Item not found"
  [$EC_FAILED_VERSION_SAVE]="Failed to save version"
  [$EC_BLUEPRINT_NOT_FOUND]="Blueprint not found"
  [$EC_INVALID_BLUEPRINT]="Invalid blueprint"
  [$EC_INVALID_INSTANCE]="Invalid instance"
  [$EC_FAILED_MV]="Failed to move file"
  [$EC_ERROR]="Error occurred"
  [$EC_FAILED_TOUCH]="Failed to create file"
  [$EC_FAILURE]="Operation failed"
  [$EC_MISSING_ARGS]="Missing arguments"
  [$EC_SKIP]="Operation skipped"
  [$EC_SUCCESS]="Operation successful"
)

function __print_error_code() {
  local code=$1
  local script="${BASH_SOURCE[1]}" # The script where the error occurred
  local func="${FUNCNAME[1]}"      # The function where the error occurred
  local line="${BASH_LINENO[0]}"   # The line number where the error occurred

  echo "Error $code: ${EXIT_CODES[$code]:-Unknown error}" >&2
  echo "Occurred in script: $script, function: $func, line: $line" >&2
  exit $code
}

export -f __print_error_code

function __enable_error_checking() {
  set -o pipefail
  trap '__print_error_code $?; exit $?' ERR
}

export -f __enable_error_checking

function __disable_error_checking() {
  set +o pipefail
  trap '' ERR
}

export -f __disable_error_checking

__enable_error_checking

export KGSM_ERRORS_LOADED=1
