import Foundation

/// Turns a stream of polled session snapshots into your-turn alerts.
///
/// Alerting is defined purely on *transitions* of a session's status, with three
/// guards layered on top: a debounce so transient states do not alert, a startup
/// baseline so pre-existing states do not alert, and a latch so a held state does
/// not re-alert.
public final class TurnAlertEngine {
    /// How long a status must hold before it can alert.
    ///
    /// Opening any local slash-command UI momentarily reports as `waiting`, so a
    /// menu the user dismisses at once looks like a block. Requiring the
    /// status to persist removes that false positive along with any other
    /// flicker, at a latency cost well under human reaction time.
    public static let debounceInterval: TimeInterval = 0.75

    private struct Tracked {
        var confirmed: SessionStatus
        var candidate: SessionStatus?
        var candidateSince: Date?
    }

    private var tracked: [String: Tracked] = [:]
    /// Sessions that have already alerted for their current confirmed status.
    private var latched: Set<String> = []
    private var hasBaseline = false

    public init() {}

    /// Feeds one poll result in and returns any alerts it produced.
    public func ingest(_ sessions: [LiveSession], now: Date) -> [TurnAlert] {
        var alerts: [TurnAlert] = []
        var present = Set<String>()

        for session in sessions {
            present.insert(session.sessionId)

            guard var state = tracked[session.sessionId] else {
                // First sighting of this session. There is no prior state to have
                // transitioned from, so it is recorded silently — whether that is
                // the startup baseline or a terminal launched later.
                tracked[session.sessionId] = Tracked(
                    confirmed: session.status, candidate: nil, candidateSince: nil
                )
                continue
            }

            if session.status == state.confirmed {
                // Returned to the confirmed status: any pending change was flicker.
                state.candidate = nil
                state.candidateSince = nil
                tracked[session.sessionId] = state
                continue
            }

            if state.candidate != session.status {
                // A different pending status: restart the debounce window.
                state.candidate = session.status
                state.candidateSince = now
                tracked[session.sessionId] = state
                continue
            }

            guard let since = state.candidateSince,
                  now.timeIntervalSince(since) >= TurnAlertEngine.debounceInterval else {
                tracked[session.sessionId] = state
                continue
            }

            // The new status has held long enough to be real.
            let previous = state.confirmed
            state.confirmed = session.status
            state.candidate = nil
            state.candidateSince = nil
            tracked[session.sessionId] = state

            // Leaving a status re-arms the session for its next alert.
            latched.remove(session.sessionId)

            if let alert = TurnAlertEngine.classify(from: previous, to: session.status, session: session) {
                latched.insert(session.sessionId)
                alerts.append(alert)
            }
        }

        // Forget sessions that are gone, so a restart is treated as new.
        for id in tracked.keys where !present.contains(id) {
            tracked.removeValue(forKey: id)
            latched.remove(id)
        }

        if !hasBaseline {
            // The first tick establishes the baseline only. Without this, launching
            // the widget would chime once per already-idle session — the normal case.
            hasBaseline = true
            return []
        }
        return alerts
    }

    /// The transition table. Everything not named here is silent.
    static func classify(from: SessionStatus, to: SessionStatus, session: LiveSession) -> TurnAlert? {
        // An unrecognized status on either side cannot manufacture an alert.
        guard from.isAlertable, to.isAlertable else { return nil }

        if to == .waiting {
            // Any status -> waiting. The session is blocked on the user.
            return TurnAlert(
                sessionId: session.sessionId, label: session.label,
                kind: .blocked, reason: session.waitingFor
            )
        }
        if to == .idle && from == .busy {
            // The turn completed. Note `shell -> idle` is deliberately excluded:
            // shell already meant the turn was over.
            return TurnAlert(
                sessionId: session.sessionId, label: session.label,
                kind: .done, reason: nil
            )
        }
        // idle -> busy, anything -> shell, and every other pair: silent.
        return nil
    }

    /// Whether a session is currently latched, i.e. has already alerted for the
    /// status it is in. Exposed so the UI can hold an attention state.
    public func isLatched(sessionId: String) -> Bool {
        return latched.contains(sessionId)
    }
}
