#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="CodexStatusBar"
DISPLAY_NAME="Codex Status Bar"
BUNDLE_ID="${BUNDLE_ID:-com.jagatees.codexstatusbar}"
VERSION="${VERSION:-1.0.0}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
APP="build/${APP_NAME}.app"
BIN="${APP}/Contents/MacOS/${APP_NAME}"
MODULE_CACHE="build/module-cache"

if [[ "${1:-}" == "--clean" ]]; then
  rm -rf build
  echo "Removed build output."
  exit 0
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$MODULE_CACHE"

echo "Compiling ${DISPLAY_NAME}..."
compile() {
  swiftc -O -warnings-as-errors -module-cache-path "$MODULE_CACHE" "$@" \
    Sources/CodexStatusBar/*.swift -o "$BIN" \
    -framework AppKit -framework UserNotifications
}

if ! compile; then
  # Some Command Line Tools releases briefly ship a newer default SDK than
  # their Swift compiler. Retry with the stable SDK when it is available.
  FALLBACK_SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX15.sdk"
  if [[ ! -d "$FALLBACK_SDK" ]]; then
    echo "No compatible fallback macOS SDK was found." >&2
    exit 1
  fi
  echo "Default SDK was incompatible; retrying with ${FALLBACK_SDK}."
  compile -sdk "$FALLBACK_SDK"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>${DISPLAY_NAME}</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleExecutable</key><string>${APP_NAME}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHumanReadableCopyright</key><string>Copyright 2026 Codex Status Bar contributors</string>
</dict>
</plist>
PLIST

cp hooks/state.js hooks/codex-status-hook.js hooks/codex-notify.js hooks/install.js hooks/uninstall.js "$APP/Contents/Resources/"
codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--dmg" ]]; then
  DMG="build/${APP_NAME}.dmg"
  STAGE="build/dmg-stage"
  rm -rf "$STAGE" "$DMG"
  mkdir -p "$STAGE"
  cp -R "$APP" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  hdiutil create -volname "$DISPLAY_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
  rm -rf "$STAGE"
  echo "Built $DMG"
fi
