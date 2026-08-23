import Foundation

/// The status a Claude Code session reports in its registry file.
///
/// Only four values have been observed (Claude Code 2.1.240): `busy`, `shell`,
/// `idle` and `waiting`.
///
/// `waiting` takes priority over `busy` at the source, so a session blocked on a
/// dialog mid-turn reports `waiting`, not `busy`.
///
/// `shell` is a refinement of `idle`, not of `busy` — the model's turn is over
/// while a background command still runs. It does not need the user.
public enum SessionStatus: String, Equatable, CaseIterable {
    case busy
    case idle
    case waiting
    case shell

    /// A status this build does not recognize. The enum above is closed today but
    /// is an internal detail of Claude Code that may grow. Mapping unfamiliar
    /// values here means a future release degrades to a visibly odd row rather
    /// than to spurious alerts or a session that silently vanishes.
    case unknown

    /// Normalizes a raw registry value. Absent or unrecognized becomes `.unknown`.
    public init(raw: String?) {
        guard let raw = raw, let known = SessionStatus(rawValue: raw), known != .unknown else {
            self = .unknown
            return
        }
        self = known
    }

    /// Whether transitions involving this status may raise alerts.
    ///
    /// `unknown` is excluded so that an unrecognized future status cannot
    /// manufacture a false "your turn".
    public var isAlertable: Bool {
        return self != .unknown
    }
}
