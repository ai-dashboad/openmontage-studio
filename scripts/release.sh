#!/usr/bin/env bash
# One-command release: build + sign + notarize the .dmg, publish it to the
# Cloudflare Pages site, and bump the version manifest so the in-app updater
# detects it. Fully automated — no browser.
#
# Usage: scripts/release.sh "Release notes shown in the in-app banner"
#
# Reads the version from pubspec.yaml. Requires:
#   - a Developer ID cert + ASC API key (see scripts/package_macos.sh), and
#   - CLOUDFLARE_API_TOKEN in cloudflare/.env (Pages deploy permission).
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(grep -m1 '^version:' pubspec.yaml | sed 's/version:[[:space:]]*//; s/+.*//')"
BUILD="$(grep -m1 '^version:' pubspec.yaml | sed 's/.*+//')"
NOTES="${1:-OpenMontage Studio ${VERSION}.}"
PROJECT="openmontage-studio"
DMG="dist/OpenMontageStudio-${VERSION}.dmg"
SITE_DMG="site/public/download/OpenMontageStudio.dmg"
FLUTTER_DART="$(dirname "$(command -v flutter)")/cache/dart-sdk/bin/dart"

echo "==> Releasing v${VERSION}"

# 1. Build + sign + notarize.
scripts/package_macos.sh

# 2. Stage the signed .dmg into the site.
mkdir -p "$(dirname "$SITE_DMG")"
cp "$DMG" "$SITE_DMG"

# 3. Update the version manifest.
cat > site/public/version.json <<JSON
{
  "version": "${VERSION}",
  "url": "https://get.opencli.ai/download/OpenMontageStudio.dmg",
  "notes": "${NOTES}"
}
JSON
echo "==> version.json -> ${VERSION}"

# 3b. Sparkle: sign the .dmg (EdDSA, private key from the keychain) and
#     regenerate the appcast feed so Sparkle-enabled apps can self-update.
SIGN="$("$FLUTTER_DART" run auto_updater:sign_update "$DMG" 2>/dev/null | tail -1)"
PUBDATE="$(date -u '+%a, %d %b %Y %H:%M:%S +0000')"
cat > site/public/appcast.xml <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>OpenMontage Studio</title>
    <link>https://get.opencli.ai/appcast.xml</link>
    <item>
      <title>${VERSION}</title>
      <sparkle:version>${BUILD}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>10.14.0</sparkle:minimumSystemVersion>
      <description><![CDATA[${NOTES}]]></description>
      <pubDate>${PUBDATE}</pubDate>
      <enclosure url="https://get.opencli.ai/download/OpenMontageStudio.dmg" type="application/x-apple-diskimage" ${SIGN} />
    </item>
  </channel>
</rss>
XML
echo "==> appcast.xml -> ${VERSION} (build ${BUILD})"

# 4. Deploy to Cloudflare Pages.
set -a; source cloudflare/.env; set +a
echo "==> Deploying site to Cloudflare Pages (${PROJECT})…"
npx --yes wrangler@latest pages deploy site/public \
  --project-name "$PROJECT" --commit-dirty=true

echo "==> Released v${VERSION}: https://get.opencli.ai/download/OpenMontageStudio.dmg"
