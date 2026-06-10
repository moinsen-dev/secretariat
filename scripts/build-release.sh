#!/bin/bash
#
# Build Release Script for Secretariat
#
# Creates optimized release builds for macOS (arm64 and x86_64).
# Can create a universal binary that works on both Intel and Apple Silicon Macs.
# Optional: code signing, notarization, DMG creation, and GitHub release.
#
# Usage:
#   ./scripts/build-release.sh                              # Build for current architecture
#   ./scripts/build-release.sh --universal                   # Build universal binary (arm64 + x86_64)
#   ./scripts/build-release.sh --dmg                         # Build + create DMG
#   ./scripts/build-release.sh --sign                        # Build + sign (needs developer ID cert)
#   ./scripts/build-release.sh --notarize                    # Build + sign + notarize
#   ./scripts/build-release.sh --release                     # Full release: universal + dmg + sign + notarize
#   ./scripts/build-release.sh --help                        # Show help
#
# Prerequisites for signing/notarization (run on Mac with Developer ID cert):
#   - Apple Developer ID Application certificate in keychain
#   - Notarytool credentials configured:
#     xcrun notarytool store-credentials "SECRETARIAT" --apple-id "email@example.com" --team-id "XXXXXXXXXX"
#
# Output:
#   build/release/secd                  Daemon binary
#   build/release/sec                   CLI binary
#   build/release/Secretariat.app       Flutter app (if not skipped)
#   build/release/Secretariat.dmg       DMG (if --dmg or --release)
#   build/release/Secretariat.zip       Zipped app for notarization

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build/release"
APP_DIR="$PROJECT_ROOT/app"

# Notarytool profile name (configured via `xcrun notarytool store-credentials`)
NOTARY_PROFILE="${NOTARY_PROFILE:-SECRETARIAT}"

# Developer ID for code signing
DEV_ID="${DEV_ID:-Developer ID Application: Ulrich Diedrichsen}"

# Team ID for notarization
TEAM_ID="${TEAM_ID:-}"

# Parse arguments
BUILD_UNIVERSAL=false
SKIP_FLUTTER=false
DO_SIGN=false
DO_NOTARIZE=false
DO_DMG=false
DO_GITHUB_RELEASE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --universal)       BUILD_UNIVERSAL=true; shift ;;
        --skip-flutter)    SKIP_FLUTTER=true; shift ;;
        --sign)            DO_SIGN=true; shift ;;
        --notarize)        DO_SIGN=true; DO_NOTARIZE=true; shift ;;
        --dmg)             DO_DMG=true; shift ;;
        --release)         BUILD_UNIVERSAL=true; DO_SIGN=true; DO_NOTARIZE=true; DO_DMG=true; shift ;;
        --github-release)  DO_GITHUB_RELEASE=true; shift ;;
        --dry-run)         DRY_RUN=true; shift ;;
        --help|-h)
            echo "Secretariat Release Build Script"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --universal       Build universal binary (arm64 + x86_64)"
            echo "  --skip-flutter    Skip Flutter app build"
            echo "  --sign            Sign binaries with Developer ID"
            echo "  --notarize        Sign + submit for Apple notarization"
            echo "  --dmg             Create distributable DMG"
            echo "  --release         Full release: universal + sign + notarize + dmg"
            echo "  --github-release  Create a GitHub Release with version tag"
            echo "  --dry-run         Print what would be done without doing it"
            echo "  --help, -h        Show this help"
            echo ""
            echo "Environment:"
            echo "  NOTARY_PROFILE    Notarytool keychain profile (default: SECRETARIAT)"
            echo "  DEV_ID            Developer ID for signing (default: Developer ID Application: Ulrich Diedrichsen)"
            echo "  TEAM_ID           Apple Team ID for notarization"
            echo ""
            echo "Output:"
            echo "  build/release/secd                    Daemon binary"
            echo "  build/release/sec                     CLI binary"
            echo "  build/release/Secretariat.app         Flutter app"
            echo "  build/release/Secretariat.dmg         DMG (if --dmg)"
            echo "  build/release/Secretariat.zip         Zipped app for notarization"
            exit 0
            ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
    esac
done

# ---- Helper Functions ----

log() { echo -e "${BLUE}=== $1 ===${NC}"; }
ok()  { echo -e "${GREEN}  ✓ $1${NC}"; }
warn(){ echo -e "${YELLOW}  ⚠ $1${NC}"; }
err() { echo -e "${RED}  ✗ $1${NC}"; }

get_version() {
    grep '^version' "$PROJECT_ROOT/Cargo.toml" | head -1 | sed 's/version = "\(.*\)"/\1/'
}

