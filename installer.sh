#!/bin/bash

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

set -o pipefail

package="kgsm"
head="${KGSM_BRANCH:-main}"
repo_base_url="https://github.com/TheKrystalShip/${package^^}"
repo_archive_url="$repo_base_url/archive/refs/heads/${head}.tar.gz"
version_url="https://raw.githubusercontent.com/TheKrystalShip/${package^^}/refs/heads/${head}/version.txt"
tarball="$package-$head-latest.tar.gz"

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

function usage() {
  echo "Manages KGSM installation, updates, and version checks

Usage:
  $(basename "$0") OPTION

Options:
  -h, --help                 Prints this message

  --install                  Downloads and installs the latest version of KGSM
  --check-update             Checks if a newer version of KGSM is available
  --update                   Updates KGSM to the latest version

Examples:
  $(basename "$0") --install
  $(basename "$0") --check-update
  $(basename "$0") --update
"
}

SELF_PATH="$(dirname "$(readlink -f "$0")")"

function get_latest_version() {
  if command -v wget >/dev/null 2>&1; then
    wget -qO - "$version_url"
  else
    echo -e "${0##*/} ${COLOR_RED}ERROR${COLOR_END}: wget is required but not installed." >&2
    exit 1
  fi
}

function check_for_update() {
  local latest_version
  local current_version

  latest_version=$(get_latest_version)
  if [[ ! -f version.txt ]]; then
    echo -e "${0##*/} ${COLOR_RED}ERROR${COLOR_END}: Current version not found. Assuming outdated." >&2
    return 1
  fi

  current_version=$(<version.txt)
  if [[ "$current_version" != "$latest_version" ]]; then
    echo -e "${0##*/} ${COLOR_BLUE}INFO${COLOR_END}: New version available: $latest_version"
    echo -e "${0##*/} ${COLOR_BLUE}INFO${COLOR_END}: Run '$(basename "$0") --update' to update."
  else
    echo -e "${0##*/} ${COLOR_BLUE}INFO${COLOR_END}: You are using the latest version: $current_version."
  fi
}

function download_kgsm() {
  local latest_version
  latest_version=$(get_latest_version)

  echo -e "${0##*/} ${COLOR_BLUE}INFO${COLOR_END}: Downloading latest version ($latest_version)..."
  wget -qO "$SELF_PATH/$tarball" "$repo_archive_url"

  echo -e "${0##*/} ${COLOR_BLUE}INFO${COLOR_END}: Extracting files..."
  tar -xzf "$SELF_PATH/$tarball"
  rm "$SELF_PATH/$tarball"

  local extracted_dir="${package^^}-${head}"
  mv "$SELF_PATH/$extracted_dir" "$SELF_PATH/$package"

  echo -e "${0##*/} ${COLOR_GREEN}SUCCESS${COLOR_END}: Downloaded KGSM version $latest_version"
}

function update_kgsm() {
  echo -e "${0##*/} ${COLOR_BLUE}INFO${COLOR_END}: Updating KGSM..."

  download_kgsm

  cp -r "$SELF_PATH/$package"/* .
  rm -rf "$SELF_PATH/${package:?}"

  echo -e "${0##*/} ${COLOR_GREEN}SUCCESS${COLOR_END}: KGSM Updated"
}

function install_kgsm() {
  echo -e "${0##*/} ${COLOR_BLUE}INFO${COLOR_END}: Installing KGSM..."

  download_kgsm

  echo -e "${0##*/} ${COLOR_GREEN}SUCCESS${COLOR_END}: KGSM Installed"
}

if [[ $# -eq 0 ]]; then
  echo -e "${0##*/} ${COLOR_ORANGE}WARNING${COLOR_END}: No arguments provided. Defaulting to '--install'."
  install_kgsm
  exit 0
fi

case "$1" in
  --install)
    install_kgsm
    ;;
  --check-update)
    check_for_update
    ;;
  --update)
    update_kgsm
    ;;
  -h | --help)
    usage
    ;;
  *)
    usage
    ;;
esac

