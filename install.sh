#!/bin/bash
# KGSM installer script

set -e

head="main"
version_url="https://raw.githubusercontent.com/TheKrystalShip/KGSM/$head/version.txt"
repo_archive_url="https://github.com/TheKrystalShip/KGSM/archive/refs/heads/$head.tar.gz"
tarball="kgsm-$head.tar.gz"

required_packages=("grep" "jq" "wget" "unzip" "tar" "sed" "find")
missing_packages=()

for p in "${required_packages[@]}"; do
  if ! command -v "$p" &>/dev/null; then missing_packages+=("$p"); fi
done

if [[ "${#missing_packages[@]}" -ne 0 ]]; then
  echo "ERROR: Missing required packages: ${missing_packages[@]}" >&2
  echo "Please install missing packages before installing KGSM" >&2
  exit 1
fi

latest_version=$(wget -q -O - "$version_url")

wget -O "$tarball" "$repo_archive_url" 2>/dev/null
tar -xzf "$tarball"
rm "$tarball"
mv KGSM-$head kgsm
cd kgsm || exit 1
chmod +x kgsm.sh modules/*.sh
echo "INFO: KGSM version $latest_version downloaded successfully." >&2
