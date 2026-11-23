#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/configure.py
python3 -m unittest discover -s tests -p 'test_*.py' -v
mkdir -p build dist
xcodebuild -project WinterStudio.xcodeproj -scheme WinterStudio -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build | tee build/device-build.log
APP="build/DerivedData/Build/Products/Release-iphoneos/WinterStudio.app"
lipo "$APP/WinterStudio" -verify_arch arm64
PACKAGE="$(mktemp -d "$PWD/build/package.XXXXXX")"
mkdir -p "$PACKAGE/Payload"
ditto "$APP" "$PACKAGE/Payload/WinterStudio.app"
OUTPUT="$PWD/dist/WinterStudioDemo.ipa"
(cd "$PACKAGE" && /usr/bin/zip -qry "$OUTPUT" Payload)
python3 scripts/verify-ipa.py dist/WinterStudioDemo.ipa
shasum -a 256 dist/WinterStudioDemo.ipa > dist/WinterStudioDemo.sha256
cp README.txt dist/INSTALL.txt
