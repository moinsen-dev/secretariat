#!/bin/bash
# Signed + notarized release build: dist/Secretariat-<version>.zip, stapled, ready to sell/download.
# Credentials come from Secretariat itself (profile "werkzeuge": ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY_PATH):
#   ~/bin/secretariat run werkzeuge -- script/release.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
: "${ASC_KEY_ID:?run through: secretariat run werkzeuge -- script/release.sh}" "${ASC_ISSUER_ID:?}" "${ASC_PRIVATE_KEY_PATH:?}"
SECRETARIAT_TIMESTAMP=1 ./script/build.sh
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' dist/Secretariat.app/Contents/Info.plist)
zip="dist/Secretariat-$version.zip"
/usr/bin/ditto -c -k --keepParent dist/Secretariat.app "$zip"
xcrun notarytool submit "$zip" --key "$ASC_PRIVATE_KEY_PATH" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID" --wait
xcrun stapler staple dist/Secretariat.app
/usr/bin/ditto -c -k --keepParent dist/Secretariat.app "$zip"   # re-zip with the stapled ticket
spctl --assess --type execute --verbose dist/Secretariat.app
echo "Release: $ROOT/$zip"
