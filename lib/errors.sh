#!/usr/bin/env bash

# Exit codes
declare -g EC_OKAY=0
export EC_OKAY

declare -g EC_GENERAL=1
export EC_GENERAL

declare -g EC_KGSM_ROOT=2
export EC_KGSM_ROOT

declare -g EC_FAILED_CONFIG=3
export EC_FAILED_CONFIG

declare -g EC_INVALID_CONFIG=4
export EC_INVALID_CONFIG

declare -g EC_FILE_NOT_FOUND=5
export EC_FILE_NOT_FOUND

declare -g EC_FAILED_SOURCE=6
export EC_FAILED_SOURCE

declare -g EC_MISSING_ARG=7
export EC_MISSING_ARG

declare -g EC_INVALID_ARG=8
export EC_INVALID_ARG

declare -g EC_FAILED_CD=9
export EC_FAILED_CD

declare -g EC_FAILED_CP=10
export EC_FAILED_CP

declare -g EC_FAILED_RM=11
export EC_FAILED_RM

declare -g EC_FAILED_TEMPLATE=12
export EC_FAILED_TEMPLATE

declare -g EC_FAILED_DOWNLOAD=13
export EC_FAILED_DOWNLOAD

declare -g EC_FAILED_DEPLOY=14
export EC_FAILED_DEPLOY

declare -g EC_FAILED_MKDIR=15
export EC_FAILED_MKDIR

declare -g EC_PERMISSION=16
export EC_PERMISSION

declare -g EC_FAILED_SED=17
export EC_FAILED_SED

declare -g EC_SYSTEMD=18
export EC_SYSTEMD

declare -g EC_UFW=19
export EC_UFW

declare -g EC_MALFORMED_INSTANCE=20
export EC_MALFORMED_INSTANCE

declare -g EC_MISSING_DEPENDENCY=21
export EC_MISSING_DEPENDENCY

declare -g EC_FAILED_LN=22
export EC_FAILED_LN

declare -g EC_FAILED_UPDATE_CONFIG=23
export EC_FAILED_UPDATE_CONFIG

declare -g EC_KEY_NOT_FOUND=24
export EC_KEY_NOT_FOUND

declare -g EC_NOT_FOUND=25
export EC_NOT_FOUND

declare -g EC_FAILED_VERSION_SAVE=26
export EC_FAILED_VERSION_SAVE

declare -g EC_BLUEPRINT_NOT_FOUND=27
export EC_BLUEPRINT_NOT_FOUND

declare -g EC_INVALID_BLUEPRINT=28
export EC_INVALID_BLUEPRINT

declare -g EC_INVALID_INSTANCE=29
export EC_INVALID_INSTANCE

declare -g EC_FAILED_MV=30
export EC_FAILED_MV

declare -g EC_ERROR=31
export EC_ERROR

declare -g EC_FAILED_TOUCH=32
export EC_FAILED_TOUCH

declare -g EC_FAILURE=33
export EC_FAILURE

declare -g EC_MISSING_ARGS=34
export EC_MISSING_ARGS

declare -g EC_SKIP=35
export EC_SKIP

declare -g EC_SUCCESS=36
export EC_SUCCESS

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
