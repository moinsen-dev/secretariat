#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
swift build
mkdir -p Assets dist
if [[ ! -f Assets/AppIcon.icns ]]; then
  icon_tmp="$(mktemp -d)"
  trap 'rm -rf "$icon_tmp"' EXIT
  mkdir "$icon_tmp/AppIcon.iconset"
  swift script/draw_icon.swift "$icon_tmp/icon.png"
  for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$icon_tmp/icon.png" --out "$icon_tmp/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$icon_tmp/icon.png" --out "$icon_tmp/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns "$icon_tmp/AppIcon.iconset" -o Assets/AppIcon.icns
  rm -rf "$icon_tmp"
  trap - EXIT
fi
stage="$ROOT/dist/.Secretariat-stage-$$.app"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/Contents/MacOS" "$stage/Contents/Resources"
cp "$(swift build --show-bin-path)/Secretariat" "$stage/Contents/MacOS/Secretariat"
cp Resources/Info.plist "$stage/Contents/Info.plist"
cp Assets/AppIcon.icns "$stage/Contents/Resources/AppIcon.icns"
identity="${SECRETARIAT_SIGN_IDENTITY:-}"
if [[ -z "$identity" ]]; then
  identity="$(security find-identity -v -p codesigning | python3 -c 'import re,sys; matches=re.findall(r"\"(Developer ID Application:[^\"]+)\"",sys.stdin.read()); print(matches[0] if matches else "-")')"
fi
if [[ "$identity" == "Developer ID Application:"* ]]; then
  # 0.3: synchronizable keys live in the data-protection keychain, which needs the app identifier
  # and keychain access group — restricted entitlements a Developer ID app only gets with an
  # embedded provisioning profile (App ID dev.moinsen.secretariat.local, profile "Secretariat Developer ID").
  cp Resources/Secretariat.provisionprofile "$stage/Contents/embedded.provisionprofile"
  codesign --force --sign "$identity" --options runtime --timestamp=none --entitlements Resources/Secretariat.entitlements "$stage"
else
  # Ad-hoc builds cannot carry restricted entitlements; they keep the local login keychain only.
  codesign --force --sign "$identity" --options runtime --timestamp=none "$stage"
fi
codesign --verify --strict "$stage"
python3 - "$ROOT/dist/Secretariat.app" <<'PY'
import pathlib,plistlib,shutil,sys
p=pathlib.Path(sys.argv[1])
if p.exists():
    with (p/'Contents/Info.plist').open('rb') as f:info=plistlib.load(f)
    if info.get('CFBundleIdentifier')!='dev.moinsen.secretariat.local':raise SystemExit('Existing bundle belongs to another app')
    shutil.rmtree(p)
PY
mv "$stage" "$ROOT/dist/Secretariat.app"
trap - EXIT
echo "App-Paket: $ROOT/dist/Secretariat.app"
