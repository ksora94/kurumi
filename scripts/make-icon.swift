// Renders a white glyph (icon.svg or icon.png, on transparency) onto a green macOS-style
// rounded square and writes a 1024x1024 PNG. Usage: swift scripts/make-icon.swift <glyph> <output.png>
import AppKit

let background = NSColor(srgbRed: 0x73 / 255.0, green: 0xD1 / 255.0, blue: 0x3D / 255.0, alpha: 1)
let canvasSize = 1024
// Apple's macOS icon grid: an 824pt rounded square centered in the 1024pt canvas.
let bodySize: CGFloat = 824
let cornerRadius: CGFloat = 185.4
let glyphFraction: CGFloat = 0.62

let arguments = CommandLine.arguments
guard arguments.count == 3, let glyph = NSImage(contentsOfFile: arguments[1]) else {
    FileHandle.standardError.write(Data("usage: make-icon.swift <glyph> <output.png>\n".utf8))
    exit(1)
}

func makeBitmap(width: Int, height: Int) -> NSBitmapImageRep {
    NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
}

func render(into rep: NSBitmapImageRep, _ draw: (CGContext) -> Void) {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current!.imageInterpolation = .high
    draw(NSGraphicsContext.current!.cgContext)
    NSGraphicsContext.restoreGraphicsState()
}

/// Bounding box of non-transparent pixels, so the visible shape (not the padded file) is centered.
func opaqueBounds(of rep: NSBitmapImageRep) -> CGRect {
    let width = rep.pixelsWide, height = rep.pixelsHigh
    var minX = width, minY = height, maxX = -1, maxY = -1
    for y in 0..<height {
        for x in 0..<width where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.03 {
            minX = min(minX, x); maxX = max(maxX, x)
            minY = min(minY, y); maxY = max(maxY, y)
        }
    }
    guard maxX >= 0 else { return CGRect(x: 0, y: 0, width: width, height: height) }
    // Bitmap rows run top-down; flip into AppKit's bottom-up coordinates.
    return CGRect(x: minX, y: height - 1 - maxY, width: maxX - minX + 1, height: maxY - minY + 1)
}

// Rasterize once at a fixed probe size only to measure the glyph; the final draw below goes
// through NSImage again, so vector sources stay sharp at any output size.
let probeWidth = 512
let probeHeight = max(1, Int((CGFloat(probeWidth) * glyph.size.height / glyph.size.width).rounded()))
let probe = makeBitmap(width: probeWidth, height: probeHeight)
render(into: probe) { _ in
    glyph.draw(in: NSRect(x: 0, y: 0, width: probeWidth, height: probeHeight))
}
let bounds = opaqueBounds(of: probe)

let output = makeBitmap(width: canvasSize, height: canvasSize)
render(into: output) { context in
    let inset = (CGFloat(canvasSize) - bodySize) / 2
    let body = CGRect(x: inset, y: inset, width: bodySize, height: bodySize)
    context.addPath(CGPath(roundedRect: body, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil))
    context.setFillColor(background.cgColor)
    context.fillPath()

    let scale = bodySize * glyphFraction / max(bounds.width, bounds.height)
    let drawRect = NSRect(
        x: body.midX - bounds.midX * scale,
        y: body.midY - bounds.midY * scale,
        width: CGFloat(probeWidth) * scale,
        height: CGFloat(probeHeight) * scale
    )
    glyph.draw(in: drawRect)
}

guard let png = output.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: arguments[2]))