run_or_dry() {
    if $DRY_RUN; then
        echo "  [DRY-RUN] $*"
    else
        "$@"
    fi
}

# ---- Phases ----

build_rust() {
    local target=$1
    local label=$2
    log "Building Rust components for $label"

    cd "$PROJECT_ROOT"

    if [[ -n "$target" ]]; then
        run_or_dry cargo build --release --target "$target" -p secd
        cp "$PROJECT_ROOT/target/$target/release/secd" "$BUILD_DIR/secd-$target"
        run_or_dry cargo build --release --target "$target" -p sec
        cp "$PROJECT_ROOT/target/$target/release/sec" "$BUILD_DIR/sec-$target"
    else
        run_or_dry cargo build --release -p secd
        cp "$PROJECT_ROOT/target/release/secd" "$BUILD_DIR/"
        run_or_dry cargo build --release -p sec
        cp "$PROJECT_ROOT/target/release/sec" "$BUILD_DIR/"
    fi

    ok "Rust components built"
}

create_universal() {
    log "Creating universal binaries"

    if [ ! -f "$BUILD_DIR/secd-aarch64-apple-darwin" ] || [ ! -f "$BUILD_DIR/secd-x86_64-apple-darwin" ]; then
        err "Missing architecture-specific builds. Run with --universal first."
        exit 1
    fi

    run_or_dry lipo -create \
        "$BUILD_DIR/secd-aarch64-apple-darwin" \
        "$BUILD_DIR/secd-x86_64-apple-darwin" \
        -output "$BUILD_DIR/secd"

    run_or_dry lipo -create \
        "$BUILD_DIR/sec-aarch64-apple-darwin" \
        "$BUILD_DIR/sec-x86_64-apple-darwin" \
        -output "$BUILD_DIR/sec"

    rm -f "$BUILD_DIR/secd-aarch64-apple-darwin" "$BUILD_DIR/secd-x86_64-apple-darwin"
    rm -f "$BUILD_DIR/sec-aarch64-apple-darwin" "$BUILD_DIR/sec-x86_64-apple-darwin"

    ok "Universal binaries created"
}

build_flutter() {
    log "Building Flutter app"

    cd "$APP_DIR"
    run_or_dry flutter pub get
    run_or_dry flutter build macos --release

    # Use ditto (not cp -r) to preserve framework symlinks (Versions/Current).
    # cp -r flattens them, which makes codesign report "bundle format is ambiguous".
    rm -rf "$BUILD_DIR/Secretariat.app"
    run_or_dry ditto "$APP_DIR/build/macos/Build/Products/Release/Secretariat.app" "$BUILD_DIR/Secretariat.app"
    ok "Flutter app built"
}

sign_binary() {
    local path="$1"
    if [ -f "$path" ]; then
        echo "  Signing $path..."
        run_or_dry codesign --force --options runtime --timestamp --sign "$DEV_ID" "$path"
        ok "Signed $path"
    else
        warn "File not found: $path — skipping"
    fi
}

sign_all() {
    log "Code signing with: $DEV_ID"

    # Sign Rust binaries
    sign_binary "$BUILD_DIR/secd"
    sign_binary "$BUILD_DIR/sec"

    # Sign Flutter app inside-out: nested frameworks first, app bundle last.
    # --deep is unreliable for Developer ID + hardened runtime and strips the
    # app's entitlements; sign each component explicitly instead.
    if [ -d "$BUILD_DIR/Secretariat.app" ]; then
        local APP="$BUILD_DIR/Secretariat.app"
        local ENTITLEMENTS="$APP_DIR/macos/Runner/Release.entitlements"

        echo "  Signing nested frameworks..."
        local fw
        for fw in "$APP/Contents/Frameworks/"*.framework; do
            [ -e "$fw" ] || continue
            run_or_dry codesign --force --options runtime --timestamp --sign "$DEV_ID" "$fw"
        done
        ok "Nested frameworks signed"

        echo "  Signing Secretariat.app (with entitlements)..."
        run_or_dry codesign --force --options runtime --timestamp \
            --entitlements "$ENTITLEMENTS" \
            --sign "$DEV_ID" "$APP"
        ok "Signed Secretariat.app"

        # Verify signing
        echo "  Verifying signature..."
        run_or_dry codesign --verify --deep --strict --verbose=2 "$APP"
        codesign -dvv "$APP" 2>&1 | grep -E "Authority|TeamIdentifier|Runtime" || true
        ok "Signature verified"
    else
        warn "Secretariat.app not found in build directory"
    fi
}

