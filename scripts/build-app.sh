#!/bin/bash
set -e

echo "Building PortPulse..."

# Check for Xcode
if [ -d "/Applications/Xcode-beta.app" ]; then
    export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
elif [ -d "/Applications/Xcode.app" ]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
else
    echo "Error: Xcode not found"
    exit 1
fi

# Build release frameworks
echo "[1/4] Building frameworks..."
swift build -c release --target PortPulseCore --target PortPulseHardware --target PortPulseMonitor 2>&1 | tail -3

# Create static libraries
echo "[2/4] Creating static libraries..."
rm -rf /tmp/portpulse-libs
mkdir -p /tmp/portpulse-libs
ar rcs /tmp/portpulse-libs/libPortPulseCore.a .build/out/Products/Release/PortPulseCore.o
ar rcs /tmp/portpulse-libs/libPortPulseHardware.a .build/out/Products/Release/PortPulseHardware.o
ar rcs /tmp/portpulse-libs/libPortPulseMonitor.a .build/out/Products/Release/PortPulseMonitor.o

# Build app bundle
echo "[3/4] Building app bundle..."
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
cat > "$APP_DIR/Contents/Info.plist" << 'EOF'
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
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

# Sign app
echo "[4/4] Signing app..."
codesign --force --sign - --identifier com.portpulse.app "$APP_DIR"

# Build CLI
swift build -c release --product portpulse 2>&1 | tail -2
cp .build/release/portpulse "$APP_DIR/Contents/MacOS/portpulse-cli"

echo ""
echo "Build complete: $APP_DIR"
echo "  App: $APP_DIR/Contents/MacOS/PortPulse"
echo "  CLI: $APP_DIR/Contents/MacOS/portpulse-cli"
echo ""
echo "To install:"
echo "  cp -rf $APP_DIR /Applications/"
echo "  ln -sf /Applications/PortPulse.app/Contents/MacOS/portpulse-cli /usr/local/bin/portpulse"
