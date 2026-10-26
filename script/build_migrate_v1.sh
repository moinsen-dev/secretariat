#!/bin/bash
# Builds .artifacts/MigrateV1.app (one-time 0.x → 1.0 move, see migrate_v1.swift) with Secretariat's identifier and entitlements.

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
app="$ROOT/.artifacts/MigrateV1.app"
rm -rf "$app"; mkdir -p "$app/Contents/MacOS"
swiftc -parse-as-library -O -module-name MigrateV1 "$ROOT/script/migrate_v1.swift" "$ROOT"/Sources/SecretariatCore/*.swift -o "$app/Contents/MacOS/migrate-v1"
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>dev.moinsen.secretariat.local</string>
<key>CFBundleExecutable</key><string>migrate-v1</string>
<key>CFBundleName</key><string>MigrateV1</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
cp "$ROOT/Resources/Secretariat.provisionprofile" "$app/Contents/embedded.provisionprofile"
identity="$(security find-identity -v -p codesigning | python3 -c 'import re,sys; m=re.findall(r"\"(Developer ID Application:[^\"]+)\"",sys.stdin.read()); print(m[0])')"
codesign --force --sign "$identity" --options runtime --timestamp=none --entitlements "$ROOT/Resources/Secretariat.entitlements" "$app"
codesign --verify --strict "$app"
echo "$app"
