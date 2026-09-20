#!/usr/bin/env bash
# Builds CursorPro.app fresh, then wraps it in a signed-content .pkg
# installer with a license (Terms & Conditions) pane the user must
# accept to continue — via productbuild's native license-pane support.
#
# NOTE: produces a SIGNED + NOTARIZED .pkg automatically once the Apple
# Developer ID Installer certificate is configured (see
# codesigning/README.md, one-time setup). Until then, falls back to an
# UNSIGNED package — macOS Gatekeeper shows an "unidentified developer"
# warning on first open (right-click the .pkg → Open, or allow it in
# System Settings → Privacy & Security). Mention that in download
# instructions only while unsigned.
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
# --scripts: preinstall CURATA doar o instalare veche ramasa (pkill +
# rm -rf /Applications/CursorPro.app), ca sa nu ramana doua copii ale
# aplicatiei cu acelasi bundle ID pe disc. NU contine niciun hack de
# Gatekeeper/quarantine - pachetul e semnat + notarizat + stapled mai jos,
# deci Gatekeeper il accepta nativ (vezi CLAUDE.md, 2026-08-25).
pkgbuild \
    --root "$PAYLOAD_ROOT" \
    --identifier "$PKG_ID" \
    --version "$VERSION" \
    --install-location "/" \
    --scripts "installer/scripts" \
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

# Semnare + notarizare a .pkg-ului final, daca certificatul Installer e
# configurat (vezi codesigning/README.md) - altfel ramane nesemnat.
./codesigning/sign-and-notarize.sh pkg "$FINAL_PKG"

# A version-agnostic copy too — the landing page always links to this
# stable filename (releases/latest/download/CursorProGDC.pkg), so it
# doesn't need editing every release. Upload BOTH files to each GitHub
# release: the versioned one (so old links keep working) and this one
# (so the landing page's link always resolves to whatever is newest).
cp "$FINAL_PKG" "$DIST_DIR/CursorProGDC.pkg"

# [2026-09-20] Regula 45 / K: .zip si .command NU se mai produc. Distributia
# clientului = DMG (release_dmg.sh). Acest .pkg ramane DOAR canal de
# tranzitie pentru Self-Updater-ul vechi (<=1.4.1, cauta CursorProGDC.pkg).
echo "==> Done (canal legacy updater): $FINAL_PKG + $DIST_DIR/CursorProGDC.pkg"
