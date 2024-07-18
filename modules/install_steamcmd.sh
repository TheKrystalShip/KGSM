#!/bin/bash

set -e

# URL for SteamCMD documentation
steamcmd_url="https://developer.valvesoftware.com/wiki/SteamCMD"

# Function to check if a command exists
command_exists() {
  command -v "$1" &>/dev/null
}

# Function to install SteamCMD for Debian-based distributions
install_steamcmd_debian() {
  apt-get update
  apt-get install -y software-properties-common
  add-apt-repository multiverse
  dpkg --add-architecture i386
  apt-get update
  apt-get install -y steamcmd
}

# Function to install SteamCMD for RHEL-based distributions
install_steamcmd_rhel() {
  yum check-update
  yum install -y epel-release
  yum install -y steamcmd
}

# Function to install SteamCMD for Arch-based distributions
install_steamcmd_arch() {
  pacman -Syu --noconfirm
  pacman -S --noconfirm base-devel git
  git clone https://aur.archlinux.org/steamcmd.git
  cd steamcmd
  makepkg -si --noconfirm
  cd ..
  rm -rf steamcmd
}

# Detect package manager and install SteamCMD
if command_exists apt-get; then
  install_steamcmd_debian
elif command_exists yum; then
  install_steamcmd_rhel
elif command_exists pacman; then
  install_steamcmd_arch
else
  echo "ERROR: Unsupported package manager. Please install SteamCMD manually." >&2
  echo "For manual installation, visit: $steamcmd_url" >&2
  exit 1
fi

# Verify installation
if command_exists steamcmd; then
  echo "SteamCMD installation completed successfully!" >&2
  exit 0
else
  echo "ERROR: SteamCMD not found in PATH after installation." >&2
  echo "Please ensure SteamCMD is installed correctly. For more information, visit: $steamcmd_url" >&2
  exit 1
fi
