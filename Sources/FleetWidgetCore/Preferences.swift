import Foundation
import CoreGraphics

/// Small persisted settings. Backed by `UserDefaults` so they survive relaunch.
public final class Preferences {
    private enum Key {
        static let muted = "fleetwidget.muted"
        static let originX = "fleetwidget.panelOriginX"
        static let originY = "fleetwidget.panelOriginY"
        static let hasOrigin = "fleetwidget.panelOriginSet"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Suppresses alert sound. Visual alerting is unaffected.
    public var isMuted: Bool {
        get { return defaults.bool(forKey: Key.muted) }
        set { defaults.set(newValue, forKey: Key.muted) }
    }

    /// Last panel position in screen coordinates, or nil if never moved.
    public var panelOrigin: CGPoint? {
        get {
            guard defaults.bool(forKey: Key.hasOrigin) else { return nil }
            return CGPoint(
                x: defaults.double(forKey: Key.originX),
                y: defaults.double(forKey: Key.originY)
            )
        }
        set {
            guard let point = newValue else {
                defaults.set(false, forKey: Key.hasOrigin)
                return
            }
            defaults.set(Double(point.x), forKey: Key.originX)
            defaults.set(Double(point.y), forKey: Key.originY)
            defaults.set(true, forKey: Key.hasOrigin)
        }
    }
}
