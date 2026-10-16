#!/bin/bash
# Archive Suspension Tuner for the App Store — iPhone/iPad and Mac — and export or upload it.
#
#   TEAM_ID=ABCDE12345 ./release.sh            # archive iOS + Mac, export signed builds to build/release/
#   TEAM_ID=ABCDE12345 ./release.sh --upload   # archive and upload straight to App Store Connect
#   TEAM_ID=ABCDE12345 ./release.sh ios        # only iPhone/iPad   (or: mac)
#
# Needs: Xcode signed in to your Apple Developer account (Xcode → Settings → Accounts),
#        the app record created in App Store Connect with bundle ID solutions.wholestack.suspensiontuner.
# TEAM_ID is on developer.apple.com → Account → Membership details.
# Each upload needs a new build number; it defaults to the current date/time (e.g. 202610161430).
set -euo pipefail
cd "$(dirname "$0")"

PLATFORMS="ios mac"
DESTINATION="export"
for arg in "$@"; do
  case "$arg" in
    --upload) DESTINATION="upload" ;;
    ios|mac)  PLATFORMS="$arg" ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

if [ -z "${TEAM_ID:-}" ]; then
  echo "✗ Set your Apple Developer Team ID first, e.g.:  TEAM_ID=ABCDE12345 ./release.sh"
  echo "  (developer.apple.com → Account → Membership details → Team ID)"
  exit 1
fi
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"
OUT="build/release"
mkdir -p "$OUT"

command -v xcodegen >/dev/null || brew install xcodegen
echo "▸ Generating Xcode project"
xcodegen generate --quiet

echo "▸ Running unit tests"
swift test --quiet

sed -e "s/TEAM_ID_PLACEHOLDER/$TEAM_ID/" -e "s/DESTINATION_PLACEHOLDER/$DESTINATION/" \
  release/ExportOptions.plist > "$OUT/ExportOptions.plist"

for platform in $PLATFORMS; do
  if [ "$platform" = ios ]; then dest="generic/platform=iOS"; else dest="generic/platform=macOS"; fi
  archive="$OUT/SuspensionTuner-$platform.xcarchive"
  echo "▸ Archiving $platform (build $BUILD_NUMBER)"
  rm -rf "$archive"
  xcodebuild archive \
    -project SuspensionTuner.xcodeproj -scheme SuspensionTuner -configuration Release \
    -destination "$dest" -archivePath "$archive" \
    -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    | grep -E "error:|warning: .*signing|ARCHIVE (SUCCEEDED|FAILED)" || true
  [ -d "$archive" ] || { echo "✗ Archive failed for $platform — open SuspensionTuner.xcodeproj and use Product → Archive to see details"; exit 1; }

  if [ "$DESTINATION" = upload ]; then echo "▸ Uploading $platform"; else echo "▸ Exporting $platform"; fi
  xcodebuild -exportArchive \
    -archivePath "$archive" -exportPath "$OUT/$platform" \
    -exportOptionsPlist "$OUT/ExportOptions.plist" -allowProvisioningUpdates \
    | grep -E "error:|EXPORT (SUCCEEDED|FAILED)|Upload|Uploaded" || true
  if [ "$DESTINATION" = export ] && ! ls "$OUT/$platform"/*.ipa "$OUT/$platform"/*.pkg >/dev/null 2>&1; then
    echo "✗ Export failed for $platform — open the archive in Xcode (Window → Organizer) to see why"; exit 1
  fi
done

if [ "$DESTINATION" = upload ]; then
  echo "✓ Uploaded. In about 10–30 minutes the build appears in App Store Connect → TestFlight."
else
  echo "✓ Signed builds are in $OUT/ios and $OUT/mac."
  echo "  Upload them with the Transporter app, or re-run with --upload."
fi