notarize() {
    log "Submitting for Apple notarization"

    if [ ! -d "$BUILD_DIR/Secretariat.app" ]; then
        err "Secretariat.app not found. Build first."
        exit 1
    fi

    # Zip the app for notarization
    echo "  Creating zip archive..."
    run_or_dry ditto -c -k --keepParent \
        "$BUILD_DIR/Secretariat.app" \
        "$BUILD_DIR/Secretariat.zip"
    ok "Created Secretariat.zip"

    # Submit for notarization
    echo "  Submitting to Apple notary service..."
    SUBMIT_OUTPUT=$(run_or_dry xcrun notarytool submit "$BUILD_DIR/Secretariat.zip" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait 2>&1) || true

    if echo "$SUBMIT_OUTPUT" | grep -q "status: Accepted"; then
        ok "Notarization accepted"

        # Staple the ticket
        echo "  Stapling notarization ticket..."
        run_or_dry xcrun stapler staple "$BUILD_DIR/Secretariat.app"
        ok "Ticket stapled"
    elif echo "$SUBMIT_OUTPUT" | grep -q "status: Invalid"; then
        err "Notarization rejected. Check the log for details."
        echo "$SUBMIT_OUTPUT"
        exit 1
    else
        warn "Notarization status unknown. Output:"
        echo "$SUBMIT_OUTPUT"
    fi
}

create_dmg() {
    log "Creating DMG"

    if [ ! -d "$BUILD_DIR/Secretariat.app" ]; then
        err "Secretariat.app not found. Build the Flutter app first."
        exit 1
    fi

    local VERSION
    VERSION=$(get_version)

    rm -f "$BUILD_DIR/Secretariat.dmg"
    local DMG_OK=false

    if command -v create-dmg &>/dev/null; then
        echo "  Using create-dmg..."
        local DMG_ARGS=(
            --volname "Secretariat v$VERSION"
            --window-pos 200 120
            --window-size 600 400
            --icon-size 100
            --icon "Secretariat.app" 150 190
            --hide-extension "Secretariat.app"
            --app-drop-link 450 190
        )
        # Optional volume icon — only added if a real .icns exists
        # (the asset catalog ships PNGs only, so this is normally skipped)
        local ICNS="$APP_DIR/macos/Runner/Assets.xcassets/AppIcon.appiconset/AppIcon.icns"
        [ -f "$ICNS" ] && DMG_ARGS+=(--volicon "$ICNS")

        run_or_dry create-dmg "${DMG_ARGS[@]}" \
            "$BUILD_DIR/Secretariat.dmg" \
            "$BUILD_DIR/Secretariat.app" || true

        [ -f "$BUILD_DIR/Secretariat.dmg" ] && DMG_OK=true || warn "create-dmg produced no DMG — falling back to hdiutil"
    fi

    if ! $DMG_OK; then
        echo "  Using hdiutil..."
        local DMG_TMP="$BUILD_DIR/.dmg-tmp"
        rm -rf "$DMG_TMP"
        mkdir -p "$DMG_TMP"
        # ditto preserves framework symlinks (cp -r would corrupt the signed app)
        ditto "$BUILD_DIR/Secretariat.app" "$DMG_TMP/Secretariat.app"
        ln -s /Applications "$DMG_TMP/Applications"

        run_or_dry hdiutil create -volname "Secretariat v$VERSION" \
            -srcfolder "$DMG_TMP" \
            -ov -format UDZO \
            "$BUILD_DIR/Secretariat.dmg"

        rm -rf "$DMG_TMP"
    fi

    if [ ! -f "$BUILD_DIR/Secretariat.dmg" ]; then
        err "DMG creation failed"
        exit 1
    fi

    # Sign + notarize the DMG too if signing was requested.
    # Signing the DMG (not just the app inside) is Apple best practice and
    # makes `spctl -a -t open` assess it as accepted.
    if $DO_SIGN && [ -f "$BUILD_DIR/Secretariat.dmg" ]; then
        echo "  Signing DMG..."
        run_or_dry codesign --force --timestamp \
            --sign "$DEV_ID" "$BUILD_DIR/Secretariat.dmg"
    fi
    if $DO_NOTARIZE && [ -f "$BUILD_DIR/Secretariat.dmg" ]; then
        echo "  Notarizing DMG..."
        run_or_dry xcrun notarytool submit "$BUILD_DIR/Secretariat.dmg" \
            --keychain-profile "$NOTARY_PROFILE" \
            --wait 2>&1 || true
        run_or_dry xcrun stapler staple "$BUILD_DIR/Secretariat.dmg" 2>/dev/null || true
    fi

    ok "DMG created: $BUILD_DIR/Secretariat.dmg"
}

