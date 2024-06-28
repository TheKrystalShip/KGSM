#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "${0##*/} Please run as root" >&2
  exit 1
fi

# Define required packages
required_packages=(
  "grep"
  "jq"
  "wget"
  "unzip"
  "curl"
  "tar"
  "sed"
  "find"
  "dirname"
  "steamcmd"
)

# Function to check if a package is installed
is_package_installed() {
  if command -v "$1" &>/dev/null; then
    return 0 # Installed
  else
    return 1 # Not installed
  fi
}

# Check if each required package is installed
missing_packages=()
for package in "${required_packages[@]}"; do
  if ! is_package_installed "$package"; then
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
      exit 1
    fi
  else
    echo "Exiting script. Please install required packages manually." >&2
    exit 1
  fi
fi

# Continue with the rest of your script knowing that required packages are installed
echo "All required packages are installed." >&2
exit 0
