#!/bin/bash
# Instalare_CursorPro.command
# First-run launcher: removes the Gatekeeper quarantine flag from the
# .pkg installer (set by the browser on download) and opens it, so the
# colleague sees a normal "Open" prompt instead of the unidentified-
# developer warning / right-click -> Open detour.
#
# Deliberately does NOT re-sign anything. CursorPro.app is signed by
# build_app.sh with a persistent local Keychain identity so TCC grants
# (Accessibility / Screen Recording) survive rebuilds — re-signing here
# with a different identity would break that. See build_app.sh for the
# full explanation.

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PKG_PATH="$(find "${DIR}" -maxdepth 1 -iname "*.pkg" -print -quit)"

if [ -n "${PKG_PATH}" ] && [ -f "${PKG_PATH}" ]; then
    echo "==> Preparing $(basename "${PKG_PATH}") for first run..."
    xattr -dr com.apple.quarantine "${PKG_PATH}" 2>/dev/null
    open "${PKG_PATH}"
    sleep 1
    osascript -e 'tell application "Terminal" to close front window' 2>/dev/null &
else
    echo "Error: no .pkg installer found in this folder (${DIR})."
    read -p "Press Enter to close..."
fi
