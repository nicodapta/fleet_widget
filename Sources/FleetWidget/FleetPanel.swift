import AppKit

/// The always-on-top, non-activating panel the widget lives in.
final class FleetPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            // `.nonactivatingPanel` is what lets the panel be clicked without
            // pulling focus away from the terminal the user is working in.
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false)

        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true

        // Present in every Space, and above fullscreen windows rather than
        // being left behind on the desktop Space.
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
    }

    // A HUD that never takes focus.
    override var canBecomeKey: Bool { return false }
    override var canBecomeMain: Bool { return false }
}
