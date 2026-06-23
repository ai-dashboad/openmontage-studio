#!/usr/bin/env bash
# Build a distributable macOS .dmg for OpenMontage Studio.
#
# Usage: scripts/package_macos.sh
#
# Produces dist/OpenMontageStudio-<version>.dmg (the .app + an Applications
# symlink for drag-to-install).
#
# Code-signing + notarization happen automatically WHEN a "Developer ID
# Application" certificate is in the keychain; otherwise the build is unsigned
# (opens with a Gatekeeper warning). To enable signing you need, one time:
#   1. A "Developer ID Application" cert (Xcode > Settings > Accounts > Manage
#      Certificates > + > Developer ID Application), and
#   2. A notarization credential — either a stored notarytool profile:
#        xcrun notarytool store-credentials omstudio --apple-id <id> \
#          --team-id G9VG22HGJG --password <app-specific-password>
#      then run with NOTARY_PROFILE=omstudio, OR set APPLE_APP_PASSWORD to an
#      app-specific password (https://appleid.apple.com > Sign-In and Security).
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="openmontage_studio"
VOL_NAME="OpenMontage Studio"
VERSION="$(grep -m1 '^version:' pubspec.yaml | sed 's/version:[[:space:]]*//; s/+.*//')"
APP="build/macos/Build/Products/Release/${APP_NAME}.app"
OUT_DIR="dist"
DMG="${OUT_DIR}/OpenMontageStudio-${VERSION}.dmg"
ENTITLEMENTS="macos/Runner/Release.entitlements"

# Apple account (defaults from the existing developer account; override via env).
APPLE_TEAM_ID="${APPLE_TEAM_ID:-G9VG22HGJG}"
APPLE_ID="${APPLE_ID:-tslacoinv@gmail.com}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
APPLE_APP_PASSWORD="${APPLE_APP_PASSWORD:-}"

# Auto-detect a Developer ID Application signing identity.
IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
  | grep "Developer ID Application" | head -1 | sed -E 's/.*"(.*)".*/\1/' || true)"

echo "==> Building release (${VERSION})…"
flutter build macos --release

if [[ -n "$IDENTITY" ]]; then
  echo "==> Code-signing with: ${IDENTITY}"
  codesign --deep --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" --sign "$IDENTITY" "$APP"
  codesign --verify --strict --verbose=2 "$APP"
else
  echo "==> No 'Developer ID Application' certificate found — building UNSIGNED."
  echo "    (Create one in Xcode > Settings > Accounts > Manage Certificates.)"
fi

echo "==> Staging…"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "==> Creating ${DMG}…"
mkdir -p "$OUT_DIR"
rm -f "$DMG"
hdiutil create -volname "$VOL_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

if [[ -n "$IDENTITY" ]]; then
  codesign --force --timestamp --sign "$IDENTITY" "$DMG"

  # Pick a notarization credential.
  NOTARY_ARGS=()
  if [[ -n "$NOTARY_PROFILE" ]]; then
    NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")
  elif [[ -n "$APPLE_APP_PASSWORD" ]]; then
    NOTARY_ARGS=(--apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_PASSWORD")
  fi

  if [[ ${#NOTARY_ARGS[@]} -gt 0 ]]; then
    echo "==> Notarizing (this can take a few minutes)…"
    xcrun notarytool submit "$DMG" "${NOTARY_ARGS[@]}" --wait
    echo "==> Stapling…"
    xcrun stapler staple "$DMG"
    xcrun stapler validate "$DMG"
  else
    echo "==> Signed but NOT notarized (no notarization credential)."
    echo "    Set NOTARY_PROFILE=<profile> or APPLE_APP_PASSWORD=<app-specific-pw>."
  fi
fi

echo "==> Done: ${DMG}"
ls -lh "$DMG"
[[ -n "$IDENTITY" ]] && spctl -a -t open --context context:primary-signature -v "$DMG" 2>&1 | head -2 || true
