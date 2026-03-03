#!/bin/bash
echo "Uninstalling macOS Local MCP..."

# Remove binary
rm -f ~/bin/macos-local-mcp

# Remove admin app
rm -rf "/Applications/macOS Local MCP Server.app"

echo ""
echo "Removed binary and admin app."
echo ""
read -p "Remove config and logs (~/.macos-local-mcp/)? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf ~/.macos-local-mcp
    echo "Config and logs removed."
else
    echo "Config and logs kept at ~/.macos-local-mcp/"
fi

echo ""
echo "Uninstall complete."
echo "Remember to remove the macOS Local MCP Server entry from"
echo "your Claude Desktop or Claude Code config."
