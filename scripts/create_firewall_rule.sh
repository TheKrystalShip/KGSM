#!/bin/bash

# Params
if [ $# -eq 0 ]; then
  echo ">>> ERROR: Blueprint name not supplied. Run script like this: ./${0##*/} \"SERVICE\"" >&2
  exit 1
fi

# Check for KGSM_ROOT env variable
if [ -z "$KGSM_ROOT" ]; then
  echo "WARNING: KGSM_ROOT environmental variable not found, sourcing /etc/environment." >&2
  # shellcheck disable=SC1091
  source /etc/environment

  # If not found in /etc/environment
  if [ -z "$KGSM_ROOT" ]; then
    echo ">>> ERROR: KGSM_ROOT environmental variable not found, exiting." >&2
    exit 1
  else
    echo "INFO: KGSM_ROOT found in /etc/environment, consider rebooting the system" >&2

    # Check if KGSM_ROOT is exported
    if ! declare -p KGSM_ROOT | grep -q 'declare -x'; then
      export KGSM_ROOT
    fi
  fi
fi

# Trap CTRL-C
trap exit INT

BLUEPRINT=$1

BLUEPRINT_SCRIPT="$(find "$KGSM_ROOT" -type f -name blueprint.sh)"
FIREWALL_TEMPLATE_FILE="$(find "$KGSM_ROOT" -type f -name ufw.tp)"

# shellcheck disable=SC1090
source "$BLUEPRINT_SCRIPT" "$BLUEPRINT" || exit 1

OUTPUT_FILE="$SERVICE_SERVICE_DIR/ufw-${SERVICE_NAME}"

if ! eval "cat <<EOF
$(<"$FIREWALL_TEMPLATE_FILE")
EOF
" >"$OUTPUT_FILE" 2>/dev/null; then
  echo ">>> ERROR: Failed to create $OUTPUT_FILE" >&2
fi

# ufw complains if the file isn't owned by root
sudo chown root:root "$OUTPUT_FILE"
