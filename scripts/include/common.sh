#!/bin/bash

ROOT_DIR=$KGSM_ROOT

if [[ -z "${KGSM_ROOT}" ]]; then
  ROOT_DIR=$(pwd)
else
  ROOT_DIR="${KGSM_ROOT}"
fi

# Blueprints (*.bp) are stored here
# shellcheck disable=SC2155
export BLUEPRINTS_SOURCE_DIR="$(find "$ROOT_DIR" -type d -name blueprints)"

# Overides (*.overrides.sh) are stored here
# shellcheck disable=SC2155
export OVERRIDES_SOURCE_DIR="$(find "$ROOT_DIR" -type d -name overrides)"

# Templates (*.tp) are stored here
# shellcheck disable=SC2155
export TEMPLATES_SOURCE_DIR="$(find "$ROOT_DIR" -type d -name templates)"

# All other scripts (*.sh) are stored here
# shellcheck disable=SC2155
export SCRIPTS_SOURCE_DIR="$(find "$ROOT_DIR" -type d -name scripts)"

# "Library" scripts are stored here
# shellcheck disable=SC2155
export SCRIPTS_INCLUDE_SOURCE_DIR="$(find "$ROOT_DIR" -type d -name include)"
