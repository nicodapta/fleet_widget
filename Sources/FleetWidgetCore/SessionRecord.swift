import Foundation

/// One `~/.claude/sessions/<pid>.json` record.
///
/// This mirrors the on-disk shape written by Claude Code (observed in 2.1.240).
/// It is an undocumented internal format, so only the three fields the widget
/// genuinely cannot work without are required; everything else is optional and
/// absent fields degrade rather than reject the record.
public struct SessionRecord: Codable, Equatable {
    // Required.
    public let pid: Int32
    public let sessionId: String
    public let cwd: String

    // Optional.
    public let name: String?
    public let nameSource: String?
    public let status: String?
    public let waitingFor: String?
    public let kind: String?
    public let entrypoint: String?
    public let version: String?
    public let messagingSocketPath: String?

    /// Milliseconds since the Unix epoch, written when the session started.
    public let startedAt: Double?
    /// Milliseconds since the Unix epoch, written on any record update.
    public let updatedAt: Double?
    /// Milliseconds since the Unix epoch, written when `status` last changed.
    public let statusUpdatedAt: Double?

    public init(
        pid: Int32,
        sessionId: String,
        cwd: String,
        name: String? = nil,
        nameSource: String? = nil,
        status: String? = nil,
        waitingFor: String? = nil,
        kind: String? = nil,
        entrypoint: String? = nil,
        version: String? = nil,
        messagingSocketPath: String? = nil,
        startedAt: Double? = nil,
        updatedAt: Double? = nil,
        statusUpdatedAt: Double? = nil
    ) {
        self.pid = pid
        self.sessionId = sessionId
        self.cwd = cwd
        self.name = name
        self.nameSource = nameSource
        self.status = status
        self.waitingFor = waitingFor
        self.kind = kind
        self.entrypoint = entrypoint
        self.version = version
        self.messagingSocketPath = messagingSocketPath
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.statusUpdatedAt = statusUpdatedAt
    }

    /// Display label: the derived `name`, falling back to the basename of `cwd`.
    public var displayLabel: String {
        if let name = name {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        let base = (cwd as NSString).lastPathComponent
        return base.isEmpty ? sessionId : base
    }

    /// When `status` last changed, or nil when the field is absent or unusable.
    ///
    /// Deliberately nil rather than "now" or epoch zero: an unavailable timestamp
    /// must render as unknown, never as a plausible-looking duration.
    public var statusChangedAt: Date? {
        return SessionRecord.date(fromMilliseconds: statusUpdatedAt)
    }

    /// When the session started, or nil when unavailable.
    public var startedDate: Date? {
        return SessionRecord.date(fromMilliseconds: startedAt)
    }

    static func date(fromMilliseconds ms: Double?) -> Date? {
        guard let ms = ms, ms.isFinite, ms > 0 else { return nil }
        return Date(timeIntervalSince1970: ms / 1000.0)
    }
}
