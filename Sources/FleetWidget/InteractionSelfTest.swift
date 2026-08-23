import AppKit
import FleetWidgetCore

/// Verifies that the header controls are actually reachable.
///
/// This app is an accessory with no Dock icon and no menu bar item, so the panel's
/// own quit glyph is the only way to close it. A hit region that drifted away from
/// the drawn glyph would strand the user, and that geometry depends on runtime font
/// metrics that a headless unit test in the core target cannot see.
enum InteractionSelfTest {
    static func run() -> Int32 {
        _ = NSApplication.shared

        let view = FleetContentView(frame: NSRect(
            x: 0, y: 0,
            width: FleetContentView.panelWidth,
            height: FleetContentView.height(forRowCount: 1)))
        view.rows = [FleetRow(
            session: LiveSession(
                pid: 1, sessionId: "s", label: "probe", cwd: "/tmp",
                status: .idle, waitingFor: nil,
                statusChangedAt: Date(), startedAt: Date()),
            isLatched: false)]

        // Drawing is what computes the hit regions.
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            print("FAIL: could not create offscreen rep")
            return 1
        }
        view.cacheDisplay(in: view.bounds, to: rep)

        var failures: [String] = []
        func check(_ condition: Bool, _ message: String) {
            if condition { print("ok   \(message)") } else { failures.append(message) }
        }

        check(!view.muteHitRect.isEmpty, "mute hit region was computed")
        check(!view.quitHitRect.isEmpty, "quit hit region was computed")
        check(!view.muteHitRect.intersects(view.quitHitRect), "mute and quit regions do not overlap")
        check(view.bounds.contains(view.muteHitRect), "mute region lies inside the panel")
        check(view.bounds.contains(view.quitHitRect), "quit region lies inside the panel")

        var muteFired = false
        var quitFired = false
        view.onToggleMute = { muteFired = true }
        view.onQuit = { quitFired = true }

        check(view.handleClick(at: center(of: view.muteHitRect)) && muteFired,
              "clicking the mute glyph toggles mute")
        check(view.handleClick(at: center(of: view.quitHitRect)) && quitFired,
              "clicking the quit glyph quits")

        // A click on a session row must fall through to the window drag.
        muteFired = false
        quitFired = false
        let rowPoint = NSPoint(x: 60, y: FleetContentView.headerHeight + 20)
        check(!view.handleClick(at: rowPoint) && !muteFired && !quitFired,
              "clicking a row falls through to dragging")

        for failure in failures { print("FAIL \(failure)") }
        print(failures.isEmpty ? "interaction self-test passed" : "interaction self-test FAILED")
        return failures.isEmpty ? 0 : 1
    }

    private static func center(of rect: NSRect) -> NSPoint {
        return NSPoint(x: rect.midX, y: rect.midY)
    }
}
