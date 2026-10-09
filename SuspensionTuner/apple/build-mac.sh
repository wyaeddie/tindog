#!/bin/bash
# Build Suspension Tuner for this Mac and install it in /Applications.
# No Apple Developer account needed: the app is signed "to run locally" (ad-hoc).
# Usage:  ./build-mac.sh
# The full build log is saved to apple/build/build.log — paste it if something fails.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
LOG="$PWD/build/build.log"
STEP="starting"
trap 'echo; echo "✗ Failed during: $STEP"; echo "  Full log: $LOG"; echo "  Last lines:"; tail -n 25 "$LOG" 2>/dev/null' ERR

APP_NAME="Suspension Tuner"
DEST="/Applications/$APP_NAME.app"

STEP="checking Xcode"
if ! xcodebuild -version >"$LOG" 2>&1; then
  echo "✗ Xcode command-line tools aren't pointing at Xcode. Run this once, then re-run the script:"
  echo "    sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi
echo "▸ Using $(head -1 "$LOG")"

STEP="installing XcodeGen"
if ! command -v xcodegen >/dev/null; then
  if ! command -v brew >/dev/null; then
    echo "✗ Homebrew is needed to install XcodeGen. Install it from https://brew.sh then re-run."
    exit 1
  fi
  echo "▸ Installing XcodeGen (one time)…"
  brew install xcodegen >>"$LOG" 2>&1
fi

STEP="generating the Xcode project"
echo "▸ Generating Xcode project…"
xcodegen generate >>"$LOG" 2>&1

STEP="building the app (compile errors are listed below)"
echo "▸ Building (Release, macOS)… this takes a minute or two the first time"
# Local builds skip the App Store sandbox entitlement: an ad-hoc signed app with
# the sandbox can be refused at launch. The App Store build (Xcode → Archive) still uses it.
if ! xcodebuild -project SuspensionTuner.xcodeproj -scheme SuspensionTuner \
      -configuration Release -destination 'generic/platform=macOS' \
      -derivedDataPath build/DerivedData \
      CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="-" DEVELOPMENT_TEAM="" \
      "CODE_SIGN_ENTITLEMENTS[sdk=macosx*]=" CODE_SIGN_ENTITLEMENTS="" \
      >>"$LOG" 2>&1; then
  echo "✗ Build failed. Errors:"
  grep -E "error:|fatal error" "$LOG" | sort -u | head -n 30 || tail -n 40 "$LOG"
  echo "  Full log: $LOG"
  exit 1
fi

STEP="finding the built app"
APP=$(find build/DerivedData/Build/Products -maxdepth 2 -name "SuspensionTuner.app" -type d | head -1)
if [ -z "$APP" ]; then
  echo "✗ Build said it succeeded but no SuspensionTuner.app was found under build/DerivedData/Build/Products"
  find build/DerivedData/Build/Products -maxdepth 2 | head
  exit 1
fi

STEP="installing to $DEST"
echo "▸ Installing to $DEST"
osascript -e "quit app \"$APP_NAME\"" >/dev/null 2>&1 || true
sleep 1
rm -rf "$DEST"
cp -R "$APP" "$DEST"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

STEP="launching"
echo "▸ Launching…"
open "$DEST"
sleep 3
if pgrep -f "$DEST/Contents/MacOS/" >/dev/null; then
  echo "✓ Suspension Tuner is running. Right-click its Dock icon → Options → Keep in Dock."
else
  echo "✗ The app was installed but quit right after launch. Running it directly to show why:"
  "$DEST/Contents/MacOS/SuspensionTuner" 2>&1 | head -n 40 &
  sleep 5
  echo "  (Paste the lines above into the chat.)"
fi
