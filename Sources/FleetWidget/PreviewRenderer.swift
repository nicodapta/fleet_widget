import AppKit
import FleetWidgetCore

/// Renders one frame of the widget offscreen to a PNG.
///
/// A development aid: it makes the pixel art and layout inspectable without
/// screen-recording permission or a running Claude Code fleet. Inert unless
/// `--render-preview` is passed.
enum PreviewRenderer {
    static func write(to path: String, scale: CGFloat = 3) {
        _ = NSApplication.shared // initialize AppKit for font and color services

        let now = Date()
        func makeSession(
            _ id: String, _ label: String, _ status: SessionStatus,
            _ waitingFor: String?, secondsAgo: TimeInterval
        ) -> LiveSession {
            return LiveSession(
                pid: 1, sessionId: id, label: label, cwd: "/tmp/\(label)",
                status: status, waitingFor: waitingFor,
                statusChangedAt: now.addingTimeInterval(-secondsAgo),
                startedAt: now.addingTimeInterval(-3600))
        }

        let rows = [
            FleetRow(session: makeSession("a", "claude-widget-43", .busy, nil, secondsAgo: 42),
                     isLatched: false),
            FleetRow(session: makeSession("b", "invoice-sync-f4", .waiting, "input needed", secondsAgo: 15),
                     isLatched: true),
            FleetRow(session: makeSession("c", "atlas-sts-9c", .idle, nil, secondsAgo: 8),
                     isLatched: true),   // -> DONE, Claude orange
            FleetRow(session: makeSession("d", "spotify-snippets-a1", .idle, nil, secondsAgo: 754),
                     isLatched: false),
            FleetRow(session: makeSession("e", "mad-libs-rbr-game", .shell, nil, secondsAgo: 4210),
                     isLatched: false),
            FleetRow(session: makeSession("f", "some-future-state", .unknown, nil, secondsAgo: 30),
                     isLatched: false),
        ]

        render(rows: rows, to: path, scale: scale)

        // The empty state is a distinct layout, so it gets its own frame.
        let base = (path as NSString).deletingPathExtension
        render(rows: [], to: base + "-empty.png", scale: scale)

        // A filmstrip of the finished state's animation cycle, so the occasional
        // glance can be checked without watching the widget in real time.
        markStrip(to: base + "-marks.png")

        filmstrip(
            frames: Sprite.done, appearance: .done,
            indices: [0, 17, 18, 20, 21, 23, 24, 26, 28],
            to: base + "-glance.png", scale: 6)
    }

    /// Candidate header marks, side by side.
    static func markStrip(to path: String) {
        let candidates = [ClaudeMark.compact, ClaudeMark.full]
        let pixel: CGFloat = 2, gap: CGFloat = 6, scale: CGFloat = 8
        let side = CGFloat(11) * pixel
        let width = CGFloat(candidates.count) * (side + gap) + gap
        let height = side + gap * 2
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
        rep.size = NSSize(width: width, height: height)
        guard let graphics = NSGraphicsContext(bitmapImageRep: rep) else { return }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        let context = graphics.cgContext
        context.setFillColor(NSColor(srgbRed: 0.05, green: 0.06, blue: 0.08, alpha: 1).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.translateBy(x: 0, y: height); context.scaleBy(x: 1, y: -1)
        for (slot, bitmap) in candidates.enumerated() {
            PixelRenderer.draw(
                bitmap: bitmap, topLeft: CGPoint(x: gap + CGFloat(slot) * (side + gap), y: gap),
                pixelSize: pixel, palette: ClaudeMark.palette, alpha: 1, in: context)
        }
        NSGraphicsContext.restoreGraphicsState()
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: URL(fileURLWithPath: path))
    }

    /// Lays out selected frames of one sprite side by side.
    private static func filmstrip(
        frames: [[String]], appearance: SessionAppearance,
        indices: [Int], to path: String, scale: CGFloat
    ) {
        let pixel: CGFloat = 2
        let side = CGFloat(Sprite.side) * pixel
        let gap: CGFloat = 4
        let width = CGFloat(indices.count) * (side + gap) + gap
        let height = side + gap * 2

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return }
        rep.size = NSSize(width: width, height: height)

        guard let graphics = NSGraphicsContext(bitmapImageRep: rep) else { return }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        let context = graphics.cgContext

        context.setFillColor(NSColor(srgbRed: 0.05, green: 0.06, blue: 0.08, alpha: 1).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        // Flip into the top-down space PixelRenderer expects.
        context.translateBy(x: 0, y: height)
        context.scaleBy(x: 1, y: -1)

        for (slot, index) in indices.enumerated() {
            PixelRenderer.draw(
                bitmap: frames[index % frames.count],
                topLeft: CGPoint(x: gap + CGFloat(slot) * (side + gap), y: gap),
                pixelSize: pixel,
                palette: SpritePalette.palette(for: appearance),
                alpha: 1.0,
                in: context)
        }
        NSGraphicsContext.restoreGraphicsState()

        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: URL(fileURLWithPath: path))
        FileHandle.standardError.write("wrote \(path)\n".data(using: .utf8)!)
    }

    private static func render(rows: [FleetRow], to path: String, scale: CGFloat) {
        let width = FleetContentView.panelWidth
        let height = FleetContentView.height(forRowCount: rows.count)
        let view = FleetContentView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        view.rows = rows

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return }

        // Reporting a smaller point size than the pixel dimensions gives the
        // drawing context its scale factor.
        rep.size = NSSize(width: width, height: height)

        guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        view.displayIgnoringOpacity(view.bounds, in: context)
        NSGraphicsContext.restoreGraphicsState()

        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: URL(fileURLWithPath: path))
        FileHandle.standardError.write("wrote \(path)\n".data(using: .utf8)!)
    }
}
