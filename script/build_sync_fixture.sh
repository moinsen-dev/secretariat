#!/bin/bash
# Builds .artifacts/SyncFixture.app: same identifier, entitlements and profile as Secretariat,
# so it can see the app's synced keychain items. Only touches test namespaces (see sync_fixture.swift).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
app="$ROOT/.artifacts/SyncFixture.app"
rm -rf "$app"; mkdir -p "$app/Contents/MacOS"
swiftc -parse-as-library -O "$ROOT/script/sync_fixture.swift" -o "$app/Contents/MacOS/sync-fixture"
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>dev.moinsen.secretariat.local</string>
<key>CFBundleExecutable</key><string>sync-fixture</string>
<key>CFBundleName</key><string>SyncFixture</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
cp "$ROOT/Resources/Secretariat.provisionprofile" "$app/Contents/embedded.provisionprofile"
identity="$(security find-identity -v -p codesigning | python3 -c 'import re,sys; m=re.findall(r"\"(Developer ID Application:[^\"]+)\"",sys.stdin.read()); print(m[0])')"
codesign --force --sign "$identity" --options runtime --timestamp=none --entitlements "$ROOT/Resources/Secretariat.entitlements" "$app"
codesign --verify --strict "$app"
echo "$app"
