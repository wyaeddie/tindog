#!/bin/bash
# Archive the Suspension Tuner iPhone app for the App Store and export or upload it.
#
#   TEAM_ID=ABCDE12345 ./release.sh            # archive and export a signed .ipa to build/release/
#   TEAM_ID=ABCDE12345 ./release.sh --upload   # archive and upload straight to App Store Connect
#
# Needs: Xcode signed in to your Apple Developer account (Xcode → Settings → Accounts),
#        the app record created in App Store Connect with bundle ID solutions.wholestack.suspensiontuner.
# TEAM_ID is on developer.apple.com → Account → Membership details.
# Each upload needs a new build number; it defaults to the current date/time (e.g. 202610161430).
set -euo pipefail
cd "$(dirname "$0")"

DESTINATION="export"
for arg in "$@"; do
  case "$arg" in
    --upload) DESTINATION="upload" ;;
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

archive="$OUT/SuspensionTuner.xcarchive"
echo "▸ Archiving (build $BUILD_NUMBER)"
rm -rf "$archive"
xcodebuild archive \
  -project SuspensionTuner.xcodeproj -scheme SuspensionTuner -configuration Release \
  -destination "generic/platform=iOS" -archivePath "$archive" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  | grep -E "error:|warning: .*signing|ARCHIVE (SUCCEEDED|FAILED)" || true
[ -d "$archive" ] || { echo "✗ Archive failed — open SuspensionTuner.xcodeproj and use Product → Archive to see details"; exit 1; }

if [ "$DESTINATION" = upload ]; then echo "▸ Uploading"; else echo "▸ Exporting"; fi
xcodebuild -exportArchive \
  -archivePath "$archive" -exportPath "$OUT/ios" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" -allowProvisioningUpdates \
  | grep -E "error:|EXPORT (SUCCEEDED|FAILED)|Upload|Uploaded" || true
if [ "$DESTINATION" = export ] && ! ls "$OUT/ios"/*.ipa >/dev/null 2>&1; then
  echo "✗ Export failed — open the archive in Xcode (Window → Organizer) to see why"; exit 1
fi

if [ "$DESTINATION" = upload ]; then
  echo "✓ Uploaded. In about 10–30 minutes the build appears in App Store Connect → TestFlight."
else
  echo "✓ Signed app is in $OUT/ios."
  echo "  Upload them with the Transporter app, or re-run with --upload."
fi
