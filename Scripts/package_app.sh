#!/usr/bin/env bash
# Assemble a menu-bar .app bundle from the SwiftPM build product.
# Usage: ./Scripts/package_app.sh [debug|release]   (default: release)
set -euo pipefail

CONFIG="${1:-release}"
APP_NAME="Aurora"
BUNDLE_ID="com.evgenypopov.aurora"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN_PATH="$ROOT/.build/$CONFIG/AuroraApp"
DIST="$ROOT/dist/$APP_NAME.app"

echo "▸ Building ($CONFIG)…"
swift build -c "$CONFIG"

if [[ ! -f "$BIN_PATH" ]]; then
  echo "✗ Build product not found at $BIN_PATH" >&2
  exit 1
fi

echo "▸ Packaging $APP_NAME.app…"
rm -rf "$DIST"
mkdir -p "$DIST/Contents/MacOS" "$DIST/Contents/Resources"
cp "$BIN_PATH" "$DIST/Contents/MacOS/$APP_NAME"
cp "$ROOT/Scripts/AppIcon.icns" "$DIST/Contents/Resources/AppIcon.icns"
sed "s/__BUNDLE_ID__/$BUNDLE_ID/g" "$ROOT/Scripts/Info.plist.template" > "$DIST/Contents/Info.plist"

# Sign with a real Apple Developer identity so TCC (screen/mic) permissions
# attach to a stable, trusted identity instead of an ad-hoc one. Preference
# order: an explicit override, a "Developer ID Application" cert (for builds
# distributed outside the App Store), then any "Apple Development" cert tied
# to the logged-in Apple ID. Falls back to ad-hoc signing if none is found.
SIGN_IDENTITY="${AURORA_SIGN_IDENTITY:-}"
if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | { grep -m1 "Developer ID Application" || true; } \
    | sed -E 's/^[[:space:]]*[0-9]+\) [0-9A-F]+ "(.*)"$/\1/')"
fi
if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | { grep -m1 "Apple Development" || true; } \
    | sed -E 's/^[[:space:]]*[0-9]+\) [0-9A-F]+ "(.*)"$/\1/')"
fi

if [[ -n "$SIGN_IDENTITY" ]]; then
  # A secure Apple timestamp is required for notarization, but only Developer
  # ID signatures can be notarized — skip the network round-trip otherwise.
  TIMESTAMP_FLAG="--timestamp=none"
  if [[ "$SIGN_IDENTITY" == *"Developer ID Application"* ]]; then
    TIMESTAMP_FLAG="--timestamp"
  fi
  echo "▸ Signing with \"$SIGN_IDENTITY\"…"
  codesign --force --deep --options runtime "$TIMESTAMP_FLAG" \
    --sign "$SIGN_IDENTITY" "$DIST"
else
  echo "  (no Apple Developer identity found — falling back to ad-hoc signing)"
  codesign --force --deep --sign - "$DIST" 2>/dev/null || \
    echo "  (codesign skipped — install full Xcode/codesign for signed builds)"
fi

echo "✓ Built $DIST"

# Optional: notarize + staple (requires a Developer ID Application signature
# and credentials already stored via ./Scripts/notarize.sh --store-credentials).
#   ./Scripts/package_app.sh release notarize
for arg in "${@:2}"; do
  if [[ "$arg" == "notarize" ]]; then
    "$ROOT/Scripts/notarize.sh" "$DIST"
  fi
done

# Optional: install into /Applications for a stable location + TCC identity.
#   ./Scripts/package_app.sh release install
for arg in "${@:2}"; do
  if [[ "$arg" == "install" ]]; then
    APPS="/Applications/$APP_NAME.app"
    echo "▸ Installing to ${APPS}…"
    rm -rf "$APPS"
    cp -R "$DIST" "$APPS"   # exact copy → same code-signature/identity as dist (one TCC entry)
    echo "✓ Installed $APPS"
  fi
done

echo "  Run with: open \"$DIST\""
