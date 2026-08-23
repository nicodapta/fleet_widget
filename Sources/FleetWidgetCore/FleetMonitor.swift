import Foundation

/// Drives the poll loop and joins the registry to the alert engine.
///
/// This is the only stateful coordinator in the core: everything below it is
/// either pure or explicitly injected, which is what makes the discovery and
/// alerting logic testable without a running Claude Code.
public final class FleetMonitor {
    /// Poll cadence. Fast enough that added latency is invisible against human
    /// reaction time, cheap enough to be irrelevant: a `readdir` plus a few
    /// small JSON reads.
    public static let pollInterval: TimeInterval = 0.5

    private let registry: SessionRegistry
    private let engine: TurnAlertEngine
    private var timer: Timer?

    public private(set) var sessions: [LiveSession] = []

    /// Called after every poll with the current live set.
    public var onUpdate: (([LiveSession]) -> Void)?
    /// Called once per raised alert.
    public var onAlert: ((TurnAlert) -> Void)?

    public init(
        registry: SessionRegistry = SessionRegistry(),
        engine: TurnAlertEngine = TurnAlertEngine()
    ) {
        self.registry = registry
        self.engine = engine
    }

    public func start() {
        guard timer == nil else { return }
        tick()
        let timer = Timer(timeInterval: FleetMonitor.pollInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // .common keeps polling alive while the user drags the panel, which
        // would otherwise stall the run loop in event-tracking mode.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    public func isLatched(sessionId: String) -> Bool {
        return engine.isLatched(sessionId: sessionId)
    }

    private func tick() {
        let now = Date()
        let current = registry.poll()
        let alerts = engine.ingest(current, now: now)

        sessions = current
        onUpdate?(current)
        for alert in alerts {
            onAlert?(alert)
        }
    }
}
