#!/bin/bash

set -euo pipefail

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

package="kgsm"
owner="TheKrystalShip"
head="${KGSM_BRANCH:-main}"
repo_archive_tag_url="https://github.com/${owner}/${package^^}/archive/refs/tags"
all_releases_api_url="https://api.github.com/repos/${owner}/${package^^}/releases"
stable_release_api_url="https://api.github.com/repos/${owner}/${package^^}/releases/latest"
compare_api_url="https://api.github.com/repos/${owner}/${package^^}/compare"
local_version_file=".${package}.version"
deprecated_version_file="version.txt"
deprecated_install_file="install.sh"

SELF_PATH="$(dirname "$(readlink -f "$0")")"

# Check if stdout is a tty
if test -t 1; then
  ncolors=0
  if command -v tput >/dev/null 2>&1; then
    ncolors="$(tput colors)"
  fi
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
  -v, --version              Prints the locally installed version of KGSM
  --version-list             Prints a list of all released versions of KGSM
  --install                  Downloads and installs the latest version of KGSM
  --install [version]        Downloads and installs a specific version of KGSM
  --check-update             Checks if a newer version of KGSM is available
  --update                   Updates KGSM to the latest version

Examples:
  $(basename "$0") --install
  $(basename "$0") --install 1.6.0
  $(basename "$0") --check-update
  $(basename "$0") --update
"
}

# Ensure required commands are available
function check_command() {
  local cmd=$1
  local pkg=$2
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo -e "${0##*/} ${COLOR_RED}ERROR${COLOR_END} '$cmd' is required but not installed." >&2
    echo -e "${0##*/} ${COLOR_RED}ERROR${COLOR_END} Please install '$pkg' before proceeding." >&2
    exit 1
  fi
}

check_command wget wget
check_command jq jq
check_command tar tar

# Handle deprecated version file
if [[ -f "${SELF_PATH}/${deprecated_version_file}" ]]; then
  echo -e "${0##*/} ${COLOR_ORANGE}WARNING${COLOR_END} Deprecated file '$deprecated_version_file' found"
  echo -e "${0##*/} ${COLOR_ORANGE}WARNING${COLOR_END} This file has been moved to '$local_version_file'"
  mv "${SELF_PATH}/${deprecated_version_file}" "${SELF_PATH}/${local_version_file}"
fi

# Handle deprecated install file
if [[ -f "${SELF_PATH}/${deprecated_install_file}" ]]; then
  echo -e "${0##*/} ${COLOR_ORANGE}WARNING${COLOR_END} Deprecated file '$deprecated_install_file' found"
  echo -e "${0##*/} ${COLOR_ORANGE}WARNING${COLOR_END} This file is no longer used and is safe to delete"
  # rm "$deprecated_install_file"
fi


# Read version from the local file
function get_current_version() {
  if [[ ! -f "${SELF_PATH}/${local_version_file}" ]]; then
    echo -e "${0##*/} ${COLOR_RED}ERROR${COLOR_END} Version file is missing. Reinstallation is recommended." >&2
    exit 1
  fi
  echo "$(<"${SELF_PATH}/${local_version_file}")"
}

# Fetch versions from GitHub
function fetch_version_data() {
  local url=$1
  local data
  data=$(wget -qO - "$url") || {
    echo -e "${0##*/} ${COLOR_RED}ERROR${COLOR_END} Failed to fetch data from $url." >&2
    exit 1
  }
  echo "$data"
}

function get_latest_stable_version() {
  fetch_version_data "$stable_release_api_url" | jq -r '.tag_name'
}

function get_all_versions() {
  fetch_version_data "$all_releases_api_url" | jq -r '.[] | .tag_name' | sort -Vr
}

# Compare two semantic versions
function compare_versions() {
  local version1=$1
  local version2=$2

  if [[ $(echo -e "$version1\n$version2" | sort -V | head -n1) == "$version1" ]]; then
    if [[ "$version1" == "$version2" ]]; then
      return 0  # versions are equal
    else
      return 1  # version1 is greater than version2
    fi
  else
    return 2  # version1 is smaller than version2
  fi
}

# Fetch changelog for a specific version
function fetch_changelog() {
  local version1=$1
  local version2=$2

  fetch_version_data "$compare_api_url/${version1}...${version2}" | jq -r \
      '.commits[]
      | select(.commit.message | test("^Bumped version to [0-9]+\\.[0-9]+\\.[0-9]+") | not)
      | "\(.sha[0:7]): \(.commit.message)"'
}

