#!/usr/bin/env bash
# Builds CursorPro.app from the SPM executable + Info.plist, and installs
# it straight to /Applications — the ONLY copy that's ever allowed to
# exist on disk. (Previously this script left a second copy behind in the
# project folder too. Two .app bundles sharing the same bundle identifier
# confuses macOS's permission system — TCC couldn't reliably tell which
# copy a grant applied to, so Screen Recording/Accessibility kept
# re-prompting forever. Never reintroduce a second copy.)
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="CursorPro.app"
BUILD_OUT="/tmp/CursorPro.app.build-$$"
rm -rf "$BUILD_OUT"
mkdir -p "$BUILD_OUT/Contents/MacOS"
mkdir -p "$BUILD_OUT/Contents/Resources"

cp .build/release/CursorPro "$BUILD_OUT/Contents/MacOS/CursorPro"
cp Info.plist "$BUILD_OUT/Contents/Info.plist"
cp AppIcon.icns "$BUILD_OUT/Contents/Resources/AppIcon.icns"

# Sign with the local "CursorPro" self-signed certificate (created once
# in Keychain Access, trusted for Code Signing) instead of ad-hoc (-).
# TCC/Accessibility/Screen Recording grants bind to a signing identity —
# ad-hoc's identity can be treated as "a new app" on rebuild, causing
# permissions to silently stop applying. A real (even self-signed, local)
# identity stays the same across every future rebuild, so permissions
# granted once should keep working from here on.
#
# GDC-SEC: odata trecut la Developer ID real (vezi codesigning/README.md),
# identitatea de semnare SE SCHIMBA fata de "CursorPro" ad-hoc - macOS va
# trata asta ca o aplicatie noua pentru TCC O SINGURA DATA, deci userii
# vor trebui sa re-acorde manual Accessibility/Screen Recording dupa
# PRIMA actualizare la versiunea semnata cu Developer ID. Mentioneaza
# asta explicit in notele de release ale acelei versiuni.
if [ -n "${APPLE_SIGN_IDENTITY_APP:-}" ]; then
    ./codesigning/sign-and-notarize.sh app "$BUILD_OUT"
else
    SIGN_IDENTITY="CursorPro"
    codesign --force --deep --sign "$SIGN_IDENTITY" "$BUILD_OUT"
fi

# Install straight to /Applications (the one macOS Privacy & Security
# actually lists, and the one permission grants attach to), then remove
# the scratch build dir — never leave a second registered copy anywhere.
INSTALLED="/Applications/CursorPro.app"
if [ -d "$INSTALLED" ]; then
    pkill -x CursorPro 2>/dev/null || true
    sleep 0.5
fi
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSREGISTER" -u "$INSTALLED" 2>/dev/null || true
# sudo on purpose: a previous .pkg-based install (or Installer.app) can
# leave /Applications/CursorPro.app root-owned, which makes a plain
# rm/mv fail with "Permission denied" - asking for the admin password up
# front here means the script always works, prompting only when
# actually needed (sudo -n checks first, no prompt if already owned by
# the current user). Vezi build_app.sh din GDCPluginManager - acelasi fix.
if [ -e "$INSTALLED" ] && [ ! -O "$INSTALLED" ]; then
    sudo rm -rf "$INSTALLED"
    sudo mv "$BUILD_OUT" "$INSTALLED"
    sudo chown -R "$(id -u):$(id -g)" "$INSTALLED"
else
    rm -rf "$INSTALLED"
    rm -rf "$APP" # stray leftover from older versions of this script, if present
    mv "$BUILD_OUT" "$INSTALLED"
fi
"$LSREGISTER" -f "$INSTALLED" 2>/dev/null || true
echo "Installed to $INSTALLED"
