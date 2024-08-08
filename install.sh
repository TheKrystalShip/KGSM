#!/bin/bash

set -e

package="kgsm"
head="main"
repo_archive_url="https://github.com/TheKrystalShip/${package^^}/archive/refs/heads/${head}.tar.gz"
version_url="https://raw.githubusercontent.com/TheKrystalShip/${package^^}/${head}/version.txt"
version=$(wget -qO - "$version_url")
tarball="$package-$head-$version.tar.gz"

wget -qO "$tarball" "$repo_archive_url"
tar -xzf "$tarball"
rm "$tarball"
mv "${package^^}-${head}" "${package}"
cd "${package}"
chmod +x "./*.sh" "./modules/*.sh"
echo "KGSM $version successfully installed in ./${package}"
