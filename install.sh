#!/bin/sh
# KGSM installer script

version_url="https://raw.githubusercontent.com/TheKrystalShip/KGSM/main/version.txt"
repo_archive_url="https://github.com/TheKrystalShip/KGSM/archive/refs/heads/main.tar.gz"
tarball="kgsm.tar.gz"

if ! command -v wget >/dev/null 2>&1; then echo "ERROR: wget is required." >&2 && exit 1; fi
if ! command -v tar >/dev/null 2>&1; then echo "ERROR: tar is required." >&2 && exit 1; fi

latest_version=$(wget -q -O - "$version_url")

wget -O "$tarball" "$repo_archive_url" 2>/dev/null
tar -xzf "$tarball"
rm "$tarball"
mv KGSM-main kgsm
cd kgsm || exit 1
chmod +x kgsm.sh modules/*.sh

# kgsm.sh expects a config.cfg file to be present before doing anything
# so this creates a temporary one
cp config.cfg.example config.cfg

# Install dependencies
./kgsm.sh --requirements --install

# Remove temporary config.cfg file
rm config.cfg

echo "INFO: KGSM version $latest_version downloaded successfully." >&2 && exit 0
