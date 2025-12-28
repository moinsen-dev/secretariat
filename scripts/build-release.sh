#!/bin/bash
#
# Build Release Script for Secretariat
#
# Creates optimized release builds for macOS (arm64 and x86_64).
# Can create a universal binary that works on both Intel and Apple Silicon Macs.
#
# Usage:
#   ./scripts/build-release.sh          # Build for current architecture
#   ./scripts/build-release.sh --universal  # Build universal binary (arm64 + x86_64)
#   ./scripts/build-release.sh --help   # Show help
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build/release"

# Parse arguments
BUILD_UNIVERSAL=false
SKIP_FLUTTER=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --universal)
            BUILD_UNIVERSAL=true
            shift
            ;;
        --skip-flutter)
            SKIP_FLUTTER=true
            shift
            ;;
        --help|-h)
            echo "Secretariat Release Build Script"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --universal     Build universal binary (arm64 + x86_64)"
            echo "  --skip-flutter  Skip Flutter app build"
            echo "  --help, -h      Show this help message"
            echo ""
            echo "Output:"
            echo "  build/release/secd        Daemon binary"
            echo "  build/release/sec         CLI binary"
            echo "  build/release/Secretariat.app  Flutter app (if not skipped)"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}=== Secretariat Release Build ===${NC}"
echo ""

# Create build directory
mkdir -p "$BUILD_DIR"

# Function to build Rust components
build_rust() {
    local target=$1
    local display_name=$2

    echo -e "${YELLOW}Building Rust components for $display_name...${NC}"

    cd "$PROJECT_ROOT"

    # Build daemon
    echo "  Building daemon..."
    if [[ -n "$target" ]]; then
        cargo build --release --target "$target" -p secd
        cp "$PROJECT_ROOT/target/$target/release/secd" "$BUILD_DIR/secd-$target"
    else
        cargo build --release -p secd
        cp "$PROJECT_ROOT/target/release/secd" "$BUILD_DIR/"
    fi

    # Build CLI
    echo "  Building CLI..."
    if [[ -n "$target" ]]; then
        cargo build --release --target "$target" -p sec
        cp "$PROJECT_ROOT/target/$target/release/sec" "$BUILD_DIR/sec-$target"
    else
        cargo build --release -p sec
        cp "$PROJECT_ROOT/target/release/sec" "$BUILD_DIR/"
    fi

    echo -e "${GREEN}  ✓ Rust components built${NC}"
}

# Function to create universal binary
create_universal() {
    echo -e "${YELLOW}Creating universal binaries...${NC}"

    # Daemon
    lipo -create \
        "$BUILD_DIR/secd-aarch64-apple-darwin" \
        "$BUILD_DIR/secd-x86_64-apple-darwin" \
        -output "$BUILD_DIR/secd"

    # CLI
    lipo -create \
        "$BUILD_DIR/sec-aarch64-apple-darwin" \
        "$BUILD_DIR/sec-x86_64-apple-darwin" \
        -output "$BUILD_DIR/sec"

    # Clean up architecture-specific binaries
    rm -f "$BUILD_DIR/secd-aarch64-apple-darwin" "$BUILD_DIR/secd-x86_64-apple-darwin"
    rm -f "$BUILD_DIR/sec-aarch64-apple-darwin" "$BUILD_DIR/sec-x86_64-apple-darwin"

    echo -e "${GREEN}  ✓ Universal binaries created${NC}"
}

# Function to build Flutter app
build_flutter() {
    echo -e "${YELLOW}Building Flutter app...${NC}"

    cd "$PROJECT_ROOT/app"

    # Get dependencies
    flutter pub get

    # Build macOS app
    flutter build macos --release

    # Copy to build directory
    cp -r "build/macos/Build/Products/Release/Secretariat.app" "$BUILD_DIR/"

    echo -e "${GREEN}  ✓ Flutter app built${NC}"
}

# Main build process
if $BUILD_UNIVERSAL; then
    echo "Building universal binaries for Intel + Apple Silicon..."
    echo ""

    # Check if both targets are available
    if ! rustup target list --installed | grep -q "aarch64-apple-darwin"; then
        echo -e "${YELLOW}Installing aarch64-apple-darwin target...${NC}"
        rustup target add aarch64-apple-darwin
    fi

    if ! rustup target list --installed | grep -q "x86_64-apple-darwin"; then
        echo -e "${YELLOW}Installing x86_64-apple-darwin target...${NC}"
        rustup target add x86_64-apple-darwin
    fi

    # Build for both architectures
    build_rust "aarch64-apple-darwin" "Apple Silicon (arm64)"
    build_rust "x86_64-apple-darwin" "Intel (x86_64)"

    # Create universal binaries
    create_universal
else
    # Build for current architecture only
    build_rust "" "current architecture"
fi

# Build Flutter app
if ! $SKIP_FLUTTER; then
    build_flutter
else
    echo -e "${YELLOW}Skipping Flutter app build${NC}"
fi

# Show results
echo ""
echo -e "${GREEN}=== Build Complete ===${NC}"
echo ""
echo "Output files in $BUILD_DIR:"
ls -lh "$BUILD_DIR"

# Show binary info
echo ""
echo "Binary information:"
file "$BUILD_DIR/secd"
file "$BUILD_DIR/sec"

# Get version from workspace Cargo.toml
VERSION=$(grep '^version' "$PROJECT_ROOT/Cargo.toml" | head -1 | sed 's/version = "\(.*\)"/\1/')
echo ""
echo -e "${GREEN}Secretariat v$VERSION built successfully!${NC}"
