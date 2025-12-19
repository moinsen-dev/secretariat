#!/bin/bash
# Secretariat - Quick Setup Check
# Just verifies prerequisites - actual project structure created on demand

set -e

echo "Secretariat - Prerequisites Check"
echo "================================="

# Required tools
check_tool() {
    if command -v "$1" &> /dev/null; then
        echo "✓ $1: $($1 --version 2>&1 | head -1)"
        return 0
    else
        echo "✗ $1: NOT FOUND"
        return 1
    fi
}

missing=0

# Core requirements
check_tool rustc || missing=1
check_tool cargo || missing=1
check_tool flutter || missing=1
check_tool dart || missing=1
check_tool python3 || missing=1
check_tool node || missing=1

echo ""

if [ $missing -eq 1 ]; then
    echo "Some tools are missing. Install them before proceeding."
    exit 1
fi

echo "All prerequisites installed!"
echo ""
echo "To start development:"
echo "  1. Create Rust workspace: cargo init daemon && cargo init cli"
echo "  2. Create Flutter app:    flutter create app --platforms=macos,windows,linux"
echo "  3. Check features:        autocoder-db list --project $(pwd)"
echo ""