# Download and extract a specific version
function download_kgsm() {
  local version=$1
  local tarball="$package-$head-$version.tar.gz"

  echo -e "${0##*/} ${COLOR_BLUE}INFO${COLOR_END} Downloading version $version..."

  wget -qO "$SELF_PATH/$tarball" "$repo_archive_tag_url/$version.tar.gz" || {
    echo -e "${0##*/} ${COLOR_RED}ERROR${COLOR_END} Failed to download $tarball." >&2
    exit 1
  }

  echo -e "${0##*/} ${COLOR_BLUE}INFO${COLOR_END} Extracting files..."

  tar -xzf "$SELF_PATH/$tarball" -C "$SELF_PATH" || {
    echo -e "${0##*/} ${COLOR_RED}ERROR${COLOR_END} Extraction failed for $tarball." >&2
    exit 1
  }

  rm "$SELF_PATH/$tarball"

  echo -e "${0##*/} ${COLOR_GREEN}SUCCESS${COLOR_END} Version $version downloaded and extracted."
}

function install_kgsm() {
  local version=${1:-}
  if [[ -z "$version" ]]; then
    version=$(get_latest_stable_version) || exit 1
  fi

  echo -e "${0##*/} ${COLOR_BLUE}INFO${COLOR_END} Installing KGSM version $version..."

  download_kgsm "$version"

  echo "$version" >"${SELF_PATH}/${package^^}-${version}/${local_version_file}"

  echo -e "${0##*/} ${COLOR_GREEN}SUCCESS${COLOR_END} KGSM version $version installed."
}

function check_for_update() {
  local latest_version
  latest_version=$(get_latest_stable_version) || exit 1
  local current_version
  current_version=$(get_current_version) || exit 1

  echo -e "${0##*/} ${COLOR_BLUE}INFO${COLOR_END} Current version: $current_version"
  echo -e "${0##*/} ${COLOR_BLUE}INFO${COLOR_END} Latest version: $latest_version"

  set +euo pipefail
  compare_versions "$current_version" "$latest_version"
  case $? in
    0)
      echo -e "${0##*/} ${COLOR_BLUE}INFO${COLOR_END} Current version is up-to-date."
      ;;
    1)
      echo -e "${0##*/} ${COLOR_BLUE}INFO${COLOR_END} A newer version is available: $latest_version."
      echo -e "${0##*/} ${COLOR_BLUE}INFO${COLOR_END} Run '$(basename "$0") --update' to update."
      ;;
    2)
      # echo -e "${0##*/} ${COLOR_RED}ERROR${COLOR_END} Current version is newer than the latest stable version."
      ;;
  esac
  set -euo pipefail
}

function update_kgsm() {
  echo -e "${0##*/} ${COLOR_BLUE}INFO${COLOR_END} Updating KGSM..."

  local latest_version
  latest_version=$(get_latest_stable_version) || exit 1
  local current_version
  current_version=$(get_current_version) || exit 1

  install_kgsm "$latest_version"

  cp -r "${SELF_PATH}/${package^^}-${latest_version}"/* "$SELF_PATH"
  rm -rf "${SELF_PATH}/${package^^}-${latest_version}"

  echo -e "${0##*/} ${COLOR_GREEN}SUCCESS${COLOR_END} KGSM updated to version $latest_version."

  # Display changelog after update
  local changelog
  changelog=$(fetch_changelog "$current_version" "$latest_version") || exit 1

  if [[ -n "$changelog" ]]; then
    echo -e "${0##*/} ${COLOR_BLUE}INFO${COLOR_END} Changelog between version ${current_version} and ${latest_version}:"
    echo -e "$changelog"
  else
    echo -e "${0##*/} ${COLOR_ORANGE}WARNING${COLOR_END} No changelog available for version $latest_version."
  fi
}

if [[ $# -eq 0 ]]; then
  echo -e "${0##*/} ${COLOR_ORANGE}WARNING${COLOR_END} No arguments provided. Defaulting to '--install'."
  install_kgsm
  exit 0
fi

case "$1" in
  -v | --version)
    get_current_version
    ;;
  --version-list)
    get_all_versions
    ;;
  --install)
    shift
    install_kgsm "$1"
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
    echo -e "${0##*/} ${COLOR_RED}ERROR${COLOR_END} Invalid argument $1" >&2
    exit 1
    ;;
esac