create_github_release() {
    log "Creating GitHub Release"

    local VERSION
    VERSION=$(get_version)
    local TAG="v$VERSION"

    # Check if tag already exists
    if git rev-parse "$TAG" &>/dev/null; then
        warn "Tag $TAG already exists. Delete it first: git tag -d $TAG && git push origin :refs/tags/$TAG"
        return
    fi

    # Generate release notes from git log
    local PREV_TAG
    PREV_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    local RELEASE_NOTES="$BUILD_DIR/release-notes.md"

    {
        echo "## Secretariat v$VERSION"
        echo ""
        if [ -n "$PREV_TAG" ]; then
            echo "### Changes since $PREV_TAG"
            echo ""
            git log "$PREV_TAG..HEAD" --oneline --no-decorate | sed 's/^/- /'
        else
            echo "### Initial release"
            echo ""
            git log --oneline --no-decorate | head -20 | sed 's/^/- /'
        fi
    } > "$RELEASE_NOTES"

    # Create tag and push
    run_or_dry git tag -a "$TAG" -m "Secretariat v$VERSION"
    run_or_dry git push origin "$TAG"

    # Create GitHub Release
    if command -v gh &>/dev/null; then
        local RELEASE_ARGS=()

        if [ -f "$BUILD_DIR/Secretariat.dmg" ]; then
            RELEASE_ARGS+=(--title "Secretariat v$VERSION" --notes-file "$RELEASE_NOTES" "$BUILD_DIR/Secretariat.dmg")
        fi
        if [ -f "$BUILD_DIR/secd" ]; then
            RELEASE_ARGS+=("$BUILD_DIR/secd")
        fi
        if [ -f "$BUILD_DIR/sec" ]; then
            RELEASE_ARGS+=("$BUILD_DIR/sec")
        fi

        run_or_dry gh release create "$TAG" "${RELEASE_ARGS[@]}"
        ok "GitHub Release created: $TAG"
    else
        warn "gh CLI not found. Tag $TAG pushed — create release manually at:"
        echo "  https://github.com/moinsen-dev/secretariat/releases/new?tag=$TAG"
    fi
}

# ---- Main ----

log "Secretariat Release Build"
echo "  Version: $(get_version)"
echo "  Output:  $BUILD_DIR"
echo ""

# Create build directory
mkdir -p "$BUILD_DIR"

# Phase 1: Build
if $BUILD_UNIVERSAL; then
    log "Building universal binaries for Intel + Apple Silicon"

    for target in aarch64-apple-darwin x86_64-apple-darwin; do
        if ! rustup target list --installed | grep -q "$target"; then
            echo -e "${YELLOW}Installing $target target...${NC}"
            run_or_dry rustup target add "$target"
        fi
    done

    build_rust "aarch64-apple-darwin" "Apple Silicon (arm64)"
    build_rust "x86_64-apple-darwin" "Intel (x86_64)"
    create_universal
else
    build_rust "" "current architecture"
fi

if ! $SKIP_FLUTTER; then
    build_flutter
fi

# Phase 2: Sign
if $DO_SIGN; then
    sign_all
fi

# Phase 3: Notarize
if $DO_NOTARIZE; then
    notarize
fi

# Phase 4: DMG
if $DO_DMG; then
    create_dmg
fi

# Phase 5: GitHub Release
if $DO_GITHUB_RELEASE; then
    create_github_release
fi

# Show results
echo ""
log "Build Complete"
echo ""
echo "Output files in $BUILD_DIR:"
ls -lh "$BUILD_DIR" 2>/dev/null | grep -v '\.dmg-tmp' || echo "  (empty)"

if [ -f "$BUILD_DIR/secd" ]; then
    echo ""
    echo "Binary info:"
    file "$BUILD_DIR/secd"
    file "$BUILD_DIR/sec" 2>/dev/null || true
    if $DO_SIGN; then
        echo ""
        echo "Signature info:"
        codesign -dvv "$BUILD_DIR/secd" 2>&1 | grep -E "Authority|TeamIdentifier" || true
        codesign -dvv "$BUILD_DIR/sec" 2>&1 | grep -E "Authority|TeamIdentifier" || true
    fi
fi

VERSION=$(get_version)
echo ""
echo -e "${GREEN}Secretariat v${VERSION} ready!${NC}"
if $DO_SIGN && $DO_NOTARIZE; then
    echo -e "${GREEN}✓ Signed and notarized for distribution${NC}"
fi
echo ""
echo "Next steps on main MacBook Pro:"
echo "  git pull"
echo "  ./scripts/build-release.sh --release"
if $DO_GITHUB_RELEASE; then
    echo "  ./scripts/build-release.sh --github-release"
fi
