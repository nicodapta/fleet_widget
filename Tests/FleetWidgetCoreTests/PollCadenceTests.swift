import XCTest
@testable import FleetWidgetCore

final class PollCadenceTests: XCTestCase {
    /// Regression: replays a real live sequence: baseline busy, a sub-debounce waiting
    /// flicker, then a held busy -> idle, sampled at the real 0.5s poll cadence.
    func testLiveSequenceProducesDoneAndLatches() {
        let engine = TurnAlertEngine()
        let t0 = Date(timeIntervalSince1970: 1_787_400_000)
        func feed(_ status: SessionStatus, _ offset: TimeInterval) -> [TurnAlert] {
            return engine.ingest(
                [LiveSession(pid: 1, sessionId: "f1", label: "fixture", cwd: "/tmp",
                             status: status, waitingFor: nil,
                             statusChangedAt: t0, startedAt: t0)],
                now: t0.addingTimeInterval(offset))
        }

        var fired: [TurnAlert] = []
        // busy baseline
        fired += feed(.busy, 0.0)
        fired += feed(.busy, 0.5)
        // flicker
        fired += feed(.waiting, 1.0)
        fired += feed(.busy, 1.5)
        fired += feed(.busy, 2.0)
        XCTAssertTrue(fired.isEmpty, "flicker must not alert")
        // held idle
        fired += feed(.idle, 4.0)
        fired += feed(.idle, 4.5)
        fired += feed(.idle, 5.0)
        fired += feed(.idle, 5.5)

        XCTAssertEqual(fired.map { $0.kind }, [.done])
        XCTAssertTrue(engine.isLatched(sessionId: "f1"), "done must latch")
    }
}
