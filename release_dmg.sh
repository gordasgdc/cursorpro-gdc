#!/usr/bin/env bash
# Release macOS (Regula 45 / K): CursorPro.app semnat Developer ID -> notarizat
# -> stapled, împachetat în DMG (aplicație + link Aplicații + ghid PDF), DMG
# semnat + notarizat + stapled, verificat cu spctl și după montare.
# Profil notarizare: Keychain `gdc-notary`. NU produce .zip / .command.
set -euo pipefail
cd "$(dirname "$0")"
PROFILE="${NOTARY_PROFILE:-gdc-notary}"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist)
SIGN_ID="${SIGN_IDENTITY:-Developer ID Application: DUMITRU CRISTINEL GORDAS (8AR6XP8MG7)}"
DIST="dist"; DMG="$DIST/CursorProGDC-$VERSION.dmg"
WORK="$(mktemp -d)"; trap 'hdiutil detach "$WORK/mnt" -quiet 2>/dev/null; rm -rf "$WORK"' EXIT
fail() { echo "‼️  $*" >&2; exit 1; }
notarize() { # $1 = fișier
  local out st id
  out=$(xcrun notarytool submit "$1" --keychain-profile "$PROFILE" --wait --output-format json) || fail "notarytool a eșuat"
  st=$(printf '%s' "$out" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("status",""))')
  id=$(printf '%s' "$out" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("id",""))')
  [ "$st" = Accepted ] || { xcrun notarytool log "$id" --keychain-profile "$PROFILE" | head -40 >&2; fail "respins ($st)"; }
}

# 1. Build (build_app.sh semnează Developer ID și instalează în /Applications)
./build_app.sh >/dev/null || fail "build_app.sh a eșuat"
APP="/Applications/CursorPro.app"
codesign --verify --strict --deep "$APP" || fail "semnătură invalidă"
echo "✓ Build $VERSION semnat"

# 2. Notarizare + staple aplicație
ditto -c -k --keepParent "$APP" "$WORK/app.zip"; notarize "$WORK/app.zip"
xcrun stapler staple "$APP" >/dev/null && xcrun stapler validate "$APP" >/dev/null || fail "staple aplicație"
grep -q "Notarized Developer ID" < <(spctl -a -vv -t exec "$APP" 2>&1) || fail "spctl respinge aplicația"
echo "✓ Aplicație notarizată + stapled"

# 3. DMG
STAGE="$WORK/stage"; mkdir -p "$STAGE" "$DIST"
ditto "$APP" "$STAGE/CursorPro.app"
cp installer/Instructiuni-CursorProGDC.pdf "$STAGE/Instructiuni_Utilizare.pdf"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "CursorPro GDC $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null || fail "hdiutil"
codesign --force --sign "$SIGN_ID" --timestamp "$DMG" || fail "semnare DMG"
notarize "$DMG"
xcrun stapler staple "$DMG" >/dev/null && xcrun stapler validate "$DMG" >/dev/null || fail "staple DMG"
grep -q "Notarized Developer ID" < <(spctl -a -vv -t open --context context:primary-signature "$DMG" 2>&1) || fail "spctl respinge DMG"

# 4. Verificare ca pe Mac-ul clientului
mkdir -p "$WORK/mnt"; hdiutil attach "$DMG" -mountpoint "$WORK/mnt" -nobrowse -readonly >/dev/null || fail "montare"
C="$WORK/mnt/CursorPro.app"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$C/Contents/Info.plist")" = "$VERSION" ] || fail "versiune diferită în DMG"
codesign --verify --strict --deep "$C" || fail "semnătură invalidă în DMG"
xcrun stapler validate "$C" >/dev/null || fail "fără bilet în DMG"
grep -q "Notarized Developer ID" < <(spctl -a -vv -t exec "$C" 2>&1) || fail "spctl respinge aplicația din DMG"
cp "$DMG" "$DIST/CursorProGDC.dmg"   # nume stabil, alături de cel versionat (Regula 17)
echo "✓ ${DMG##*/}: semnat, notarizat, stapled, acceptat de Gatekeeper"
echo "  sha256: $(shasum -a 256 "$DMG" | cut -d' ' -f1)"
