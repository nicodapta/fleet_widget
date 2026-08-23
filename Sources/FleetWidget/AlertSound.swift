import AppKit
import FleetWidgetCore

/// Plays the your-turn sound, respecting the persisted mute setting.
///
/// Deliberately quiet system sounds rather than an assertive alert: the widget
/// cannot tell whether the user is already looking at the terminal that fired,
/// so a soft cue is the safer default.
final class AlertSound {
    private let preferences: Preferences
    private var cache: [String: NSSound] = [:]

    init(preferences: Preferences) {
        self.preferences = preferences
    }

    func play(for kind: TurnAlertKind) {
        guard !preferences.isMuted else { return }

        let name = (kind == .blocked) ? "Submarine" : "Tink"
        if let cached = cache[name] {
            cached.stop()
            cached.play()
            return
        }
        if let sound = NSSound(named: NSSound.Name(name)) {
            cache[name] = sound
            sound.play()
        } else {
            NSSound.beep()
        }
    }
}
