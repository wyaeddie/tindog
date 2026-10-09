#!/bin/bash
# Build Suspension Tuner for this Mac and install it in /Applications.
# No Apple Developer account needed: the app is signed "to run locally" (ad-hoc).
# Usage:  ./build-mac.sh
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v xcodegen >/dev/null; then
  echo "▸ Installing XcodeGen (one time)…"
  brew install xcodegen
fi

echo "▸ Generating Xcode project…"
xcodegen generate --quiet

echo "▸ Building (Release, macOS)… this takes a minute the first time"
xcodebuild -project SuspensionTuner.xcodeproj -scheme SuspensionTuner \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath build -quiet \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="-" DEVELOPMENT_TEAM=""

APP="build/Build/Products/Release/SuspensionTuner.app"
DEST="/Applications/Suspension Tuner.app"

echo "▸ Installing to $DEST"
osascript -e 'quit app "Suspension Tuner"' 2>/dev/null || true
rm -rf "$DEST"
cp -R "$APP" "$DEST"

echo "✓ Installed. Opening…  (right-click its Dock icon → Options → Keep in Dock)"
open "$DEST"
