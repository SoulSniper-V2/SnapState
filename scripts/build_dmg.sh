#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/SnapState.xcodeproj"
SCHEME="SnapState"
APP_NAME="SnapState"
VOL_NAME="SnapState"

BUILD_DIR="$ROOT_DIR/.build-release"
STAGING_DIR="$ROOT_DIR/.dmg-staging"
FINAL_DMG="$ROOT_DIR/SnapState.dmg"
RELEASE_APP="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"

function require_tool() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required tool: $1" >&2
        exit 1
    fi
}

require_tool xcodebuild
require_tool create-dmg
require_tool hdiutil

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
    rm -rf "$BUILD_DIR"
fi

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
    echo "Building $APP_NAME Release app..."
    DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
    xcodebuild \
      -project "$PROJECT_PATH" \
      -scheme "$SCHEME" \
      -configuration Release \
      -derivedDataPath "$BUILD_DIR" \
      CODE_SIGNING_ALLOWED=NO \
      CODE_SIGNING_REQUIRED=NO \
      build
else
    echo "Skipping build and reusing existing Release app..."
fi

if [[ ! -d "$RELEASE_APP" ]]; then
    echo "Release app not found at $RELEASE_APP" >&2
    exit 1
fi

echo "Preparing DMG staging..."
cp -R "$RELEASE_APP" "$STAGING_DIR/"

echo "Detaching stale SnapState disk images..."
hdiutil info | awk '/\/Volumes\/SnapState/ { print $1 }' | while read -r device; do
    [[ -n "$device" ]] || continue
    hdiutil detach "$device" -force -quiet || true
done

rm -f "$FINAL_DMG"

echo "Creating DMG with create-dmg..."
create-dmg \
  --volname "$VOL_NAME" \
  --window-pos 180 140 \
  --window-size 640 360 \
  --icon-size 112 \
  --text-size 14 \
  --icon "$APP_NAME.app" 170 170 \
  --hide-extension "$APP_NAME.app" \
  --app-drop-link 470 170 \
  --format UDZO \
  --filesystem HFS+ \
  --hdiutil-quiet \
  --hdiutil-retries 8 \
  "$FINAL_DMG" \
  "$STAGING_DIR"

echo "Created $FINAL_DMG"
