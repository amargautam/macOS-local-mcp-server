#!/bin/bash
set -e

echo "Building macOS Local MCP Server..."
swift build -c release

echo "Installing server binary..."
mkdir -p ~/bin
cp .build/release/macos-local-mcp ~/bin/macos-local-mcp
chmod +x ~/bin/macos-local-mcp

echo "Creating config directory..."
mkdir -p ~/.macos-local-mcp

echo "Creating default config (read-only)..."
if [ ! -f ~/.macos-local-mcp/config.json ]; then
    cat > ~/.macos-local-mcp/config.json << 'CONF'
{
    "logLevel": "normal",
    "logMaxSizeMB": 10,
    "enabledModules": {
        "reminders": {"read": true, "write": false},
        "calendar": {"read": true, "write": false},
        "contacts": {"read": true, "write": false},
        "finder": {"read": true, "write": false},
        "mail": {"read": true, "write": false},
        "notes": {"read": true, "write": false},
        "messages": {"read": true, "write": false},
        "safari": {"read": true, "write": false},
        "shortcuts": {"read": true, "write": false},
        "crossapp": {"read": true, "write": false}
    }
}
CONF
fi

echo "Installing admin app..."
# Generate icon
ICON_DIR="/tmp/MacOSLocalMCPServer.iconset"
mkdir -p "$ICON_DIR"
swift "$(dirname "$0")/scripts/generate_icon.swift" 2>/dev/null || true

APP_DIR="/Applications/macOS Local MCP Server.app"
CONTENTS_DIR="$APP_DIR/Contents"
mkdir -p "$CONTENTS_DIR/MacOS"
mkdir -p "$CONTENTS_DIR/Resources"

cp .build/release/MacOSLocalMCPAdmin "$CONTENTS_DIR/MacOS/macOS Local MCP Server"
chmod +x "$CONTENTS_DIR/MacOS/macOS Local MCP Server"

# Copy icon if it was generated
if [ -f /tmp/MacOSLocalMCPServer.icns ]; then
    cp /tmp/MacOSLocalMCPServer.icns "$CONTENTS_DIR/Resources/AppIcon.icns"
fi

cat > "$CONTENTS_DIR/Info.plist" << 'INFOPLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>macOS Local MCP Server</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.amargautam.macos-local-mcp-admin</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>macOS Local MCP Server</string>
    <key>CFBundleDisplayName</key>
    <string>macOS Local MCP Server</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
</dict>
</plist>
INFOPLIST

touch "$APP_DIR"

echo ""
echo "Installation complete!"
echo ""
echo "  Server binary: ~/bin/macos-local-mcp"
echo "  Admin app:     /Applications/macOS Local MCP Server.app"
echo "  Config:        ~/.macos-local-mcp/config.json"
echo ""
echo "Add this to your Claude Desktop config:"
echo "  ~/Library/Application Support/Claude/claude_desktop_config.json"
echo ""
echo '  "mcpServers": {'
echo '    "macOS Local MCP Server": {'
echo '      "command": "'$HOME'/bin/macos-local-mcp"'
echo '    }'
echo '  }'
echo ""
