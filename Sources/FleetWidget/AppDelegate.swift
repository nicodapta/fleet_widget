import AppKit
import FleetWidgetCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Sprite animation cadence. Also refreshes the elapsed-time readouts.
    private static let redrawInterval: TimeInterval = 0.15
    private static let screenMargin: CGFloat = 16

    private let preferences = Preferences()
    private let monitor = FleetMonitor(registry: AppDelegate.makeRegistry())
    private lazy var sound = AlertSound(preferences: preferences)

    private var panel: FleetPanel!
    private var contentView: FleetContentView!
    private var redrawTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildPanel()
        startMonitoring()
        startRedrawTimer()
    }

    /// Clicking the Dock icon has nothing to reveal — the panel is always on
    /// screen. Recover the case that does need it: a panel dragged onto a display
    /// that has since been disconnected, which leaves it somewhere unreachable.
    func applicationShouldHandleReopen(
        _ sender: NSApplication, hasVisibleWindows flag: Bool
    ) -> Bool {
        recoverPanelIfOffscreen()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        redrawTimer?.invalidate()
    }

    /// Normally the real registry. `FLEETWIDGET_SESSIONS_DIR` points it at a
    /// fixture directory instead, so the full pipeline can be exercised against
    /// scripted transitions without writing anything into `~/.claude`.
    private static func makeRegistry() -> SessionRegistry {
        if let override = ProcessInfo.processInfo.environment["FLEETWIDGET_SESSIONS_DIR"] {
            return SessionRegistry(directory: URL(fileURLWithPath: override))
        }
        return SessionRegistry()
    }

    // MARK: - Panel

    private func buildPanel() {
        let height = FleetContentView.height(forRowCount: 0)
        let size = NSSize(width: FleetContentView.panelWidth, height: height)

        contentView = FleetContentView(frame: NSRect(origin: .zero, size: size))
        contentView.isMuted = preferences.isMuted
        contentView.onToggleMute = { [weak self] in self?.toggleMute() }
        contentView.onQuit = { NSApp.terminate(nil) }

        panel = FleetPanel(contentRect: NSRect(origin: startingOrigin(for: size), size: size))
        panel.contentView = contentView
        panel.orderFrontRegardless()

        NotificationCenter.default.addObserver(
            self, selector: #selector(panelDidMove),
            name: NSWindow.didMoveNotification, object: panel)
    }

    /// The stored position if it is still usable, otherwise the default corner.
    private func startingOrigin(for size: NSSize) -> NSPoint {
        if let saved = preferences.panelOrigin {
            let candidate = NSRect(origin: saved, size: size)
            // A position saved on a display that is no longer connected would
            // put the widget somewhere the user cannot see or reach.
            let onScreen = NSScreen.screens.contains { $0.visibleFrame.intersects(candidate) }
            if onScreen { return saved }
        }
        return defaultCorner(for: size)
    }

    private func defaultCorner(for size: NSSize) -> NSPoint {
        guard let screen = NSScreen.main else { return NSPoint(x: 100, y: 100) }
        let visible = screen.visibleFrame
        return NSPoint(
            x: visible.maxX - size.width - AppDelegate.screenMargin,
            y: visible.maxY - size.height - AppDelegate.screenMargin)
    }

    /// Snap the panel back to the default corner when it is no longer on any
    /// connected display. A panel that is merely somewhere unexpected is left
    /// alone — the user put it there.
    private func recoverPanelIfOffscreen() {
        let frame = panel.frame
        let onScreen = NSScreen.screens.contains { $0.visibleFrame.intersects(frame) }
        guard !onScreen else {
            panel.orderFrontRegardless()
            return
        }
        panel.setFrameOrigin(defaultCorner(for: frame.size))
        panel.orderFrontRegardless()
        preferences.panelOrigin = panel.frame.origin
    }

    @objc private func panelDidMove() {
        preferences.panelOrigin = panel.frame.origin
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        monitor.onUpdate = { [weak self] sessions in
            self?.apply(sessions: sessions)
        }
        monitor.onAlert = { [weak self] alert in
            self?.sound.play(for: alert.kind)
        }
        monitor.start()
    }

    private func apply(sessions: [LiveSession]) {
        contentView.rows = sessions.map { session in
            FleetRow(session: session, isLatched: monitor.isLatched(sessionId: session.sessionId))
        }
        resizePanel(forRowCount: sessions.count)
    }

    /// Grows and shrinks downward, so the panel's top edge stays put as sessions
    /// come and go.
    private func resizePanel(forRowCount count: Int) {
        let height = FleetContentView.height(forRowCount: count)
        guard abs(panel.frame.height - height) > 0.5 else { return }

        let top = panel.frame.maxY
        let frame = NSRect(
            x: panel.frame.origin.x,
            y: top - height,
            width: FleetContentView.panelWidth,
            height: height)
        panel.setFrame(frame, display: true)
    }

    // MARK: - Controls

    private func toggleMute() {
        preferences.isMuted = !preferences.isMuted
        contentView.isMuted = preferences.isMuted
    }

    private func startRedrawTimer() {
        let timer = Timer(timeInterval: AppDelegate.redrawInterval, repeats: true) { [weak self] _ in
            self?.contentView.advanceFrame()
        }
        RunLoop.main.add(timer, forMode: .common)
        redrawTimer = timer
    }
}
