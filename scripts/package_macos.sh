#!/usr/bin/env bash
# Build a distributable macOS .dmg for OpenMontage Studio.
#
# Usage: scripts/package_macos.sh
#
# Produces dist/OpenMontageStudio-<version>.dmg containing the .app plus an
# Applications symlink for drag-to-install.
#
# NOTE: this does NOT code-sign or notarize. For a release users can open
# without Gatekeeper warnings, you need an Apple Developer ID certificate:
#   codesign --deep --force --options runtime --sign "Developer ID Application: <NAME> (<TEAMID>)" <app>
#   xcrun notarytool submit <dmg> --apple-id <id> --team-id <TEAMID> --password <app-specific-pw> --wait
#   xcrun stapler staple <dmg>
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="openmontage_studio"
VOL_NAME="OpenMontage Studio"
VERSION="$(grep -m1 '^version:' pubspec.yaml | sed 's/version:[[:space:]]*//; s/+.*//')"
APP="build/macos/Build/Products/Release/${APP_NAME}.app"
OUT_DIR="dist"
DMG="${OUT_DIR}/OpenMontageStudio-${VERSION}.dmg"

echo "==> Building release (${VERSION})…"
flutter build macos --release

echo "==> Staging…"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "==> Creating ${DMG}…"
mkdir -p "$OUT_DIR"
rm -f "$DMG"
hdiutil create -volname "$VOL_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

echo "==> Done: ${DMG}"
ls -lh "$DMG"
