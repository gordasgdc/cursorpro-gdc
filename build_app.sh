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

# BUG REAL (2026-09-04, gasit la audit — vezi acelasi fix deja aplicat in
# gdc-plugin-manager-catalog-vendor/build_furnizor_app.sh): resursele SPM
# (Package.swift `resources:`) se instaleaza intr-un .bundle separat,
# langa executabil, in .build/release/ — `swift build` NU il copiaza
# automat in Contents/Resources/ al .app-ului instalat. Fara acest pas,
# Bundle.module.url(...) (HelpGuide.swift) ar fi intors mereu nil in
# aplicatia instalata, desi mergea perfect la `swift run` local — exact
# genul de discrepanta greu de prins fara sa testezi explicit .app-ul
# din /Applications, nu doar build-ul din sursa.
SPM_RESOURCE_BUNDLE=".build/release/CursorPro_CursorPro.bundle"
if [ -d "$SPM_RESOURCE_BUNDLE" ]; then
    cp -R "$SPM_RESOURCE_BUNDLE" "$BUILD_OUT/Contents/Resources/"
fi

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
#
# [2026-09-12] CAUZA REALA a permisiunilor "care nu se retin", gasita direct in
# baza de date TCC a sistemului: macOS leaga permisiunea de o CERINTA DE
# SEMNATURA, nu de calea aplicatiei. Intrarea salvata pe aceasta masina cerea
# certificatul local auto-semnat "CursorPro"; build-ul instalat era semnat
# Developer ID, deci nu o mai indeplinea — sistemul cerea permisiunea la
# FIECARE pornire, desi in Setari bifa ramanea aprinsa.
#
# De aceea fallback-ul auto-semnat NU mai e implicit: daca exista un Developer
# ID in breloc, se foloseste ALA, si identitatea ramane aceeasi intre build-ul
# local si cel livrat. Fallback-ul ramane posibil, dar explicit si zgomotos.
if [ -n "${APPLE_SIGN_IDENTITY_APP:-}" ]; then
    ./codesigning/sign-and-notarize.sh app "$BUILD_OUT"
else
    DEV_ID=$(security find-identity -v -p codesigning 2>/dev/null \
             | grep -m1 "Developer ID Application" | sed -E 's/.*"(.*)"/\1/')
    if [ -n "$DEV_ID" ]; then
        echo "  Semnez cu identitatea reala din breloc: $DEV_ID"
        echo "  (aceeasi ca la build-urile livrate — permisiunile acordate raman valabile)"
        codesign --force --deep --sign "$DEV_ID" --options runtime "$BUILD_OUT"
    elif [ "${CURSORPRO_ALLOW_SELFSIGNED:-}" = "1" ]; then
        echo "  ATENTIE: semnez cu certificatul local auto-semnat \"CursorPro\"." >&2
        echo "  Permisiunile acordate acestui build NU vor mai fi valabile pentru" >&2
        echo "  un build semnat Developer ID, si invers — sistemul le va cere din" >&2
        echo "  nou la fiecare pornire. Foloseste-l doar pentru teste izolate." >&2
        codesign --force --deep --sign "CursorPro" "$BUILD_OUT"
    else
        echo "EROARE: niciun 'Developer ID Application' in breloc si nici" >&2
        echo "APPLE_SIGN_IDENTITY_APP setat." >&2
        echo "" >&2
        echo "Semnarea cu certificatul local auto-semnat ar rupe permisiunile deja" >&2
        echo "acordate (Accesibilitate / Inregistrare ecran) — de aceea nu se mai" >&2
        echo "face automat. Daca chiar vrei asta pentru un test izolat:" >&2
        echo "    CURSORPRO_ALLOW_SELFSIGNED=1 ./build_app.sh" >&2
        exit 1
    fi
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
