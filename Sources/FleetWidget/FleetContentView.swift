import AppKit
import FleetWidgetCore

/// One rendered session row.
struct FleetRow {
    let session: LiveSession
    /// The session has alerted for the status it is in and the user has not
    /// returned to it yet. Used to hold a finished session at full prominence.
    let isLatched: Bool

    var appearance: SessionAppearance {
        return SessionAppearance(status: session.status, isLatched: isLatched)
    }
}

/// How loudly a row is drawn. Idle is the common resting state, so an untiered
/// widget becomes a uniform block the eye learns to skip.
private enum Prominence {
    case attention  // needs the user right now
    case active     // working
    case resting    // parked

    var alpha: CGFloat {
        switch self {
        case .attention: return 1.0
        case .active:    return 0.85
        case .resting:   return 0.42
        }
    }
}

final class FleetContentView: NSView {
    // Layout
    static let panelWidth: CGFloat = 252
    static let headerHeight: CGFloat = 26
    static let rowHeight: CGFloat = 40
    static let bottomPadding: CGFloat = 8
    private static let spritePixel: CGFloat = 3
    static let blockedAmber = NSColor(srgbRed: 1.00, green: 0.72, blue: 0.25, alpha: 1)
    private static let spriteInset: CGFloat = 12

    var rows: [FleetRow] = [] { didSet { needsDisplay = true } }
    var isMuted: Bool = false { didSet { needsDisplay = true } }

    var onToggleMute: (() -> Void)?
    var onQuit: (() -> Void)?

    private var frameIndex: Int = 0
    /// Control hit regions, recomputed on each draw. Not private so the
    /// interaction self-test can verify them against the drawn glyphs.
    private(set) var muteHitRect: NSRect = .zero
    private(set) var quitHitRect: NSRect = .zero

    override var isFlipped: Bool { return true }

    /// Height the panel needs for the current rows.
    static func height(forRowCount count: Int) -> CGFloat {
        let bodyRows = max(count, 1) // the empty state occupies one row
        return headerHeight + CGFloat(bodyRows) * rowHeight + bottomPadding
    }

    /// Advances sprite animation. Driven by the app's redraw timer.
    func advanceFrame() {
        frameIndex = frameIndex &+ 1
        needsDisplay = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let now = Date()

        drawBackground(in: context)
        drawHeader(in: context)

        if rows.isEmpty {
            drawEmptyState()
            return
        }
        for (index, row) in rows.enumerated() {
            let top = FleetContentView.headerHeight + CGFloat(index) * FleetContentView.rowHeight
            draw(row: row, top: top, now: now, in: context)
        }
    }

