import Foundation

/// Why a session needs the user.
///
/// Both kinds mean the same thing from the user's chair — go look at this
/// terminal — so they share one detection path, one debounce and one latch.
/// They differ only in presentation, because a blocked session is making no
/// progress while a finished one is merely idle.
public enum TurnAlertKind: Equatable {
    /// `busy -> idle`: the session finished its turn.
    case done
    /// `* -> waiting`: the session is blocked on the user.
    case blocked
}

public struct TurnAlert: Equatable {
    public let sessionId: String
    public let label: String
    public let kind: TurnAlertKind
    /// For `.blocked`, the record's `waitingFor` text.
    public let reason: String?

    public init(sessionId: String, label: String, kind: TurnAlertKind, reason: String?) {
        self.sessionId = sessionId
        self.label = label
        self.kind = kind
        self.reason = reason
    }
}
