# CursorPro GDC

A native macOS presentation tool for screen recordings and live courses: a cursor **Halo**, a **Spotlight** that dims everything but a circle around your pointer, **Draw** (freehand, arrows, circles, selection frames) with reconfigurable keyboard shortcuts, and a live **Zoom** loupe that magnifies the screen around your cursor.

Built as a lightweight, native (Swift/AppKit) Apple Silicon replacement for tools like Pro Mouse — menu-bar only, no Dock icon, doesn't steal focus from whatever you're presenting.

Romanian / English / Spanish interface.

## Download

Get the latest build from [Releases](../../releases/latest). A **3-day free trial** starts automatically on first launch — every feature works, no license needed to try it.

## Features

- **Halo** — a visible ring around the cursor so it's easy to follow on a projected/shared screen. Ring, filled, or crosshair style; adjustable color and size.
- **Spotlight** — dims the rest of the screen except a circle around the cursor, to pull attention to one spot.
- **Draw** — freehand or shapes (arrow, circle, selection frame) drawn directly over any app, with per-tool keyboard shortcuts you can reassign.
- **Zoom** — a live, magnified loupe that follows the cursor, for showing small UI details clearly.
- All modes activate by holding a key (fully reconfigurable) — nothing stays on by accident.

## License

CursorPro GDC works fully for 3 days from first launch. After that, a license is needed to keep using it — see the **License** page in Preferences, or message on WhatsApp from there to buy one.

Source code in this repository is provided under the MIT license (see [LICENSE](LICENSE)) — it's open for review, but using the distributed app past the trial period requires an activation code, per the app's own terms.

## Building from source

Requires macOS 14+ and Swift 5.9+ (Xcode Command Line Tools).

```bash
git clone https://github.com/gordasgdc/cursorpro-gdc.git
cd cursorpro-gdc
./build_app.sh
```

This builds and installs straight to `/Applications/CursorPro.app`.
