import Foundation

/// A Claude Code session confirmed live at poll time, normalized for display.
public struct LiveSession: Equatable {
    public let pid: Int32
    public let sessionId: String
    public let label: String
    public let cwd: String
    public let status: SessionStatus
    /// Why the session is blocked, when `status == .waiting`.
    ///
    /// Claude Code's vocabulary (2.1.240): "sandbox request", "input needed",
    /// "worker request", "dialog open", or the text of the topmost dialog.
    public let waitingFor: String?
    public let statusChangedAt: Date?
    public let startedAt: Date?

    public init(
        pid: Int32,
        sessionId: String,
        label: String,
        cwd: String,
        status: SessionStatus,
        waitingFor: String?,
        statusChangedAt: Date?,
        startedAt: Date?
    ) {
        self.pid = pid
        self.sessionId = sessionId
        self.label = label
        self.cwd = cwd
        self.status = status
        self.waitingFor = waitingFor
        self.statusChangedAt = statusChangedAt
        self.startedAt = startedAt
    }

    public init(record: SessionRecord) {
        self.init(
            pid: record.pid,
            sessionId: record.sessionId,
            label: record.displayLabel,
            cwd: record.cwd,
            status: SessionStatus(raw: record.status),
            waitingFor: record.waitingFor,
            statusChangedAt: record.statusChangedAt,
            startedAt: record.startedDate
        )
    }

    /// Seconds spent in the current status, or nil when the source timestamp is
    /// unavailable. Never reports zero to stand in for "unknown".
    public func elapsedInStatus(at now: Date) -> TimeInterval? {
        guard let changed = statusChangedAt else { return nil }
        let elapsed = now.timeIntervalSince(changed)
        return elapsed < 0 ? 0 : elapsed
    }
}
