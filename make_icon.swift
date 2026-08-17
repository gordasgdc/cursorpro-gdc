import AppKit

// Renders the CursorPro app icon: a soft purple->blue gradient rounded
// square (macOS Big Sur+ style — the system masks the corners itself, so
// we just fill the full square), a classic pointer-arrow glyph, and a
// glowing halo ring around it, echoing the app's actual Mouse Halo /
// Spotlight features.

let size = 1024.0
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError() }

let rect = CGRect(x: 0, y: 0, width: size, height: size)

// Background gradient — deep indigo to violet, matching a "spotlight in
// the dark" mood.
let bgColors = [
    NSColor(calibratedRed: 0.10, green: 0.09, blue: 0.20, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.28, green: 0.16, blue: 0.46, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.42, green: 0.22, blue: 0.62, alpha: 1).cgColor
]
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors as CFArray, locations: [0, 0.55, 1])!
ctx.saveGState()
ctx.addRect(rect)
ctx.clip()
ctx.drawLinearGradient(bgGradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])
ctx.restoreGState()

// Soft radial glow behind the cursor, standing in for Spotlight.
let center = CGPoint(x: size * 0.44, y: size * 0.46)
let glowColors = [
    NSColor(calibratedRed: 1.0, green: 0.85, blue: 0.35, alpha: 0.55).cgColor,
    NSColor(calibratedRed: 1.0, green: 0.85, blue: 0.35, alpha: 0.0).cgColor
]
let glowGradient = CGGradient(colorsSpace: colorSpace, colors: glowColors as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(
    glowGradient,
    startCenter: center, startRadius: 0,
    endCenter: center, endRadius: size * 0.42,
    options: []
)

// Halo ring around the cursor — the app's signature feature.
ctx.saveGState()
ctx.setStrokeColor(NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.25, alpha: 0.95).cgColor)
ctx.setLineWidth(size * 0.028)
ctx.setShadow(offset: .zero, blur: size * 0.05, color: NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.25, alpha: 0.8).cgColor)
let haloRadius = size * 0.235
ctx.strokeEllipse(in: CGRect(
    x: center.x - haloRadius, y: center.y - haloRadius,
    width: haloRadius * 2, height: haloRadius * 2
))
ctx.restoreGState()

// Classic pointer-arrow glyph, drawn by hand (no glyph/font dependency),
// white with a soft drop shadow for depth against the gradient.
func pointerPath() -> CGPath {
    // Coordinates authored in a 100x100 box, tip at top-left, then scaled
    // and positioned below.
    let p = CGMutablePath()
    p.move(to: CGPoint(x: 8, y: 92))
    p.addLine(to: CGPoint(x: 8, y: 8))
    p.addLine(to: CGPoint(x: 62, y: 60))
    p.addLine(to: CGPoint(x: 38, y: 63))
    p.addLine(to: CGPoint(x: 52, y: 90))
    p.addLine(to: CGPoint(x: 40, y: 96))
    p.addLine(to: CGPoint(x: 26, y: 69))
    p.addLine(to: CGPoint(x: 8, y: 92))
    p.closeSubpath()
    return p
}

ctx.saveGState()
let glyphScale = size * 0.34 / 100.0
var transform = CGAffineTransform(translationX: center.x - size * 0.10, y: center.y + size * 0.12)
transform = transform.scaledBy(x: glyphScale, y: -glyphScale)
let scaledPath = pointerPath().copy(using: &transform)!

ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.012), blur: size * 0.02, color: NSColor.black.withAlphaComponent(0.45).cgColor)
ctx.addPath(scaledPath)
ctx.setFillColor(NSColor.white.cgColor)
ctx.fillPath()

ctx.addPath(scaledPath)
ctx.setStrokeColor(NSColor(calibratedWhite: 0.15, alpha: 0.9).cgColor)
ctx.setLineWidth(size * 0.008)
ctx.strokePath()
ctx.restoreGState()

img.unlockFocus()

// Export as PNG.
guard let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode PNG")
}
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
try! png.write(to: URL(fileURLWithPath: outPath))
print("Wrote \(outPath)")
