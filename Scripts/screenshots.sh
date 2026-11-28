#!/bin/zsh
# Run: Scripts/screenshots.sh
# Regenerates the README logo and screenshots. Runs the UI tests on a fresh simulator with a clean status bar,
# then copies the screenshots they capture into docs/. Needs the project generated with `xcodegen generate`.
set -euo pipefail

root=${0:A:h:h}
device_type=com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro
runtime=com.apple.CoreSimulator.SimRuntime.iOS-27-2
# Screen width in points over corner radius in points, for iPhone 18 Pro.
screen_corner=0.137
# Width in pixels: twice the size the README shows them.
screen_width=560

# README name, appearance, the name the UI test gives its screenshot, and the test that takes it.
# The README leads with dark mode and shows light once. Under a dark appearance, the tests' -dark screens are dark
# throughout, status bar included.
shots=(
  main dark main-dark testScreenshots
  ringing dark ringing testRingAddRepeatStop
  main-light light main-light testScreenshots
  quick-start dark quick testQuickStartSavesOnlyLabelled
  category dark category-dark testScreenshots
  icon dark icon testChooseIcon
  widgets dark widgets-dark testWidgetGallery
)

work=$(mktemp -d)
udid=$(xcrun simctl create readme-screenshots $device_type $runtime)
trap 'xcrun simctl delete "$udid" 2>/dev/null; rm -rf "$work"' EXIT

xcrun simctl bootstatus "$udid" -b > /dev/null
xcrun simctl status_bar "$udid" override --time 9:41 --batteryState discharging --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiBars 3 --dataNetwork wifi

xcodebuild_quietly() {
  xcodebuild -quiet -project "$root/Timing.xcodeproj" -scheme Timing -destination "id=$udid" \
    -derivedDataPath "$work/build" "$@" > "$work/xcodebuild.log" 2>&1 || {
    tail -n 40 "$work/xcodebuild.log"
    exit 1
  }
}

echo "Building..."
xcodebuild_quietly build-for-testing

for appearance in dark light; do
  tests=()
  for name look capture test in $shots; do
    [[ $look == $appearance ]] && tests+=(-only-testing:TimingUITests/TimingUITests/$test)
  done
  echo "Capturing $appearance screenshots..."
  xcrun simctl ui "$udid" appearance $appearance
  xcodebuild_quietly test-without-building -resultBundlePath "$work/$appearance.xcresult" ${(u)tests}
  xcrun xcresulttool export attachments --path "$work/$appearance.xcresult" --output-path "$work/$appearance" > /dev/null
done

mkdir -p "$root/docs/screenshots"
for name look capture test in $shots; do
  file=$(jq -r --arg capture "$capture" \
    '.[].attachments[] | select(.suggestedHumanReadableName | startswith($capture + "_")) | .exportedFileName' \
    "$work/$look/manifest.json" | head -n 1)
  if [[ -z $file ]]; then
    echo "$test took no screenshot named $capture" >&2
    exit 1
  fi
  swift "$root/Scripts/readme_image.swift" "$work/$look/$file" "$root/docs/screenshots/$name.png" $screen_width $screen_corner
done

# The icon at 256 pixels with the corner of an iOS app icon.
swift "$root/Scripts/readme_image.swift" "$root/Resources/Assets.xcassets/AppIcon.appiconset/icon.png" \
  "$root/docs/logo.png" 256 0.2237
echo "Updated docs/logo.png and docs/screenshots/"
