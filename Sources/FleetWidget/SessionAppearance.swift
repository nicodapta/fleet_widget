import Foundation
import FleetWidgetCore

/// How a row presents itself.
///
/// This is presentation state, not registry state: `done` is not a status Claude
/// Code reports, it is an idle session that has alerted and that the user has not
/// returned to yet. Deriving it once here keeps sprite, palette, caption and
/// prominence from each re-deciding what "done" means.
enum SessionAppearance {
    case busy
    case blocked
    case done
    case idle
    case shell
    case unknown

    init(status: SessionStatus, isLatched: Bool) {
        switch status {
        case .waiting: self = .blocked
        case .busy:    self = .busy
        case .idle:    self = isLatched ? .done : .idle
        case .shell:   self = .shell
        case .unknown: self = .unknown
        }
    }

    /// Both "your turn" states sit at full prominence.
    var needsUser: Bool {
        return self == .blocked || self == .done
    }
}
