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

Required packages:
  ${required_packages[*]}

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
  if command -v "$1" &> /dev/null; then
    return 0 # Installed
  else
    return 1 # Not installed
  fi
}

# https://developer.valvesoftware.com/wiki/SteamCMD#Package_From_Repositories
function _install_steamcmd() {
  local steamcmdUrl="https://developer.valvesoftware.com/wiki/SteamCMD"
  local manualInstallRequired="Manual installation required: $steamcmdUrl"

  # Function to check for command existence
  command_exists() {
    command -v "$1" &> /dev/null
  }

  if command_exists steamcmd &>/dev/null; then
    echo "SteamCMD is installed" >&2
    return 0
  fi

  # Ubuntu/Debian
  if command_exists apt-get; then
    apt-get update

    # Install software-properties-common if necessary
    if ! command_exists add-apt-repository; then
      if ! apt-get install -y software-properties-common; then
        echo "ERROR: Command failed: sudo apt-get install software-properties-common" >&2
        echo "$manualInstallRequired" >&2
        return 1
      fi
    fi

    # Add the new repository and update package list
    if ! add-apt-repository -y multiverse; then
      echo "ERROR: Command failed: sudo add-apt-repository multiverse" >&2
      echo "$manualInstallRequired" >&2
      return 1
    fi

    if ! dpkg --add-architecture i386; then
      echo "ERROR: Command failed: sudo dpkg --add-architecture i386" >&2
      echo "$manualInstallRequired" >&2
      return 1
    fi

    apt-get update

    # Install steamcmd
    if ! apt-get install -y steamcmd; then
      echo "ERROR: Command failed: sudo apt-get install steamcmd" >&2
      echo "$manualInstallRequired" >&2
      return 1
    fi

    if ! command_exists steamcmd; then
      echo "ERROR: steamcmd not available on the \$PATH after successful install" >&2
      echo "$manualInstallRequired" >&2
      return 1
    fi

    echo "SteamCMD installation completed successfully!"
    return 0

  # Fedora/CentOS/RHEL
  elif command_exists yum; then
    yum check-update

    # Install EPEL repository if not already present
    if ! rpm -qa | grep -qw epel-release; then
      if ! sudo yum install -y epel-release; then
        echo "ERROR: Command failed: sudo yum install epel-release" >&2
          echo "$manualInstallRequired" >&2
            return 1
      fi
    fi

    # Install steamcmd
    if ! yum install -y steamcmd; then
      echo "ERROR: Command failed: sudo yum install steamcmd" >&2
      echo "$manualInstallRequired" >&2
      return 1
    fi

    echo "SteamCMD installation completed successfully!"
    return 0

  # Arch Linux
  elif command_exists pacman; then
    pacman -Syu --noconfirm

    # Install base-devel and git if not present
    if ! command_exists makepkg; then
      if ! pacman -S --noconfirm base-devel; then
        echo "ERROR: Command failed: sudo pacman -S base-devel" >&2
          echo "$manualInstallRequired" >&2
            return 1
      fi
    fi

    if ! command_exists git; then
      if ! pacman -S --noconfirm git; then
        echo "ERROR: Command failed: sudo pacman -S git" >&2
        echo "$manualInstallRequired" >&2
        return 1
      fi
    fi

    # Clone and install steamcmd from AUR
    git clone https://aur.archlinux.org/steamcmd.git
    cd steamcmd
    makepkg -si --noconfirm
    cd ..
    rm -rf steamcmd

    echo "SteamCMD installation completed successfully!"
    return 0

  else
    echo "ERROR: Unsupported package manager. Please install steamcmd manually." >&2
    echo "$steamcmdUrl" >&2
    return 1
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
    read -rp "Do you want to install them now? (Y/n): " choice

    if [[ "$choice" =~ ^[Nn]?$ ]]; then
      echo "Exiting script. Please install required packages manually." >&2
      return 1
    fi

    # Install missing packages based on the package manager
    if command -v apt-get &> /dev/null; then
      apt-get install "${missing_packages[@]}"
    elif command -v yum &> /dev/null; then
      yum install "${missing_packages[@]}"
    elif command -v pacman &> /dev/null; then
      pacman -S "${missing_packages[@]}"
    else
      # shellcheck disable=SC2145
      echo "Unsupported package manager. Please install ${missing_packages[@]} manually." >&2
      return 1
      fi
  fi

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
