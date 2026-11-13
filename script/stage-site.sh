#!/bin/bash
# Site folder for a release: dist/site-<version> = site/ + every release zip + latest zip/pkg + appcast.xml.
# Deploy (Uli): secretariat run werkzeuge -- npx --yes wrangler@4 pages deploy dist/site-<version> --project-name secretariat --branch main
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' dist/Secretariat.app/Contents/Info.plist)
[ -f "dist/Secretariat-$version.zip" ] || { echo "dist/Secretariat-$version.zip missing: run script/release.sh first." >&2; exit 1; }
stage="dist/site-$version"
rm -rf "$stage"; mkdir -p "$stage"
cp -R site/. "$stage/"
cp dist/Secretariat-*.zip "$stage/"
cp "dist/Secretariat-$version.zip" "$stage/Secretariat-latest.zip"
cp dist/appcast.xml "$stage/"
if [ -f "dist/Secretariat-$version.pkg" ]; then
  cp "dist/Secretariat-$version.pkg" "$stage/"
  cp "dist/Secretariat-$version.pkg" "$stage/Secretariat-latest.pkg"
else
  echo "No dist/Secretariat-$version.pkg: the admin guide's package link would break." >&2; exit 1
fi
echo "Site: $ROOT/$stage"
