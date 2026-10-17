#!/bin/bash
# Build Suspension Tuner and open it in the iOS Simulator.
# Usage, from the apple folder:  bash run.sh
set -u
cd "$(dirname "$0")"

say()  { printf "\n\033[1;33m▶ %s\033[0m\n" "$1"; }
fail() { printf "\n\033[1;31m✖ %s\033[0m\n" "$1"; exit 1; }

say "Checking Xcode"
if ! xcodebuild -version >/dev/null 2>&1; then
    fail "Terminal isn't using the full Xcode. Run this once, enter your Mac password, then run this script again:
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
fi
xcodebuild -version | head -1

say "Checking XcodeGen"
if ! command -v xcodegen >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
        brew install xcodegen || fail "Couldn't install XcodeGen with Homebrew."
    else
        fail "XcodeGen isn't installed. Install Homebrew from https://brew.sh, then run:  brew install xcodegen"
    fi
fi

say "Generating the Xcode project"
xcodegen generate || fail "XcodeGen couldn't read project.yml. Make sure you're in the apple folder."

say "Finding an iPhone simulator"
LINE=$(xcrun simctl list devices available | grep -E "iPhone .*Pro \(" | grep -v Max | tail -1)
[ -z "$LINE" ] && LINE=$(xcrun simctl list devices available | grep -E "iPhone" | tail -1)
[ -z "$LINE" ] && fail "No iPhone simulators installed. In Xcode: Settings → Components → install an iOS simulator."
UDID=$(echo "$LINE" | grep -oE "[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}")
NAME=$(echo "$LINE" | sed -E 's/^ *//; s/ \(.*//')
echo "$NAME ($UDID)"

# Build outside the project folder: external drives can break code signing.
BUILD="$HOME/Library/Developer/SuspensionTunerBuild"
LOG="$BUILD/build.log"
mkdir -p "$BUILD"

say "Building (the first build takes a minute or two)"
if ! xcodebuild -project SuspensionTuner.xcodeproj -scheme SuspensionTuner \
        -destination "id=$UDID" -derivedDataPath "$BUILD" build >"$LOG" 2>&1; then
    echo
    grep -E "error:|BUILD FAILED" "$LOG" | sort -u | head -40
    fail "Build failed. Copy the lines above (full log: $LOG) and send them over."
fi
echo "Build succeeded"

APP=$(find "$BUILD/Build/Products" -maxdepth 2 -name "SuspensionTuner.app" -path "*iphonesimulator*" | head -1)
[ -z "$APP" ] && fail "Built, but couldn't find SuspensionTuner.app in $BUILD/Build/Products."

say "Opening the simulator"
xcrun simctl boot "$UDID" 2>/dev/null || true
# Xcode 26 and earlier ship Simulator.app; Xcode 27 replaced it with Device Hub.
if ! open -a Simulator 2>/dev/null; then
    HUB=$(find "$(xcode-select -p)/../.." -maxdepth 5 -name "DeviceHub.app" 2>/dev/null | head -1)
    if [ -n "$HUB" ]; then open "$HUB"; else open -a "Device Hub" 2>/dev/null || open -a DeviceHub 2>/dev/null || \
        echo "Open Xcode → Window → Devices and Simulators to see the simulator screen."; fi
fi
xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || true

say "Installing and launching"
xcrun simctl install "$UDID" "$APP" || fail "Couldn't install the app on the simulator."
xcrun simctl launch "$UDID" solutions.wholestack.suspensiontuner || fail "Installed, but couldn't launch the app."

printf "\n\033[1;32m✔ Suspension Tuner is running on %s\033[0m\n" "$NAME"
