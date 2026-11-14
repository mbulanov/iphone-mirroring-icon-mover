#!/bin/bash
set -euo pipefail
if [ "$#" -ne 0 ]; then
  echo 'Usage: ./build.sh (builds an isolated release candidate)' >&2
  exit 2
fi
repo_root="$(cd -- "$(dirname -- "$0")" && pwd)"
bundle="$repo_root/dist/iPhone Icon Mover RC.app"
mkdir -p "$bundle/Contents/MacOS" "$repo_root/.build/module-cache"
xcrun swiftc -swift-version 5 -O \
  -target "$(uname -m)-apple-macos15.0" \
  -module-cache-path "$repo_root/.build/module-cache" \
  "$repo_root/Sources/Core.swift" "$repo_root/Sources/main.swift" \
  -o "$bundle/Contents/MacOS/iPhoneIconMover"
cat > "$bundle/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.iphone-mirroring-icon-mover.rc</string>
<key>CFBundleName</key><string>iPhone Icon Mover RC</string>
<key>CFBundleDisplayName</key><string>iPhone Icon Mover RC</string>
<key>CFBundleExecutable</key><string>iPhoneIconMover</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>15.0</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
/usr/bin/plutil -lint "$bundle/Contents/Info.plist"
/usr/bin/codesign --force --sign - "$bundle"
/usr/bin/codesign --verify --strict "$bundle"
echo "Built: $bundle"
echo 'This is a separate app identity. Rebuilding an authorized copy may require renewing its permission.'
