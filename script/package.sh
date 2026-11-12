#!/bin/bash
# Installer package for MDM (Jamf, Kandji, Mosyle, Intune …): dist/Secretariat-<version>.pkg, signed with
# "Developer ID Installer", notarized and stapled. Builds on the notarized app from script/release.sh.
#   ~/bin/secretariat run werkzeuge -- script/package.sh
# Needs a "Developer ID Installer" certificate in the login keychain (Apple Developer account → Certificates).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
: "${ASC_KEY_ID:?run through: secretariat run werkzeuge -- script/package.sh}" "${ASC_ISSUER_ID:?}" "${ASC_PRIVATE_KEY_PATH:?}"
identity=$(security find-identity -v | awk -F'"' '/Developer ID Installer/ {print $2; exit}')
if [ -z "$identity" ]; then
  echo "No 'Developer ID Installer' certificate in the keychain. Create one at developer.apple.com → Certificates," >&2
  echo "install it, then run this again. The app itself (script/release.sh) doesn't need it." >&2
  exit 2
fi
app="dist/Secretariat.app"
xcrun stapler validate "$app" >/dev/null || { echo "Run script/release.sh first: $app must be notarized." >&2; exit 1; }
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
stage="$(mktemp -d)"; trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/root/Applications"
/usr/bin/ditto "$app" "$stage/root/Applications/Secretariat.app"
pkgbuild --root "$stage/root" --identifier dev.moinsen.secretariat.pkg --version "$version" \
  --install-location / "$stage/Secretariat-unsigned.pkg"
pkg="dist/Secretariat-$version.pkg"
productsign --sign "$identity" "$stage/Secretariat-unsigned.pkg" "$pkg"
xcrun notarytool submit "$pkg" --key "$ASC_PRIVATE_KEY_PATH" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID" --wait
xcrun stapler staple "$pkg"
pkgutil --check-signature "$pkg"
spctl --assess --type install --verbose "$pkg"
echo "Package: $ROOT/$pkg"
