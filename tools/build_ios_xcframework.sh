#!/bin/bash
# Build secretariat-core-ffi for iOS as a DYNAMIC framework and package
# SecretariatCore.xcframework (vendored by app/ios/secretariat_core.podspec).
#
# Why dynamic, not a static .a: a static lib's force-loaded symbols get
# dead-stripped out of the Flutter Runner binary, so dart:ffi can't find them.
# A dynamic framework exports its symbols and is embedded + signed by
# CocoaPods, so DynamicLibrary.process() resolves them at runtime. (This is
# what cargokit/flutter_rust_bridge do for iOS.)
#
# Re-run after changing core/ or core-ffi/, then `pod install` in app/ios.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FW="SecretariatCore"
OUT="${ROOT}/app/ios/Frameworks/${FW}.xcframework"
WORK="${ROOT}/target/ios-frameworks"

echo "Installing iOS Rust targets…"
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios >/dev/null

echo "Building cdylib (release) for device + both simulator archs…"
for t in aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios; do
  cargo build --release -p secretariat-core-ffi --target "$t" --manifest-path "${ROOT}/Cargo.toml"
done

make_framework() { # $1=dylib  $2=destdir  $3=platform(iPhoneOS|iPhoneSimulator)
  local dylib="$1" dest="$2/${FW}.framework" platform="$3"
  rm -rf "$dest"; mkdir -p "$dest/Headers"
  cp "$dylib" "$dest/${FW}"
  cp "${ROOT}/core-ffi/include/secretariat_core_ffi.h" "$dest/Headers/"
  cat > "$dest/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>${FW}</string>
<key>CFBundleIdentifier</key><string>dev.moinsen.SecretariatCore</string>
<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
<key>CFBundleName</key><string>${FW}</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>CFBundleShortVersionString</key><string>0.4.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>MinimumOSVersion</key><string>13.0</string>
<key>CFBundleSupportedPlatforms</key><array><string>${platform}</string></array>
</dict></plist>
PLIST
}

rm -rf "$WORK"; mkdir -p "$WORK/sim-bin"
make_framework "${ROOT}/target/aarch64-apple-ios/release/libsecretariat_core_ffi.dylib" "$WORK/device" iPhoneOS
lipo -create \
  "${ROOT}/target/aarch64-apple-ios-sim/release/libsecretariat_core_ffi.dylib" \
  "${ROOT}/target/x86_64-apple-ios/release/libsecretariat_core_ffi.dylib" \
  -output "$WORK/sim-bin/${FW}.dylib"
make_framework "$WORK/sim-bin/${FW}.dylib" "$WORK/sim" iPhoneSimulator

echo "Creating xcframework at ${OUT}…"
rm -rf "$OUT"; mkdir -p "${ROOT}/app/ios/Frameworks"
xcodebuild -create-xcframework \
  -framework "$WORK/device/${FW}.framework" \
  -framework "$WORK/sim/${FW}.framework" \
  -output "$OUT"

echo "Done. Slices:"
ls "$OUT" | grep -v Info
