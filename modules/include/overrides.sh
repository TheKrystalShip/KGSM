#!/bin/bash

# Params
if [ $# -eq 0 ]; then
  echo "${0##*/} ERROR: Service name not supplied" >&2 && exit 1
fi

# Check for KGSM_ROOT env variable
if [ -z "$KGSM_ROOT" ]; then
  echo "WARNING: KGSM_ROOT not found, sourcing /etc/environment." >&2
  # shellcheck disable=SC1091
  source /etc/environment
  if [ -z "$KGSM_ROOT" ]; then
    echo "${0##*/} ERROR: KGSM_ROOT not found, exiting." >&2 && exit 1
  else
    echo "INFO: KGSM_ROOT found in /etc/environment, consider rebooting the system" >&2
    if ! declare -p KGSM_ROOT | grep -q 'declare -x'; then export KGSM_ROOT; fi
  fi
fi

INSTANCE=$1

MODULE_COMMON=$(find "$KGSM_ROOT" -type f -name common.sh)
[[ -z "$MODULE_COMMON" ]] && echo "${0##*/} ERROR: Could not find module common.sh" >&2 && exit 1

# shellcheck disable=SC1090
source "$MODULE_COMMON" || exit 1

[[ $INSTANCE != *.ini ]] && INSTANCE="${INSTANCE}.ini"

INSTANCE_CONFIG_FILE=$(find "$KGSM_ROOT" -type f -name "$INSTANCE")
[[ -z "$INSTANCE_CONFIG_FILE" ]] && echo "${0##*/} ERROR: Could not find instance $INSTANCE" >&2 && exit 1

instance_overrides_file=$(grep "INSTANCE_OVERRIDES_FILE=" <"$INSTANCE_CONFIG_FILE" | cut -d "=" -f2 | tr -d '"')

# Import custom scripts if the game has any
if [[ -n "$instance_overrides_file" ]] && [[ -f "$instance_overrides_file" ]]; then
  # It's important to also source the instance config file because the overrides
  # need access to the variables contained in it.
  # shellcheck disable=SC1090
  source "$INSTANCE_CONFIG_FILE" || exit 1

  # shellcheck disable=SC1090
  source "$instance_overrides_file" || exit 1
fi
