import Foundation
import XCTest
@testable import FleetWidgetCore

/// Injectable stand-in for the OS process table.
final class FakeLiveness: ProcessLivenessChecking {
    var alive: Set<Int32> = []
    var starts: [Int32: Date] = [:]

    func isAlive(pid: Int32) -> Bool { return alive.contains(pid) }
    func startTime(pid: Int32) -> Date? { return starts[pid] }

    /// Registers a healthy process: alive, launched just before its session.
    func register(pid: Int32, sessionStart: Date) {
        alive.insert(pid)
        starts[pid] = sessionStart.addingTimeInterval(-0.2)
    }
}

/// Creates and cleans up a throwaway registry directory.
final class FixtureDirectory {
    let url: URL

    init() {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("fleetwidget-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    func write(pid: Int32, json: String) {
        let file = url.appendingPathComponent("\(pid).json")
        try? json.data(using: .utf8)?.write(to: file)
    }

    func remove(pid: Int32) {
        try? FileManager.default.removeItem(at: url.appendingPathComponent("\(pid).json"))
    }
}

/// A well-formed record matching the shape Claude Code writes.
func recordJSON(
    pid: Int32,
    sessionId: String,
    cwd: String = "/Users/x/Dev/project",
    name: String? = "project-a1",
    status: String? = "idle",
    waitingFor: String? = nil,
    startedAtMs: Double,
    statusUpdatedAtMs: Double? = nil
) -> String {
    var fields: [String] = [
        "\"pid\": \(pid)",
        "\"sessionId\": \"\(sessionId)\"",
        "\"cwd\": \"\(cwd)\"",
        "\"startedAt\": \(startedAtMs)",
    ]
    if let name = name { fields.append("\"name\": \"\(name)\"") }
    if let status = status { fields.append("\"status\": \"\(status)\"") }
    if let waitingFor = waitingFor { fields.append("\"waitingFor\": \"\(waitingFor)\"") }
    if let s = statusUpdatedAtMs { fields.append("\"statusUpdatedAt\": \(s)") }
    return "{\n  " + fields.joined(separator: ",\n  ") + "\n}"
}

/// Builds a `LiveSession` directly, for alert-engine tests that do not need disk.
func session(
    _ id: String,
    status: SessionStatus,
    label: String = "sess",
    waitingFor: String? = nil
) -> LiveSession {
    return LiveSession(
        pid: 1,
        sessionId: id,
        label: label,
        cwd: "/tmp",
        status: status,
        waitingFor: waitingFor,
        statusChangedAt: nil,
        startedAt: nil
    )
}
