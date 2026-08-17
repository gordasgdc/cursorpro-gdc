#!/usr/bin/env bash
# Builds CursorPro.app fresh, then wraps it in a signed-content .pkg
# installer with a license (Terms & Conditions) pane the user must
# accept to continue — via productbuild's native license-pane support.
#
# NOTE: this produces an UNSIGNED installer package (we don't have a
# paid Apple Developer ID Installer certificate, only a free local code-
# signing identity for the app itself). macOS Gatekeeper will show an
# "unidentified developer" warning on first open — right-click the .pkg
# → Open, or allow it in System Settings → Privacy & Security. This is
# normal for indie-distributed tools outside the App Store; mention it
# in the download instructions.
set -euo pipefail
cd "$(dirname "$0")"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist)
PKG_ID="com.gordasgdc.cursorpro.installer"
APP_NAME="CursorPro.app"
DIST_DIR="dist"
PAYLOAD_ROOT="$DIST_DIR/payload"
COMPONENT_PKG="$DIST_DIR/CursorProGDC-component.pkg"
FINAL_PKG="$DIST_DIR/CursorProGDC-$VERSION.pkg"

echo "==> Building app…"
./build_app.sh

rm -rf "$DIST_DIR"
mkdir -p "$PAYLOAD_ROOT/Applications"
cp -R "/Applications/$APP_NAME" "$PAYLOAD_ROOT/Applications/$APP_NAME"

echo "==> Building component package…"
pkgbuild \
    --root "$PAYLOAD_ROOT" \
    --identifier "$PKG_ID" \
    --version "$VERSION" \
    --install-location "/" \
    "$COMPONENT_PKG"

echo "==> Writing distribution definition…"
cat > "$DIST_DIR/Distribution.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="1">
    <title>CursorPro GDC $VERSION</title>
    <license file="License.txt" mime-type="text/plain"/>
    <options customize="never" require-scripts="false" rootVolumeOnly="true"/>
    <domains enable_localSystem="true"/>
    <choices-outline>
        <line choice="default">
            <line choice="$PKG_ID"/>
        </line>
    </choices-outline>
    <choice id="default"/>
    <choice id="$PKG_ID" visible="false">
        <pkg-ref id="$PKG_ID"/>
    </choice>
    <pkg-ref id="$PKG_ID" version="$VERSION" onConclusion="none">CursorProGDC-component.pkg</pkg-ref>
</installer-gui-script>
EOF

cp installer/License.txt "$DIST_DIR/License.txt"

echo "==> Building final installer package…"
productbuild \
    --distribution "$DIST_DIR/Distribution.xml" \
    --package-path "$DIST_DIR" \
    --resources "$DIST_DIR" \
    "$FINAL_PKG"

rm -rf "$PAYLOAD_ROOT" "$COMPONENT_PKG"
echo "==> Done: $FINAL_PKG"
