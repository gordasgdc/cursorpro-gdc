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

# A version-agnostic copy too — the landing page always links to this
# stable filename (releases/latest/download/CursorProGDC.pkg), so it
# doesn't need editing every release. Upload BOTH files to each GitHub
# release: the versioned one (so old links keep working) and this one
# (so the landing page's link always resolves to whatever is newest).
cp "$FINAL_PKG" "$DIST_DIR/CursorProGDC.pkg"

echo "==> Copying first-run launcher (removes Gatekeeper quarantine automatically)…"
cp "Instalare_CursorPro.command" "$DIST_DIR/Instalare_CursorPro.command"
chmod +x "$DIST_DIR/Instalare_CursorPro.command"

# Bundle .pkg + launcher + instructions into one zip. The website's
# download button links to THIS zip, not the bare .pkg — a direct .pkg
# link means the user never sees Instalare_CursorPro.command, defeating
# the whole point of the launcher.
echo "==> Building CursorProGDC-Mac.zip (pkg + launcher + instructions)…"
ZIP_STAGE="$DIST_DIR/zip_stage"
rm -rf "$ZIP_STAGE"
mkdir -p "$ZIP_STAGE"
cp "$DIST_DIR/CursorProGDC.pkg" "$ZIP_STAGE/"
cp "$DIST_DIR/Instalare_CursorPro.command" "$ZIP_STAGE/"
chmod +x "$ZIP_STAGE/Instalare_CursorPro.command"
cp "installer/Instructiuni-CursorProGDC.pdf" "$ZIP_STAGE/" 2>/dev/null || true
( cd "$ZIP_STAGE" && zip -q -r "../CursorProGDC-Mac.zip" . )
rm -rf "$ZIP_STAGE"

echo "==> Done: $FINAL_PKG"
echo "==> Also: $DIST_DIR/CursorProGDC.pkg, $DIST_DIR/Instalare_CursorPro.command, $DIST_DIR/Instructiuni-CursorProGDC.pdf, $DIST_DIR/CursorProGDC-Mac.zip"
echo "    Upload CursorProGDC-Mac.zip to the GitHub release (that's what the website links to)."
