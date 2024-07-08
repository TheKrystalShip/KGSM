#!/bin/bash

# Define required packages
required_packages=(
  "grep"
  "jq"
  "wget"
  "unzip"
  "tar"
  "sed"
  "find"
  "dirname"
  "tr"
  "steamcmd"
)

function usage() {
  echo "Listing an installation of required packages for KGSM

Usage:
  ./${0##*/} [option]

Options:
  -h --help   Prints this message

  --install   Attempts to install the required dependencies using the first
              package manager it can find

  --list      Displays a list of all required packages for KGSM
"
}

set -eo pipefail

# shellcheck disable=SC2199
if [[ $@ =~ "--debug" ]]; then
  export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
  set -x
fi

while [ $# -gt 0 ]; do
  case "$1" in
  -h | --help)
    usage && exit 0
    ;;
  --list)
    echo "${required_packages[@]}" && exit 0
    ;;
  *)
    break
    ;;
  esac
  shift
done

if [ "$EUID" -ne 0 ]; then
  echo "${0##*/} Please run as root" >&2
  exit 1
fi

# Function to check if a package is installed
function is_package_installed() {
  if command -v "$1" &>/dev/null; then
    return 0 # Installed
  else
    return 1 # Not installed
  fi
}

function _install() {
  # Check if each required package is installed
  missing_packages=()
  for package in "${required_packages[@]}"; do
    if ! is_package_installed "$package"; then
      [[ "$package" == "find" ]] && package=findutils
      [[ "$package" == "dirname" || "$package" == "tr" ]] && package=coreutils
      missing_packages+=("$package")
    fi
  done

  # If there are missing packages, prompt the user to install them
  if [ ${#missing_packages[@]} -gt 0 ]; then
    # shellcheck disable=SC2145
    echo "The following packages are required but not installed: ${missing_packages[@]}" >&2
    read -rp "Do you want to install them now? (y/n): " choice
    if [[ "$choice" =~ ^[Yy](es)?$ ]]; then
      # Install missing packages based on the package manager
      # You might need to adjust the package installation command based on the distribution
      if command -v apt-get &>/dev/null; then
        apt-get install "${missing_packages[@]}"
      elif command -v yum &>/dev/null; then
        yum install "${missing_packages[@]}"
      elif command -v pacman &>/dev/null; then
        pacman -S "${missing_packages[@]}"
      else
        # shellcheck disable=SC2145
        echo "Unsupported package manager. Please install ${missing_packages[@]} manually." >&2
        return 1
      fi
    else
      echo "Exiting script. Please install required packages manually." >&2
      return 1
    fi
  fi

  # Continue with the rest of your script knowing that required packages are installed
  echo "All required packages are installed." >&2
  return 0
}

#Read the argument values
while [ $# -gt 0 ]; do
  case "$1" in
  --install)
    _install && exit $?
    ;;
  *)
    echo "ERROR: Invalid argument $1" >&2
    usage && exit 1
    ;;
  esac
  shift
done
