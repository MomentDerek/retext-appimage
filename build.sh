#! /bin/bash

set -e
set -x

if [ "$ARCH" == "" ]; then
    echo "Error: \$ARCH not set"
    echo "Please export \$ARCH to either x86_64 or i386 and try again"
    exit 1
fi

# use RAM disk if possible
if [ "$CI" == "" ] && [ -d /dev/shm ]; then
    TEMP_BASE=/dev/shm
else
    TEMP_BASE=/tmp
fi

BUILD_DIR=$(mktemp -d -p "$TEMP_BASE" linuxdeploy-build-XXXXXX)

cleanup () {
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
    fi
}

trap cleanup EXIT

# store repo root as variable
REPO_ROOT=$(readlink -f $(dirname $(dirname $0)))
OLD_CWD=$(readlink -f .)

pushd "$BUILD_DIR"

# get linuxdeploy and its conda plugin
wget https://momincong.com/upload/2022/09/linuxdeploy-aarch64.AppImage
wget https://github.com/linuxdeploy/linuxdeploy-plugin-conda/raw/master/linuxdeploy-plugin-conda.sh
chmod +x linuxdeploy*
sed -i 's|AI\x02|\x00\x00\x00|' *.AppImage

# fetch some assets from the ReText repo
wget https://github.com/retext-project/retext/raw/master/data/me.mitya57.ReText.desktop
wget https://github.com/retext-project/retext/raw/master/icons/retext.svg

# set up a basic AppDir; we cannot finish the AppImage already since we need to find out the ReText version after installing it from PyPI
export PIP_REQUIREMENTS="ReText pymdown-extensions pyenchant"
./linuxdeploy-"$ARCH".AppImage --appdir AppDir --plugin conda

# get a proper version number
export VERSION="$(cat AppDir/usr/bin/retext  | grep __requires__ | sed -r 's|.*ReText\s*==\s*([^'"'"']+).*|\1|')"

# finish up AppDir and run the appimage plugin to create the final AppImage
./linuxdeploy-"$ARCH".AppImage --appdir AppDir --output appimage -d me.mitya57.ReText.desktop -i retext.svg --custom-apprun "$REPO_ROOT"/AppRun.sh

mv ReText-*.AppImage "$OLD_CWD"
