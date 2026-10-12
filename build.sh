#!/bin/zsh
# Builds Penderie.app into ./build (no Xcode needed, just the Command Line Tools).
# ./build.sh --install also copies it to /Applications and launches it.
set -euo pipefail
cd "$(dirname "$0")"
APP=build/Penderie.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -swift-version 5 -parse-as-library \
  -target "$(uname -m)-apple-macos26.0" \
  Sources/*.swift -o "$APP/Contents/MacOS/Penderie"
cp Info.plist "$APP/Contents/Info.plist"
[[ -f AppIcon.icns ]] && cp AppIcon.icns "$APP/Contents/Resources/"
codesign --force --sign - "$APP" >/dev/null
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x Penderie 2>/dev/null || true
  rm -rf /Applications/Penderie.app
  cp -R "$APP" /Applications/
  open /Applications/Penderie.app
  echo "Installed to /Applications — look for the hanger in your menu bar."
fi
