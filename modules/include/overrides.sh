#!/bin/bash

# Params
if [ $# -eq 0 ]; then
  echo "${0##*/} ERROR: Sourcing error, blueprint name not specified" >&2 && exit 1
fi

# Check for KGSM_ROOT env variable
if [ -z "$KGSM_ROOT" ]; then
  echo "${0##*/} WARNING: KGSM_ROOT not found, sourcing /etc/environment." >&2
  # shellcheck disable=SC1091
  source /etc/environment
  if [ -z "$KGSM_ROOT" ]; then
    echo "${0##*/} ERROR: KGSM_ROOT not found, exiting." >&2 && exit 1
  else
    echo "${0##*/} INFO: KGSM_ROOT found in /etc/environment, consider rebooting the system" >&2
    if ! declare -p KGSM_ROOT | grep -q 'declare -x'; then export KGSM_ROOT; fi
  fi
fi

instance=$1

module_common="$(find "$KGSM_ROOT" -type f -name common.sh -print -quit)"
[[ -z "$module_common" ]] && echo "${0##*/} ERROR: Could not find module common.sh" >&2 && exit 1

# shellcheck disable=SC1090
source "$module_common" || exit 1

instance_config_file=$(__load_instance "$instance")

# for when grep fails to find INSTANCE_OVERRIDES_FILE
set +eo pipefail
instance_overrides_file=$(grep "INSTANCE_OVERRIDES_FILE=" <"$instance_config_file" | cut -d "=" -f2 | tr -d '"')
set -eo pipefail

# Import custom scripts if the game has any
if [[ -n "$instance_overrides_file" ]] && [[ -f "$instance_overrides_file" ]]; then
  # It's important to also source the instance config file because the overrides
  # need access to the variables contained in it.
  # shellcheck disable=SC1090
  source "$instance_config_file" || exit 1

  # shellcheck disable=SC1090
  source "$instance_overrides_file" || exit 1
fi
