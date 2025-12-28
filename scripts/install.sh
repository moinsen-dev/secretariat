#!/bin/bash
#
# Install Script for Secretariat
#
# Installs the Secretariat daemon, CLI, and optionally the Flutter app.
# Sets up LaunchAgent for automatic daemon startup.
#
# Usage:
#   ./scripts/install.sh              # Install from build/release
#   ./scripts/install.sh --build      # Build first, then install
#   ./scripts/install.sh --uninstall  # Uninstall everything
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Installation paths
INSTALL_BIN="$HOME/.local/bin"
INSTALL_APP="/Applications"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
DATA_DIR="$HOME/Library/Application Support/Secretariat"

# LaunchAgent identifier
LAUNCH_AGENT_ID="dev.moinsen.secretariat.daemon"
LAUNCH_AGENT_PLIST="$LAUNCH_AGENTS/$LAUNCH_AGENT_ID.plist"

# Project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build/release"

# Parse arguments
DO_BUILD=false
DO_UNINSTALL=false
INSTALL_APP_FLAG=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --build)
            DO_BUILD=true
            shift
            ;;
        --uninstall)
            DO_UNINSTALL=true
            shift
            ;;
        --no-app)
            INSTALL_APP_FLAG=false
            shift
            ;;
        --help|-h)
            echo "Secretariat Installation Script"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --build       Build release binaries before installing"
            echo "  --uninstall   Uninstall Secretariat completely"
            echo "  --no-app      Skip Flutter app installation"
            echo "  --help, -h    Show this help message"
            echo ""
            echo "Installation locations:"
            echo "  Daemon:       $INSTALL_BIN/secd"
            echo "  CLI:          $INSTALL_BIN/sec"
            echo "  App:          $INSTALL_APP/Secretariat.app"
            echo "  LaunchAgent:  $LAUNCH_AGENT_PLIST"
            echo "  Data:         $DATA_DIR/"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Uninstall function
uninstall() {
    echo -e "${BLUE}=== Uninstalling Secretariat ===${NC}"
    echo ""

    # Stop daemon if running
    echo "Stopping daemon..."
    if launchctl list | grep -q "$LAUNCH_AGENT_ID"; then
        launchctl unload "$LAUNCH_AGENT_PLIST" 2>/dev/null || true
    fi
    pkill -f secd 2>/dev/null || true

    # Remove LaunchAgent
    if [[ -f "$LAUNCH_AGENT_PLIST" ]]; then
        echo "Removing LaunchAgent..."
        rm -f "$LAUNCH_AGENT_PLIST"
    fi

    # Remove binaries
    echo "Removing binaries..."
    rm -f "$INSTALL_BIN/secd"
    rm -f "$INSTALL_BIN/sec"

    # Remove app
    if [[ -d "$INSTALL_APP/Secretariat.app" ]]; then
        echo "Removing app..."
        rm -rf "$INSTALL_APP/Secretariat.app"
    fi

    echo ""
    echo -e "${YELLOW}Note: Data directory preserved at $DATA_DIR${NC}"
    echo "To remove all data (including secrets), run:"
    echo "  rm -rf \"$DATA_DIR\""
    echo ""
    echo -e "${GREEN}Secretariat uninstalled successfully!${NC}"
    exit 0
}

# Run uninstall if requested
if $DO_UNINSTALL; then
    uninstall
fi

echo -e "${BLUE}=== Installing Secretariat ===${NC}"
echo ""

# Build if requested
if $DO_BUILD; then
    echo -e "${YELLOW}Building release binaries...${NC}"
    "$SCRIPT_DIR/build-release.sh"
    echo ""
fi

# Check if build exists
if [[ ! -f "$BUILD_DIR/secd" ]] || [[ ! -f "$BUILD_DIR/sec" ]]; then
    echo -e "${RED}Error: Build not found at $BUILD_DIR${NC}"
    echo "Run with --build flag or execute ./scripts/build-release.sh first"
    exit 1
fi

# Create installation directories
echo "Creating directories..."
mkdir -p "$INSTALL_BIN"
mkdir -p "$LAUNCH_AGENTS"
mkdir -p "$DATA_DIR"

# Stop existing daemon
echo "Stopping existing daemon..."
if launchctl list | grep -q "$LAUNCH_AGENT_ID"; then
    launchctl unload "$LAUNCH_AGENT_PLIST" 2>/dev/null || true
fi
pkill -f secd 2>/dev/null || true
sleep 1

# Install binaries
echo "Installing binaries..."
cp "$BUILD_DIR/secd" "$INSTALL_BIN/"
cp "$BUILD_DIR/sec" "$INSTALL_BIN/"
chmod +x "$INSTALL_BIN/secd"
chmod +x "$INSTALL_BIN/sec"

# Install Flutter app
if $INSTALL_APP_FLAG && [[ -d "$BUILD_DIR/Secretariat.app" ]]; then
    echo "Installing app..."
    rm -rf "$INSTALL_APP/Secretariat.app"
    cp -r "$BUILD_DIR/Secretariat.app" "$INSTALL_APP/"
fi

# Create LaunchAgent plist
echo "Creating LaunchAgent for auto-start..."
cat > "$LAUNCH_AGENT_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LAUNCH_AGENT_ID</string>

    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_BIN/secd</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>

    <key>StandardOutPath</key>
    <string>$DATA_DIR/daemon.log</string>

    <key>StandardErrorPath</key>
    <string>$DATA_DIR/daemon.error.log</string>

    <key>WorkingDirectory</key>
    <string>$DATA_DIR</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>RUST_LOG</key>
        <string>info</string>
    </dict>
</dict>
</plist>
EOF

# Load LaunchAgent
echo "Starting daemon..."
launchctl load "$LAUNCH_AGENT_PLIST"
sleep 2

# Verify daemon is running
if launchctl list | grep -q "$LAUNCH_AGENT_ID"; then
    echo -e "${GREEN}  ✓ Daemon started successfully${NC}"
else
    echo -e "${YELLOW}  ! Daemon may not have started. Check logs at $DATA_DIR/daemon.log${NC}"
fi

# Add to PATH if not already
if [[ ":$PATH:" != *":$INSTALL_BIN:"* ]]; then
    echo ""
    echo -e "${YELLOW}Add the following to your shell profile (~/.zshrc or ~/.bashrc):${NC}"
    echo ""
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
fi

# Print summary
echo ""
echo -e "${GREEN}=== Installation Complete ===${NC}"
echo ""
echo "Installed components:"
echo "  Daemon:      $INSTALL_BIN/secd"
echo "  CLI:         $INSTALL_BIN/sec"
if $INSTALL_APP_FLAG && [[ -d "$INSTALL_APP/Secretariat.app" ]]; then
    echo "  App:         $INSTALL_APP/Secretariat.app"
fi
echo "  LaunchAgent: $LAUNCH_AGENT_PLIST"
echo "  Data:        $DATA_DIR/"
echo ""
echo "Quick start:"
echo "  sec init                  # Initialize vault with master password"
echo "  sec set MY_API_KEY value  # Add a secret"
echo "  sec list                  # List all secrets"
echo "  sec status                # Check daemon status"
echo ""
echo "For help: sec --help"
