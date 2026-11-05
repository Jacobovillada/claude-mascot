#!/bin/sh
# Compila la mascota y la deja en ~/Applications/Mascota Claude.app
set -e
cd "$(dirname "$0")/.."
APP="$HOME/Applications/Mascota Claude.app"
mkdir -p "$APP/Contents/MacOS"
swiftc -O -swift-version 5 -o "$APP/Contents/MacOS/Mascota" Sources/*.swift
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Mascota Claude</string>
  <key>CFBundleIdentifier</key><string>io.github.mascota-claude</string>
  <key>CFBundleExecutable</key><string>Mascota</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>2.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "compilada: $APP"
