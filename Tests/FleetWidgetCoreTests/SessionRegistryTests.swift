import XCTest
@testable import FleetWidgetCore

final class SessionRegistryTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_787_400_000)
    private var ms: Double { return base.timeIntervalSince1970 * 1000 }

    private func makeRegistry(_ dir: FixtureDirectory, _ liveness: FakeLiveness) -> SessionRegistry {
        return SessionRegistry(directory: dir.url, checker: liveness)
    }

    // MARK: - Discovery

    func testHealthyRecordAppears() {
        let dir = FixtureDirectory(); let live = FakeLiveness()
        dir.write(pid: 100, json: recordJSON(pid: 100, sessionId: "s1", status: "busy", startedAtMs: ms))
        live.register(pid: 100, sessionStart: base)

        let sessions = makeRegistry(dir, live).poll()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.sessionId, "s1")
        XCTAssertEqual(sessions.first?.status, .busy)
    }

    func testAbsentDirectoryYieldsEmptySet() {
        let missing = URL(fileURLWithPath: "/nonexistent/fleetwidget/sessions")
        let registry = SessionRegistry(directory: missing, checker: FakeLiveness())
        XCTAssertEqual(registry.poll().count, 0)
    }

    func testRemovedFileDropsSession() {
        let dir = FixtureDirectory(); let live = FakeLiveness()
        dir.write(pid: 100, json: recordJSON(pid: 100, sessionId: "s1", startedAtMs: ms))
        live.register(pid: 100, sessionStart: base)
        let registry = makeRegistry(dir, live)

        XCTAssertEqual(registry.poll().count, 1)
        dir.remove(pid: 100)
        XCTAssertEqual(registry.poll().count, 0)
    }

    // MARK: - Liveness

    func testStaleRecordWithDeadPidExcluded() {
        let dir = FixtureDirectory(); let live = FakeLiveness()
        dir.write(pid: 999, json: recordJSON(pid: 999, sessionId: "dead", startedAtMs: ms))
        // Process is not registered: it crashed and left the file behind.

        XCTAssertEqual(makeRegistry(dir, live).poll().count, 0)
    }

    func testRecycledPidExcluded() {
        let dir = FixtureDirectory(); let live = FakeLiveness()
        dir.write(pid: 100, json: recordJSON(pid: 100, sessionId: "old", startedAtMs: ms))
        // The pid is alive, but the process behind it launched an hour after the
        // record was written, so it is a different process wearing the same pid.
        live.alive.insert(100)
        live.starts[100] = base.addingTimeInterval(3600)

        XCTAssertEqual(makeRegistry(dir, live).poll().count, 0)
    }

    func testUnavailableProcessStartTimeExcluded() {
        let dir = FixtureDirectory(); let live = FakeLiveness()
        dir.write(pid: 100, json: recordJSON(pid: 100, sessionId: "s1", startedAtMs: ms))
        live.alive.insert(100) // alive, but no start time available

        XCTAssertEqual(makeRegistry(dir, live).poll().count, 0)
    }

    func testClockToleranceAbsorbsSmallSkew() {
        let dir = FixtureDirectory(); let live = FakeLiveness()
        dir.write(pid: 100, json: recordJSON(pid: 100, sessionId: "s1", startedAtMs: ms))
        live.alive.insert(100)
        live.starts[100] = base.addingTimeInterval(1.0) // within the 2s tolerance

        XCTAssertEqual(makeRegistry(dir, live).poll().count, 1)
    }

    // MARK: - Malformed input

    func testTruncatedJsonRetainsPreviouslyKnownState() {
        let dir = FixtureDirectory(); let live = FakeLiveness()
        dir.write(pid: 100, json: recordJSON(pid: 100, sessionId: "s1", status: "busy", startedAtMs: ms))
        live.register(pid: 100, sessionStart: base)
        let registry = makeRegistry(dir, live)

        XCTAssertEqual(registry.poll().first?.status, .busy)

        // Caught mid-write.
        dir.write(pid: 100, json: "{\"pid\": 100, \"sessi")
        let afterTruncation = registry.poll()
        XCTAssertEqual(afterTruncation.count, 1, "session should not blink out on a partial read")
        XCTAssertEqual(afterTruncation.first?.status, .busy)
    }

    func testMalformedRecordDoesNotAffectOtherSessions() {
        let dir = FixtureDirectory(); let live = FakeLiveness()
        dir.write(pid: 100, json: "not json at all")
        dir.write(pid: 200, json: recordJSON(pid: 200, sessionId: "good", startedAtMs: ms))
        live.register(pid: 100, sessionStart: base)
        live.register(pid: 200, sessionStart: base)

        let sessions = makeRegistry(dir, live).poll()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.sessionId, "good")
    }

    func testMissingRequiredFieldsSkipped() {
        let dir = FixtureDirectory(); let live = FakeLiveness()
        // Valid JSON, but no cwd.
        dir.write(pid: 100, json: "{\"pid\": 100, \"sessionId\": \"s1\", \"startedAt\": \(ms)}")
        live.register(pid: 100, sessionStart: base)

        XCTAssertEqual(makeRegistry(dir, live).poll().count, 0)
    }

    // MARK: - Normalization

    func testUnknownStatusValueNormalizes() {
        let dir = FixtureDirectory(); let live = FakeLiveness()
        dir.write(pid: 100, json: recordJSON(pid: 100, sessionId: "s1", status: "hyperdrive", startedAtMs: ms))
        live.register(pid: 100, sessionStart: base)

        let sessions = makeRegistry(dir, live).poll()
        XCTAssertEqual(sessions.first?.status, .unknown)
        XCTAssertFalse(sessions.first!.status.isAlertable)
    }

    func testAbsentStatusNormalizesToUnknown() {
        let dir = FixtureDirectory(); let live = FakeLiveness()
        dir.write(pid: 100, json: recordJSON(pid: 100, sessionId: "s1", status: nil, startedAtMs: ms))
        live.register(pid: 100, sessionStart: base)

        XCTAssertEqual(makeRegistry(dir, live).poll().first?.status, .unknown)
    }

    func testAllKnownStatusesRoundTrip() {
        for status in ["busy", "idle", "waiting", "shell"] {
            XCTAssertEqual(SessionStatus(raw: status).rawValue, status)
        }
    }

    // MARK: - Display identity

    func testDisplayLabelUsesName() {
        let dir = FixtureDirectory(); let live = FakeLiveness()
        dir.write(pid: 100, json: recordJSON(
            pid: 100, sessionId: "s1", name: "claude-widget-43", startedAtMs: ms))
        live.register(pid: 100, sessionStart: base)

        XCTAssertEqual(makeRegistry(dir, live).poll().first?.label, "claude-widget-43")
    }

    func testDisplayLabelFallsBackToCwdBasename() {
        let dir = FixtureDirectory(); let live = FakeLiveness()
        dir.write(pid: 100, json: recordJSON(
            pid: 100, sessionId: "s1", cwd: "/Users/x/Dev/invoice_sync", name: nil, startedAtMs: ms))
        live.register(pid: 100, sessionStart: base)

        XCTAssertEqual(makeRegistry(dir, live).poll().first?.label, "invoice_sync")
    }

    // MARK: - Elapsed time

    func testElapsedDerivedFromStatusUpdatedAt() {
        let changed = base.addingTimeInterval(-42)
        let dir = FixtureDirectory(); let live = FakeLiveness()
        dir.write(pid: 100, json: recordJSON(
            pid: 100, sessionId: "s1", status: "busy",
            startedAtMs: ms, statusUpdatedAtMs: changed.timeIntervalSince1970 * 1000))
        live.register(pid: 100, sessionStart: base)

        let session = makeRegistry(dir, live).poll().first
        XCTAssertEqual(session?.elapsedInStatus(at: base) ?? -1, 42, accuracy: 0.01)
    }

    func testElapsedUnavailableRatherThanZero() {
        let dir = FixtureDirectory(); let live = FakeLiveness()
        dir.write(pid: 100, json: recordJSON(
            pid: 100, sessionId: "s1", startedAtMs: ms, statusUpdatedAtMs: nil))
        live.register(pid: 100, sessionStart: base)

        XCTAssertNil(makeRegistry(dir, live).poll().first?.elapsedInStatus(at: base))
    }

    // MARK: - Ordering

    func testOrderingIsStableAcrossStatusChanges() {
        let dir = FixtureDirectory(); let live = FakeLiveness()
        // Written out of order; expected order is by session start time.
        dir.write(pid: 300, json: recordJSON(pid: 300, sessionId: "third", status: "idle", startedAtMs: ms + 2000))
        dir.write(pid: 100, json: recordJSON(pid: 100, sessionId: "first", status: "idle", startedAtMs: ms))
        dir.write(pid: 200, json: recordJSON(pid: 200, sessionId: "second", status: "idle", startedAtMs: ms + 1000))
        live.register(pid: 100, sessionStart: base)
        live.register(pid: 200, sessionStart: base)
        live.register(pid: 300, sessionStart: base)
        let registry = makeRegistry(dir, live)

        XCTAssertEqual(registry.poll().map { $0.sessionId }, ["first", "second", "third"])

        // The middle session changes status; its position must not move.
        dir.write(pid: 200, json: recordJSON(pid: 200, sessionId: "second", status: "waiting", startedAtMs: ms + 1000))
        XCTAssertEqual(registry.poll().map { $0.sessionId }, ["first", "second", "third"])
    }
}