    private func drawBackground(in context: CGContext) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        NSColor(srgbRed: 0.05, green: 0.06, blue: 0.08, alpha: 0.94).setFill()
        path.fill()
        NSColor(srgbRed: 0.30, green: 0.34, blue: 0.40, alpha: 0.55).setStroke()
        path.lineWidth = 1
        path.stroke()
        _ = context
    }

    private func drawHeader(in context: CGContext) {
        let titleFont = NSFont.monospacedSystemFont(ofSize: 9, weight: .bold)
        // The header takes the colour of the most urgent thing in the list, so the
        // widget reads at a glance even before the rows are scanned.
        let titleColor: NSColor
        if rows.contains(where: { $0.appearance == .blocked }) {
            titleColor = FleetContentView.blockedAmber
        } else if rows.contains(where: { $0.appearance == .done }) {
            titleColor = SpritePalette.claudeOrange
        } else {
            titleColor = NSColor(srgbRed: 0.55, green: 0.60, blue: 0.68, alpha: 1.0)
        }

        // The mark carries the same colour as the title, so the header reads as a
        // single status indicator rather than a logo next to some text.
        let markPixel: CGFloat = 2
        let markSide = CGFloat(ClaudeMark.compact.count) * markPixel
        PixelRenderer.draw(
            bitmap: ClaudeMark.compact,
            topLeft: CGPoint(x: 11, y: (FleetContentView.headerHeight - markSide) / 2),
            pixelSize: markPixel,
            palette: ClaudeMark.palette(tinted: titleColor),
            alpha: 1.0,
            in: context)

        ("FLEET" as NSString).draw(
            at: NSPoint(x: 11 + markSide + 7, y: 9),
            withAttributes: [.font: titleFont, .foregroundColor: titleColor])

        // Controls, right-aligned. Mute has no home outside the panel, and quit
        // belongs beside it: reaching for the menu bar means leaving the widget.
        let controlFont = NSFont.monospacedSystemFont(ofSize: 8, weight: .semibold)
        let dim = NSColor(srgbRed: 0.50, green: 0.55, blue: 0.62, alpha: 1.0)

        let quitText = "X" as NSString
        let quitSize = quitText.size(withAttributes: [.font: controlFont])
        let quitOrigin = NSPoint(x: bounds.width - 12 - quitSize.width, y: 10)
        quitText.draw(at: quitOrigin, withAttributes: [.font: controlFont, .foregroundColor: dim])
        quitHitRect = NSRect(x: quitOrigin.x - 5, y: 4, width: quitSize.width + 10, height: 18)

        let muteText = (isMuted ? "MUTE" : "SND") as NSString
        let muteSize = muteText.size(withAttributes: [.font: controlFont])
        let muteOrigin = NSPoint(x: quitOrigin.x - 10 - muteSize.width, y: 10)
        let muteColor = isMuted
            ? NSColor(srgbRed: 0.85, green: 0.42, blue: 0.38, alpha: 1.0) : dim
        muteText.draw(at: muteOrigin, withAttributes: [.font: controlFont, .foregroundColor: muteColor])
        muteHitRect = NSRect(x: muteOrigin.x - 5, y: 4, width: muteSize.width + 10, height: 18)

        // Hairline under the header.
        NSColor(srgbRed: 0.25, green: 0.28, blue: 0.34, alpha: 0.7).setFill()
        NSRect(x: 8, y: FleetContentView.headerHeight - 1,
               width: bounds.width - 16, height: 1).fill()
    }

    private func drawEmptyState() {
        let font = NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
        let color = NSColor(srgbRed: 0.45, green: 0.48, blue: 0.55, alpha: 0.75)
        let text = "no claude sessions" as NSString
        let size = text.size(withAttributes: [.font: font])
        text.draw(
            at: NSPoint(x: (bounds.width - size.width) / 2,
                        y: FleetContentView.headerHeight + FleetContentView.rowHeight / 2 - size.height / 2),
            withAttributes: [.font: font, .foregroundColor: color])
    }

    private func draw(row: FleetRow, top: CGFloat, now: Date, in context: CGContext) {
        let appearance = row.appearance
        let alpha = prominence(for: row).alpha

        // Sprite, vertically centred in the row.
        let frames = Sprite.frames(for: appearance)
        let bitmap = frames[frameIndex % frames.count]
        let spriteSide = CGFloat(Sprite.side) * FleetContentView.spritePixel

        // Only a blocked session bounces. A finished one is prominent but still,
        // so its occasional glance is the only movement drawing the eye.
        let bounce: CGFloat = (appearance == .blocked && frameIndex % 2 == 0) ? -2 : 0
        let spriteTop = top + (FleetContentView.rowHeight - spriteSide) / 2 + bounce

        PixelRenderer.draw(
            bitmap: bitmap,
            topLeft: CGPoint(x: FleetContentView.spriteInset, y: spriteTop),
            pixelSize: FleetContentView.spritePixel,
            palette: SpritePalette.palette(for: appearance),
            alpha: alpha,
            in: context)

        let textX = FleetContentView.spriteInset + spriteSide + 12
        let rightEdge = bounds.width - 12

        // Label.
        let labelFont = NSFont.monospacedSystemFont(ofSize: 10, weight: .medium)
        let labelColor = NSColor(srgbRed: 0.88, green: 0.91, blue: 0.95, alpha: alpha)
        let label = truncate(row.session.label, font: labelFont, maxWidth: rightEdge - textX)
        (label as NSString).draw(
            at: NSPoint(x: textX, y: top + 7),
            withAttributes: [.font: labelFont, .foregroundColor: labelColor])

        // Elapsed, right-aligned on the caption line.
        let captionFont = NSFont.monospacedSystemFont(ofSize: 8.5, weight: .regular)
        var captionLimit = rightEdge - textX
        if let elapsed = row.session.elapsedInStatus(at: now) {
            let text = format(elapsed: elapsed) as NSString
            let size = text.size(withAttributes: [.font: captionFont])
            text.draw(
                at: NSPoint(x: rightEdge - size.width, y: top + 21),
                withAttributes: [
                    .font: captionFont,
                    .foregroundColor: NSColor(srgbRed: 0.55, green: 0.60, blue: 0.68, alpha: alpha),
                ])
            captionLimit -= (size.width + 8)
        }

        // Caption.
        let captionColor = captionTint(for: row).withAlphaComponent(alpha)
        let caption = truncate(captionText(for: row), font: captionFont, maxWidth: captionLimit)
        (caption as NSString).draw(
            at: NSPoint(x: textX, y: top + 21),
            withAttributes: [.font: captionFont, .foregroundColor: captionColor])
    }

    // MARK: - Row presentation

    private func prominence(for row: FleetRow) -> Prominence {
        // A finished session stays prominent until the user goes back to it,
        // which is exactly when the alert latch clears.
        if row.appearance.needsUser { return .attention }
        if row.appearance == .busy { return .active }
        return .resting
    }

    private func captionText(for row: FleetRow) -> String {
        switch row.appearance {
        case .blocked:
            if let reason = row.session.waitingFor, !reason.isEmpty {
                return "YOUR TURN · \(reason)"
            }
            return "YOUR TURN"
        case .busy:    return "working"
        case .done:    return "DONE"
        case .idle:    return "idle"
        case .shell:   return "shell running"
        case .unknown: return "unknown state"
        }
    }

    private func captionTint(for row: FleetRow) -> NSColor {
        switch row.appearance {
        case .blocked: return FleetContentView.blockedAmber
        case .done:    return SpritePalette.claudeOrange
        case .busy:    return NSColor(srgbRed: 0.45, green: 0.80, blue: 0.75, alpha: 1)
        default:       return NSColor(srgbRed: 0.55, green: 0.60, blue: 0.68, alpha: 1)
        }
    }

    private func format(elapsed: TimeInterval) -> String {
        let total = Int(elapsed)
        if total < 3600 {
            return String(format: "%d:%02d", total / 60, total % 60)
        }
        return String(format: "%dh %02dm", total / 3600, (total % 3600) / 60)
    }

    private func truncate(_ text: String, font: NSFont, maxWidth: CGFloat) -> String {
        guard maxWidth > 0 else { return "" }
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        if (text as NSString).size(withAttributes: attributes).width <= maxWidth { return text }

        var result = text
        while !result.isEmpty {
            result.removeLast()
            let candidate = result + "…"
            if (candidate as NSString).size(withAttributes: attributes).width <= maxWidth {
                return candidate
            }
        }
        return ""
    }

    // MARK: - Interaction

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard handleClick(at: point) else {
            // Anywhere outside a control drags the panel. `performDrag` on a
            // non-activating panel moves the window without stealing focus
            // from the frontmost app.
            window?.performDrag(with: event)
            return
        }
    }

    /// Routes a click in view coordinates to a control.
    /// Returns true when a control consumed it, false when it should drag.
    @discardableResult
    func handleClick(at point: NSPoint) -> Bool {
        if muteHitRect.contains(point) {
            onToggleMute?()
            return true
        }
        if quitHitRect.contains(point) {
            onQuit?()
            return true
        }
        return false
    }
}
