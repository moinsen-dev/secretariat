#!/bin/bash
# Signed + notarized release build: dist/Secretariat-<version>.zip, stapled, ready to sell/download.
# Credentials come from Secretariat itself (profile "werkzeuge": ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY_PATH,
# SPARKLE_PRIVATE_KEY for the update feed):
#   ~/bin/secretariat run werkzeuge -- script/release.sh
# Also writes dist/appcast.xml (Sparkle feed); the site deploy publishes it with the versioned zip.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
: "${ASC_KEY_ID:?run through: secretariat run werkzeuge -- script/release.sh}" "${ASC_ISSUER_ID:?}" "${ASC_PRIVATE_KEY_PATH:?}"
: "${SPARKLE_PRIVATE_KEY:?SPARKLE_PRIVATE_KEY missing in the werkzeuge profile (moinsen/secretariat-sparkle/private_key)}"
SECRETARIAT_TIMESTAMP=1 ./script/build.sh
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' dist/Secretariat.app/Contents/Info.plist)
zip="dist/Secretariat-$version.zip"
/usr/bin/ditto -c -k --keepParent dist/Secretariat.app "$zip"
xcrun notarytool submit "$zip" --key "$ASC_PRIVATE_KEY_PATH" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID" --wait
xcrun stapler staple dist/Secretariat.app
/usr/bin/ditto -c -k --keepParent dist/Secretariat.app "$zip"   # re-zip with the stapled ticket
spctl --assess --type execute --verbose dist/Secretariat.app

# Sparkle feed: one item for the newest release, signed with the EdDSA key (public half in Info.plist).
build=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' dist/Secretariat.app/Contents/Info.plist)
signature=$(printf '%s' "$SPARKLE_PRIVATE_KEY" | .build/artifacts/sparkle/Sparkle/bin/sign_update --ed-key-file - -p "$zip")
python3 - "$version" "$build" "$signature" "$(stat -f %z "$zip")" > dist/appcast.xml <<'PY'
import sys
from email.utils import formatdate
version, build, signature, length = sys.argv[1:5]
url = f"https://secretariat.moinsen.dev/Secretariat-{version}.zip"
print(f"""<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Secretariat</title>
    <item>
      <title>Secretariat {version}</title>
      <pubDate>{formatdate(usegmt=True)}</pubDate>
      <sparkle:version>{build}</sparkle:version>
      <sparkle:shortVersionString>{version}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <enclosure url="{url}" length="{length}" type="application/octet-stream" sparkle:edSignature="{signature}"/>
    </item>
  </channel>
</rss>""")
PY
echo "Feed: $ROOT/dist/appcast.xml"
echo "Release: $ROOT/$zip"
