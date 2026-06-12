#!/bin/bash
# Build secretariat-core-ffi for iOS and package SecretariatCore.xcframework
# (vendored by app/ios/secretariat_core.podspec). Re-run after changing core/
# or core-ffi/, then `pod install` in app/ios.
#
# The simulator slice is a FAT lib (arm64 + x86_64) so it links on both the
# Apple-Silicon and Intel simulator architectures Xcode may build. With both
# archs the slice directory is named `ios-arm64_x86_64-simulator`.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${ROOT}/app/ios/Frameworks/SecretariatCore.xcframework"
SIMFAT="${ROOT}/target/ios-sim-fat"

echo "Installing iOS Rust targets (no-op if present)…"
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios >/dev/null

echo "Building core-ffi (release) for device + both simulator archs…"
cargo build --release -p secretariat-core-ffi --target aarch64-apple-ios --manifest-path "${ROOT}/Cargo.toml"
cargo build --release -p secretariat-core-ffi --target aarch64-apple-ios-sim --manifest-path "${ROOT}/Cargo.toml"
cargo build --release -p secretariat-core-ffi --target x86_64-apple-ios --manifest-path "${ROOT}/Cargo.toml"

echo "Lipo-ing the fat simulator slice…"
mkdir -p "${SIMFAT}"
lipo -create \
  "${ROOT}/target/aarch64-apple-ios-sim/release/libsecretariat_core_ffi.a" \
  "${ROOT}/target/x86_64-apple-ios/release/libsecretariat_core_ffi.a" \
  -output "${SIMFAT}/libsecretariat_core_ffi.a"

echo "Creating xcframework at ${OUT}…"
rm -rf "${OUT}"
mkdir -p "${ROOT}/app/ios/Frameworks"
xcodebuild -create-xcframework \
  -library "${ROOT}/target/aarch64-apple-ios/release/libsecretariat_core_ffi.a" \
  -headers "${ROOT}/core-ffi/include" \
  -library "${SIMFAT}/libsecretariat_core_ffi.a" \
  -headers "${ROOT}/core-ffi/include" \
  -output "${OUT}"

echo "Done. Slices:"
ls "${OUT}" | grep -v Info
