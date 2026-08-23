import AppKit

/// Generates the app icon as an `.iconset` directory for `iconutil`.
///
/// The icon is drawn from the same string-bitmap as the header mark rather than
/// from an image file, so there is still no binary art in the repository and the
/// icon cannot drift away from what the widget shows.
enum IconRenderer {
    /// Sizes macOS expects in an iconset, as (file name, pixel size).
    private static let variants: [(String, Int)] = [
        ("icon_16x16", 16), ("icon_16x16@2x", 32),
        ("icon_32x32", 32), ("icon_32x32@2x", 64),
        ("icon_128x128", 128), ("icon_128x128@2x", 256),
        ("icon_256x256", 256), ("icon_256x256@2x", 512),
        ("icon_512x512", 512), ("icon_512x512@2x", 1024),
    ]

    static func writeIconset(to directory: String) -> Int32 {
        _ = NSApplication.shared
        let url = URL(fileURLWithPath: directory)
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            print("FAIL: could not create \(directory): \(error)")
            return 1
        }

        for (name, size) in variants {
            guard let data = png(size: size) else {
                print("FAIL: could not render \(name)")
                return 1
            }
            do {
                try data.write(to: url.appendingPathComponent("\(name).png"))
            } catch {
                print("FAIL: could not write \(name): \(error)")
                return 1
            }
        }
        print("wrote \(variants.count) icon sizes to \(directory)")
        return 0
    }

    private static func png(size: Int) -> Data? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        rep.size = NSSize(width: size, height: size)

        guard let graphics = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        let context = graphics.cgContext
        let side = CGFloat(size)

        // Rounded square, inset like a standard macOS icon so it does not fill
        // its whole tile.
        let inset = side * 0.08
        let plate = CGRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
        let radius = plate.width * 0.2237  // macOS squircle corner ratio
        let path = NSBezierPath(roundedRect: plate, xRadius: radius, yRadius: radius)
        NSColor(srgbRed: 0.07, green: 0.08, blue: 0.11, alpha: 1).setFill()
        path.fill()
        NSColor(srgbRed: 0.30, green: 0.34, blue: 0.40, alpha: 0.55).setStroke()
        path.lineWidth = max(1, side * 0.006)
        path.stroke()

        // Below about 64pt the 11x11 mark loses its diagonals, so the compact
        // 7x7 form is used instead of a muddy downscale.
        let bitmap = size < 64 ? ClaudeMark.compact : ClaudeMark.full
        let grid = CGFloat(bitmap.count)
        let pixelSize = max(1, floor(side * 0.60 / grid))
        let markSide = pixelSize * grid
        let origin = CGPoint(x: (side - markSide) / 2, y: (side - markSide) / 2)

        // PixelRenderer works top-down; flip into that space.
        context.translateBy(x: 0, y: side)
        context.scaleBy(x: 1, y: -1)
        PixelRenderer.draw(
            bitmap: bitmap, topLeft: origin, pixelSize: pixelSize,
            palette: ClaudeMark.palette, alpha: 1.0, in: context)

        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }
}
