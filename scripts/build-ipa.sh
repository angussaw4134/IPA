#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Run this build on a Mac with Xcode, or use the GitHub Actions workflow." >&2
  exit 1
fi
python3 scripts/configure.py
mkdir -p build dist
xcodebuild -version
plutil -lint App/Info.plist AccessHubTest.xcodeproj/project.pbxproj
xcodebuild -project AccessHubTest.xcodeproj -scheme AccessHubTest \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  build | tee build/xcodebuild.log

APP="build/DerivedData/Build/Products/Release-iphoneos/AccessHubTest.app"
test -f "$APP/AccessHubTest"
lipo -verify_arch arm64 "$APP/AccessHubTest"
PACKAGE="$(mktemp -d "$PWD/build/ipa.XXXXXX")"
mkdir -p "$PACKAGE/Payload"
ditto "$APP" "$PACKAGE/Payload/AccessHubTest.app"
# SideStore signs this package with the tester's account on installation.
OUTPUT="$PWD/dist/AccessHubTest.ipa"
(cd "$PACKAGE" && /usr/bin/zip -qry "$OUTPUT" Payload)
python3 scripts/verify-ipa.py "$OUTPUT"
shasum -a 256 "$OUTPUT" > dist/AccessHubTest.sha256
echo "IPA ready: $OUTPUT"
