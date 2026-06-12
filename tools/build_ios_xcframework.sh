#!/bin/bash
# Build the secretariat-core-ffi static libs for iOS and package them as an
# xcframework the Flutter iOS Runner vendors (app/ios/secretariat_core.podspec).
#
# Run after changing core/ or core-ffi/. Re-run `pod install` in app/ios after.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/app/ios/Frameworks/SecretariatCore.xcframework"

echo "Installing iOS Rust targets (no-op if present)…"
rustup target add aarch64-apple-ios aarch64-apple-ios-sim >/dev/null

echo "Building core-ffi (release) for device + simulator…"
cargo build --release -p secretariat-core-ffi --target aarch64-apple-ios --manifest-path "$ROOT/Cargo.toml"
cargo build --release -p secretariat-core-ffi --target aarch64-apple-ios-sim --manifest-path "$ROOT/Cargo.toml"

echo "Creating xcframework at $OUT…"
rm -rf "$OUT"
mkdir -p "$ROOT/app/ios/Frameworks"
xcodebuild -create-xcframework \
  -library "$ROOT/target/aarch64-apple-ios/release/libsecretariat_core_ffi.a" \
  -headers "$ROOT/core-ffi/include" \
  -library "$ROOT/target/aarch64-apple-ios-sim/release/libsecretariat_core_ffi.a" \
  -headers "$ROOT/core-ffi/include" \
  -output "$OUT"

echo "✓ Done. Slices:"
/usr/libexec/PlistBuddy -c "Print :AvailableLibraries" "$OUT/Info.plist" 2>/dev/null \
  | grep LibraryIdentifier || true
