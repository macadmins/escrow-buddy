#!/bin/bash

#
#  build_and_pkg.sh
#  Escrow Buddy
#
#  Copyright 2023 Netflix
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

# Fail script if any command fails
set -e

cd "$(dirname "$0")"
xcodebuild -project "../Escrow Buddy/Escrow Buddy.xcodeproj" clean build analyze -configuration Release

echo "Determining version..."
VERSION=$(defaults read "$(pwd)/../Escrow Buddy/build/Release/Escrow Buddy.bundle/Contents/Info.plist" CFBundleShortVersionString)
echo "  Version: $VERSION"

echo "Preparing pkgroot and output folders..."
PKGROOT=$(mktemp -d /tmp/Escrow-Buddy-build-root-XXXXXXXXXXX)
OUTPUTDIR=$(mktemp -d /tmp/Escrow-Buddy-output-XXXXXXXXXXX)
mkdir -pv "$PKGROOT/Library/Security/SecurityAgentPlugins/"

# echo "Copying bundle into pkgroot..."
cp -vR "../Escrow Buddy/build/Release/Escrow Buddy.bundle" "$PKGROOT/Library/Security/SecurityAgentPlugins/Escrow Buddy.bundle"

echo "Building package..."
OUTFILE="$OUTPUTDIR/Escrow Buddy-$VERSION.pkg"
pkgbuild --root "$PKGROOT" \
    --identifier com.netflix.Escrow-Buddy \
    --version "$VERSION" \
    --scripts pkg \
    "$OUTFILE"

echo "Done."
echo "$OUTFILE"
# open "$OUTPUTDIR"
