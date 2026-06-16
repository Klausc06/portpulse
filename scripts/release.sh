#!/bin/bash
set -e

VERSION="${1:-0.1.0}"
echo "Building PortPulse v${VERSION} for distribution..."

# Check for Xcode
if [ -d "/Applications/Xcode-beta.app" ]; then
    export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
elif [ -d "/Applications/Xcode.app" ]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
else
    echo "Error: Xcode not found"
    exit 1
fi

# Step 1: Build release frameworks
echo "[1/5] Building frameworks..."
swift build -c release --target PortPulseCore --target PortPulseHardware --target PortPulseMonitor 2>&1 | tail -3

# Step 2: Create static libraries
echo "[2/5] Creating static libraries..."
rm -rf /tmp/portpulse-libs
mkdir -p /tmp/portpulse-libs
ar rcs /tmp/portpulse-libs/libPortPulseCore.a .build/out/Products/Release/PortPulseCore.o
ar rcs /tmp/portpulse-libs/libPortPulseHardware.a .build/out/Products/Release/PortPulseHardware.o
ar rcs /tmp/portpulse-libs/libPortPulseMonitor.a .build/out/Products/Release/PortPulseMonitor.o

# Step 3: Build app bundle
echo "[3/5] Building app bundle..."
APP_DIR="dist/PortPulse.app"
rm -rf dist
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

swiftc -O \
    -framework SwiftUI -framework AppKit -framework IOKit -framework UserNotifications \
    -I .build/out/Products/Release \
    -L /tmp/portpulse-libs \
    -lPortPulseCore -lPortPulseHardware -lPortPulseMonitor \
    -target arm64-apple-macos14.0 \
    -parse-as-library \
    -o "$APP_DIR/Contents/MacOS/PortPulse" \
    Sources/PortPulseApp/*.swift Sources/PortPulseApp/**/*.swift

# Create Info.plist
cat > "$APP_DIR/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>PortPulse</string>
    <key>CFBundleIdentifier</key>
    <string>com.portpulse.app</string>
    <key>CFBundleName</key>
    <string>PortPulse</string>
    <key>CFBundleDisplayName</key>
    <string>PortPulse</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# Step 4: Sign app
echo "[4/5] Signing app..."
codesign --force --sign - --identifier com.portpulse.app "$APP_DIR"

# Step 5: Create DMG
echo "[5/5] Creating DMG..."
DMG_DIR="dist/dmg"
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"
cp -R "$APP_DIR" "$DMG_DIR/"

hdiutil create -volname "PortPulse" \
    -srcfolder "$DMG_DIR" \
    -ov -format UDZO \
    "dist/PortPulse-${VERSION}.dmg"

# Also create a zip for Homebrew
cd dist
zip -r "PortPulse-${VERSION}.zip" PortPulse.app
cd ..

echo ""
echo "Build complete:"
echo "  App: dist/PortPulse.app"
echo "  DMG: dist/PortPulse-${VERSION}.dmg"
echo "  ZIP: dist/PortPulse-${VERSION}.zip"
echo ""
echo "To install locally:"
echo "  cp -rf dist/PortPulse.app /Applications/"
echo ""
echo "To publish to Homebrew:"
echo "  1. Create GitHub release with PortPulse-${VERSION}.zip"
echo "  2. Update Casks/portpulse.rb with correct sha256"
echo "  3. Create homebrew tap repo"
echo "  4. Copy portpulse.rb to tap"
