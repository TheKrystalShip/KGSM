#!/bin/bash

set -e

package="kgsm"
head="main"
destination="/usr/lib"

repo_archive_url="https://raw.githubusercontent.com/TheKrystalShip/${package^^}/refs/heads/${head}.tar.gz"
version_url="https://raw.githubusercontent.com/TheKrystalShip/${package^^}/${head}/version.txt"

version=$(wget -q -O - "$version_url")
tarball="$package-$head-$version.tar.gz"

cd "$destination"
mkdir "$package"
cd "$package"

wget -O "$tarball" "$repo_archive_url" 2>/dev/null
tar -xzf "$tarball"
rm "$tarball"
mv ${package^^}-${head}/* .
chmod +x ./*.sh ./modules/*.sh
echo "KGSM $version successfully installed in $destination."
