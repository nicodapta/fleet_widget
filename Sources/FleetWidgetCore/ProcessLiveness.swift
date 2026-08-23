import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Queries the OS about a process. Injectable so registry logic can be tested
/// without real processes.
public protocol ProcessLivenessChecking {
    /// Whether a process with this pid currently exists.
    func isAlive(pid: Int32) -> Bool
    /// When the process was launched, or nil if that cannot be determined.
    func startTime(pid: Int32) -> Date?
}

/// Real implementation backed by `kill(pid, 0)` and `sysctl(KERN_PROC_PID)`.
public struct SystemProcessLiveness: ProcessLivenessChecking {
    public init() {}

    public func isAlive(pid: Int32) -> Bool {
        guard pid > 0 else { return false }
        if kill(pid, 0) == 0 { return true }
        // EPERM means the process exists but belongs to another user, which
        // still counts as alive. ESRCH means no such process.
        return errno == EPERM
    }

    public func startTime(pid: Int32) -> Date? {
        guard pid > 0 else { return nil }
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride

        let result = sysctl(&mib, u_int(mib.count), &info, &size, nil, 0)
        // A vanished process yields rc == 0 with size == 0, so size must be checked.
        guard result == 0, size > 0 else { return nil }

        let started = info.kp_proc.p_starttime
        let seconds = Double(started.tv_sec) + Double(started.tv_usec) / 1_000_000.0
        guard seconds > 0 else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }
}

/// Decides whether a registry record describes a genuinely live session.
///
/// File presence alone is not evidence: a crashed session leaves its record
/// behind indefinitely. Checking the pid handles that, but macOS recycles pids,
/// so a stale record can also collide with an unrelated new process. Comparing
/// the record's `startedAt` against the process's real launch time rejects that
/// case — a session cannot have started before the process hosting it did.
public struct SessionLiveness {
    /// Absorbs clock granularity between the two timestamps. The record is
    /// written shortly *after* the process launches, so in a healthy session the
    /// process start time always precedes `startedAt`.
    public static let clockTolerance: TimeInterval = 2.0

    private let checker: ProcessLivenessChecking

    public init(checker: ProcessLivenessChecking = SystemProcessLiveness()) {
        self.checker = checker
    }

    public func isLive(_ record: SessionRecord) -> Bool {
        guard checker.isAlive(pid: record.pid) else { return false }

        // Both timestamps are required to rule out pid reuse. When either is
        // missing the check cannot be made, and an unverifiable record is
        // excluded rather than trusted — a stale record must never be able to
        // masquerade as live by omitting a field.
        guard let processStart = checker.startTime(pid: record.pid) else { return false }
        guard let sessionStart = record.startedDate else { return false }

        if processStart.timeIntervalSince(sessionStart) > SessionLiveness.clockTolerance {
            return false // pid now belongs to a process launched after this record
        }
        return true
    }
}
