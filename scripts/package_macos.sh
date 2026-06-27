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
ENGINE_ENTITLEMENTS="macos/Runner/Engine.entitlements"

# Bundle the cinematic render engine (Node + remotion-composer node_modules +
# Chromium) into the .app so a plain install renders cinematic by default
# instead of falling back to ffmpeg cards. Adds ~600 MB. Set BUNDLE_ENGINE=0 to
# build a lean app while iterating. NODE_BIN overrides the Node binary to embed;
# otherwise the official, relocatable build is fetched (Homebrew's node links to
# Homebrew dylibs and is not relocatable).
BUNDLE_ENGINE="${BUNDLE_ENGINE:-1}"
NODE_VERSION="${NODE_VERSION:-v20.18.1}"

# Apple account (defaults from the existing developer account; override via env).
APPLE_TEAM_ID="${APPLE_TEAM_ID:-G9VG22HGJG}"
APPLE_ID="${APPLE_ID:-tslacoinv@gmail.com}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
APPLE_APP_PASSWORD="${APPLE_APP_PASSWORD:-}"
# App Store Connect API key (preferred for notarization — no app-specific
# password needed). Auto-detected from the standard private_keys location.
ASC_KEY_ID="${ASC_KEY_ID:-R7C3P5T8VU}"
ASC_ISSUER_ID="${ASC_ISSUER_ID:-3a03ed96-7b88-472c-854b-861040776a53}"
ASC_KEY_PATH="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8}"

# Auto-detect a Developer ID Application signing identity.
IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
  | grep "Developer ID Application" | head -1 | sed -E 's/.*"(.*)".*/\1/' || true)"

echo "==> Building release (${VERSION})…"
flutter build macos --release

# Copy the cinematic engine into the app's Resources, where the app's
# _findComposer()/_bundledNode() look for it at runtime.
bundle_engine() {
  local res="$APP/Contents/Resources"
  local dst="$res/remotion-composer"
  echo "==> Bundling cinematic engine (Node + Remotion + Chromium)…"
  rm -rf "$dst"; mkdir -p "$dst"
  # Preserve symlinks (e.g. node_modules/.bin/remotion) with -a.
  rsync -a --exclude '.git' --exclude 'out' --exclude '.DS_Store' \
    remotion-composer/src remotion-composer/public \
    remotion-composer/package.json remotion-composer/tsconfig.json \
    remotion-composer/node_modules "$dst/"

  # Embed an official, relocatable Node (npm/npx not needed — the app runs the
  # local Remotion CLI directly with this binary).
  local nodearch="arm64"; [[ "$(uname -m)" == "x86_64" ]] && nodearch="x64"
  mkdir -p "$res/node/bin"
  if [[ -n "${NODE_BIN:-}" && -f "${NODE_BIN}" ]]; then
    cp "$NODE_BIN" "$res/node/bin/node"
  else
    local tb="node-${NODE_VERSION}-darwin-${nodearch}.tar.gz"
    local cache="$HOME/.cache/openmontage/${tb}"
    mkdir -p "$(dirname "$cache")"
    [[ -f "$cache" ]] || curl -fsSL "https://nodejs.org/dist/${NODE_VERSION}/${tb}" -o "$cache"
    local tmp; tmp="$(mktemp -d)"
    tar -xzf "$cache" -C "$tmp"
    cp "$tmp/node-${NODE_VERSION}-darwin-${nodearch}/bin/node" "$res/node/bin/node"
    rm -rf "$tmp"
  fi
  chmod +x "$res/node/bin/node"
  echo "==> Engine bundled ($(du -sh "$dst" | cut -f1), node $("$res/node/bin/node" -v 2>/dev/null || echo '?'))"
}

# Sign every Mach-O under Resources (node, chrome-headless-shell + its dylibs,
# the Remotion compositor + bundled ffmpeg, *.node) with the hardened runtime and
# the engine entitlements. Nested code must be signed before the enclosing app.
sign_engine() {
  echo "==> Code-signing engine binaries…"
  local n=0
  while IFS= read -r -d '' f; do
    if file "$f" | grep -q "Mach-O"; then
      codesign --force --options runtime --timestamp \
        --entitlements "$ENGINE_ENTITLEMENTS" --sign "$IDENTITY" "$f" >/dev/null
      n=$((n+1))
    fi
  done < <(find "$APP/Contents/Resources" -type f -print0)
  echo "==> Signed ${n} engine binaries"
}

if [[ "$BUNDLE_ENGINE" == "1" ]]; then bundle_engine; fi

if [[ -n "$IDENTITY" ]]; then
  [[ "$BUNDLE_ENGINE" == "1" ]] && sign_engine
  echo "==> Code-signing app: ${IDENTITY}"
  # Sign the app outermost-last (no --deep, which doesn't apply per-file
  # entitlements and is deprecated).
  codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" --sign "$IDENTITY" "$APP"
  codesign --verify --verbose=2 "$APP"
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

  # Pick a notarization credential (App Store Connect API key preferred).
  NOTARY_ARGS=()
  if [[ -f "$ASC_KEY_PATH" ]]; then
    NOTARY_ARGS=(--key "$ASC_KEY_PATH" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID")
  elif [[ -n "$NOTARY_PROFILE" ]]; then
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
