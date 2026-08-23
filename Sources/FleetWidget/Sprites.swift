import AppKit
import FleetWidgetCore

/// Pixel-art sprites, authored as string-literal bitmaps.
///
/// There is deliberately no asset pipeline. Each frame is an 8x8 grid of
/// characters rendered as a grid of filled rects, which keeps the art diffable
/// in git, editable in the same file as the logic, and hard-edged at any scale.
///
///   `.` transparent   `#` body   `o` feature (eyes, mouth)   `*` accent
enum Sprite {
    static let side = 8

    // A small ghost-like creature: rounded top, eyes on row 3, a skirt on row 7
    // that alternates to suggest hovering. Deliberately no mouth and no legs —
    // at 8x8 a dark mouth above two prongs reads as a skull, not a character.

    private static let skirtA = "#.#..#.#"
    private static let skirtB = ".#.##.#."

    private static func body(eyes: String, skirt: String) -> [String] {
        return [
            "..####..",
            ".######.",
            "########",
            eyes,
            "########",
            "########",
            "########",
            skirt,
        ]
    }

    private static let eyesCentre = "##o##o##"
    private static let eyesLeft   = "#o##o###"
    private static let eyesRight  = "###o##o#"
    private static let eyesWide   = "#oo##oo#"
    private static let eyesClosed = "########"

    /// Working: eyes scan left and right while the skirt ripples.
    static let busy: [[String]] = [
        body(eyes: eyesCentre, skirt: skirtA),
        body(eyes: eyesLeft,   skirt: skirtB),
        body(eyes: eyesCentre, skirt: skirtA),
        body(eyes: eyesRight,  skirt: skirtB),
    ]

    /// Blocked on the user: wide eyes. The vertical bounce is applied by the
    /// renderer rather than baked into the frames.
    static let waiting: [[String]] = [
        body(eyes: eyesWide, skirt: skirtA),
        body(eyes: eyesWide, skirt: skirtB),
    ]

    /// Parked: still, with an occasional slow blink. The long run of identical
    /// frames is what makes the blink infrequent rather than a flutter.
    static let idle: [[String]] = {
        var frames = [[String]](repeating: body(eyes: eyesCentre, skirt: skirtA), count: 11)
        frames.append(body(eyes: eyesClosed, skirt: skirtA))
        return frames
    }()

    /// Finished and waiting to be noticed: mostly still, but every few seconds it
    /// glances left and right before blinking. The long centre hold is what makes
    /// the glance read as occasional rather than as constant fidgeting.
    static let done: [[String]] = {
        var frames: [[String]] = []
        func hold(_ eyes: String, _ count: Int) {
            frames.append(contentsOf: [[String]](repeating: body(eyes: eyes, skirt: skirtA), count: count))
        }
        hold(eyesCentre, 18)
        hold(eyesLeft, 3)
        hold(eyesCentre, 2)
        hold(eyesRight, 3)
        hold(eyesCentre, 2)
        hold(eyesClosed, 1)
        return frames
    }()

    /// Turn is over, a background command is still running.
    static let shell: [[String]] = [
        body(eyes: eyesCentre, skirt: skirtA),
    ]

    /// A status this build does not recognize.
    static let unknown: [[String]] = [
        ["..####..",
         ".##..##.",
         "....##..",
         "...##...",
         "...##...",
         "...##...",
         "........",
         "...##..."],
    ]

    static func frames(for appearance: SessionAppearance) -> [[String]] {
        switch appearance {
        case .busy:    return busy
        case .blocked: return waiting
        case .done:    return done
        case .idle:    return idle
        case .shell:   return shell
        case .unknown: return unknown
        }
    }
}

/// Colors for each status. Body, feature and accent are keyed to the sprite's
/// `#`, `o` and `*` characters.
struct SpritePalette {
    let body: NSColor
    let feature: NSColor
    let accent: NSColor

    func color(for character: Character) -> NSColor? {
        switch character {
        case "#": return body
        case "o": return feature
        case "*": return accent
        default:  return nil
        }
    }

    /// Claude's orange. Reserved for the finished state so that "this one is done
    /// and you have not come back to it" is recognisable at a glance.
    static let claudeOrange = NSColor(srgbRed: 0.851, green: 0.467, blue: 0.341, alpha: 1)

    static func palette(for appearance: SessionAppearance) -> SpritePalette {
        switch appearance {
        case .done:
            return SpritePalette(
                body: claudeOrange,
                feature: NSColor(srgbRed: 0.16, green: 0.07, blue: 0.05, alpha: 1),
                accent: NSColor(srgbRed: 0.95, green: 0.62, blue: 0.48, alpha: 1))
        case .busy:
            return SpritePalette(
                body: NSColor(srgbRed: 0.35, green: 0.85, blue: 0.75, alpha: 1),
                feature: NSColor(srgbRed: 0.04, green: 0.14, blue: 0.16, alpha: 1),
                accent: NSColor(srgbRed: 0.95, green: 0.95, blue: 0.55, alpha: 1))
        case .blocked:
            return SpritePalette(
                body: NSColor(srgbRed: 1.00, green: 0.72, blue: 0.25, alpha: 1),
                feature: NSColor(srgbRed: 0.22, green: 0.08, blue: 0.00, alpha: 1),
                accent: NSColor(srgbRed: 1.00, green: 0.35, blue: 0.30, alpha: 1))
        case .idle:
            return SpritePalette(
                body: NSColor(srgbRed: 0.45, green: 0.48, blue: 0.55, alpha: 1),
                feature: NSColor(srgbRed: 0.13, green: 0.14, blue: 0.17, alpha: 1),
                accent: NSColor(srgbRed: 0.45, green: 0.48, blue: 0.55, alpha: 1))
        case .shell:
            return SpritePalette(
                body: NSColor(srgbRed: 0.55, green: 0.68, blue: 0.90, alpha: 1),
                feature: NSColor(srgbRed: 0.08, green: 0.12, blue: 0.20, alpha: 1),
                accent: NSColor(srgbRed: 0.55, green: 0.68, blue: 0.90, alpha: 1))
        case .unknown:
            return SpritePalette(
                body: NSColor(srgbRed: 0.62, green: 0.55, blue: 0.78, alpha: 1),
                feature: NSColor(srgbRed: 0.15, green: 0.13, blue: 0.20, alpha: 1),
                accent: NSColor(srgbRed: 0.62, green: 0.55, blue: 0.78, alpha: 1))
        }
    }
}
