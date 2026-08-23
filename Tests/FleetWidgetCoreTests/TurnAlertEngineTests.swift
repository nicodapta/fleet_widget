import XCTest
@testable import FleetWidgetCore

final class TurnAlertEngineTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_787_400_000)
    private var engine = TurnAlertEngine()

    override func setUp() {
        super.setUp()
        engine = TurnAlertEngine()
    }

    /// Feeds a status and lets it clear the debounce window, returning any alerts.
    /// Two ingests are needed because a status must hold to become real.
    @discardableResult
    private func settle(
        _ status: SessionStatus,
        at offset: TimeInterval,
        id: String = "s1",
        waitingFor: String? = nil
    ) -> [TurnAlert] {
        let snapshot = [session(id, status: status, waitingFor: waitingFor)]
        _ = engine.ingest(snapshot, now: t0.addingTimeInterval(offset))
        return engine.ingest(snapshot, now: t0.addingTimeInterval(offset + 1.0))
    }

    // MARK: - Baseline

    func testFirstTickIsSilent() {
        let alerts = engine.ingest([
            session("a", status: .idle),
            session("b", status: .idle),
            session("c", status: .idle),
        ], now: t0)
        XCTAssertTrue(alerts.isEmpty, "pre-existing statuses at launch must not alert")
    }

    func testTransitionAfterBaselineStillAlerts() {
        _ = engine.ingest([session("s1", status: .busy)], now: t0)
        XCTAssertEqual(settle(.idle, at: 1).first?.kind, .done)
    }

    func testSessionAppearingMidRunIsSilent() {
        _ = engine.ingest([session("s1", status: .busy)], now: t0)
        // A terminal launched later shows up already idle; there is no transition.
        let alerts = engine.ingest([
            session("s1", status: .busy),
            session("new", status: .idle),
        ], now: t0.addingTimeInterval(5))
        XCTAssertTrue(alerts.isEmpty)
    }

    // MARK: - The two alerting transitions

    func testBusyToIdleRaisesDone() {
        _ = engine.ingest([session("s1", status: .busy)], now: t0)
        let alerts = settle(.idle, at: 1)
        XCTAssertEqual(alerts.count, 1)
        XCTAssertEqual(alerts.first?.kind, .done)
        XCTAssertNil(alerts.first?.reason)
    }

    func testBusyToWaitingRaisesBlockedWithReason() {
        _ = engine.ingest([session("s1", status: .busy)], now: t0)
        let alerts = settle(.waiting, at: 1, waitingFor: "input needed")
        XCTAssertEqual(alerts.count, 1)
        XCTAssertEqual(alerts.first?.kind, .blocked)
        XCTAssertEqual(alerts.first?.reason, "input needed")
    }

    func testIdleToWaitingAlsoRaisesBlocked() {
        _ = engine.ingest([session("s1", status: .idle)], now: t0)
        XCTAssertEqual(settle(.waiting, at: 1, waitingFor: "sandbox request").first?.kind, .blocked)
    }

    func testBlockedThenDoneWithinOneTurn() {
        _ = engine.ingest([session("s1", status: .busy)], now: t0)

        let blocked = settle(.waiting, at: 1, waitingFor: "dialog open")
        XCTAssertEqual(blocked.map { $0.kind }, [.blocked])

        // The user answers; work resumes.
        XCTAssertTrue(settle(.busy, at: 5).isEmpty)

        // Then it finishes. The user's attention was genuinely needed twice.
        XCTAssertEqual(settle(.idle, at: 10).map { $0.kind }, [.done])
    }

    // MARK: - Silent transitions

    func testIdleToBusyIsSilent() {
        _ = engine.ingest([session("s1", status: .idle)], now: t0)
        XCTAssertTrue(settle(.busy, at: 1).isEmpty, "the user just submitted this prompt")
    }

    func testTransitionIntoShellIsSilent() {
        _ = engine.ingest([session("s1", status: .idle)], now: t0)
        XCTAssertTrue(settle(.shell, at: 1).isEmpty)
    }

    func testShellToIdleIsSilent() {
        _ = engine.ingest([session("s1", status: .shell)], now: t0)
        XCTAssertTrue(settle(.idle, at: 1).isEmpty, "shell already meant the turn was over")
    }

    func testTransitionsInvolvingUnknownAreSilent() {
        _ = engine.ingest([session("s1", status: .busy)], now: t0)
        XCTAssertTrue(settle(.unknown, at: 1).isEmpty, "busy -> unknown must not alert")
        XCTAssertTrue(settle(.idle, at: 5).isEmpty, "unknown -> idle must not alert")
    }

    // MARK: - Debounce

    func testSubDebounceFlickerRaisesNothing() {
        _ = engine.ingest([session("s1", status: .busy)], now: t0)

        // A local slash-command dialog opens and closes inside the window.
        _ = engine.ingest([session("s1", status: .waiting)], now: t0.addingTimeInterval(0.1))
        let back = engine.ingest([session("s1", status: .busy)], now: t0.addingTimeInterval(0.5))
        XCTAssertTrue(back.isEmpty)

        let later = engine.ingest([session("s1", status: .busy)], now: t0.addingTimeInterval(3))
        XCTAssertTrue(later.isEmpty, "the flicker must not alert after the fact either")
    }

    func testStatusHeldBeyondDebounceAlerts() {
        _ = engine.ingest([session("s1", status: .busy)], now: t0)
        let tooSoon = engine.ingest([session("s1", status: .waiting)], now: t0.addingTimeInterval(0.1))
        XCTAssertTrue(tooSoon.isEmpty)

        let held = engine.ingest([session("s1", status: .waiting)],
                                 now: t0.addingTimeInterval(0.1 + TurnAlertEngine.debounceInterval))
        XCTAssertEqual(held.map { $0.kind }, [.blocked])
    }

    // MARK: - Latching

    func testLongIdleDoesNotRepeat() {
        _ = engine.ingest([session("s1", status: .busy)], now: t0)
        XCTAssertEqual(settle(.idle, at: 1).count, 1)

        for minute in 1...10 {
            let alerts = engine.ingest([session("s1", status: .idle)],
                                       now: t0.addingTimeInterval(Double(minute) * 60))
            XCTAssertTrue(alerts.isEmpty, "idle must alert once, not once per tick")
        }
        XCTAssertTrue(engine.isLatched(sessionId: "s1"))
    }

    func testReAlertAfterSessionIsUsedAgain() {
        _ = engine.ingest([session("s1", status: .busy)], now: t0)
        XCTAssertEqual(settle(.idle, at: 1).count, 1)

        XCTAssertTrue(settle(.busy, at: 10).isEmpty)
        XCTAssertFalse(engine.isLatched(sessionId: "s1"), "leaving idle re-arms the session")

        XCTAssertEqual(settle(.idle, at: 20).map { $0.kind }, [.done])
    }

    // MARK: - Lifecycle

    func testDisappearedSessionIsForgotten() {
        _ = engine.ingest([session("s1", status: .busy)], now: t0)
        _ = engine.ingest([], now: t0.addingTimeInterval(1))

        // Same id comes back idle. With no retained state this is a new session,
        // so it records silently rather than firing a spurious "done".
        let alerts = engine.ingest([session("s1", status: .idle)], now: t0.addingTimeInterval(2))
        XCTAssertTrue(alerts.isEmpty)
    }

    func testConcurrentSessionsAlertIndependently() {
        _ = engine.ingest([
            session("a", status: .busy),
            session("b", status: .busy),
        ], now: t0)

        let snapshot = [
            session("a", status: .idle),
            session("b", status: .busy),
        ]
        _ = engine.ingest(snapshot, now: t0.addingTimeInterval(1))
        let alerts = engine.ingest(snapshot, now: t0.addingTimeInterval(2))

        XCTAssertEqual(alerts.count, 1)
        XCTAssertEqual(alerts.first?.sessionId, "a")
    }
}
