import AppKit

/// A pixel-art starburst in the spirit of Claude's mark, drawn in the same
/// string-bitmap idiom as the session sprites so the widget reads as one piece.
enum ClaudeMark {
    /// 7x7. Sized for the panel header, where a taller mark would crowd the bar.
    static let compact: [String] = [
        "...#...",
        ".#.#.#.",
        "..###..",
        "#######",
        "..###..",
        ".#.#.#.",
        "...#...",
    ]

    /// 11x11. Full-length diagonals, for the app icon where there is room for them.
    static let full: [String] = [
        ".....#.....",
        ".#...#...#.",
        "..#..#..#..",
        "...#.#.#...",
        "....###....",
        "###########",
        "....###....",
        "...#.#.#...",
        "..#..#..#..",
        ".#...#...#.",
        ".....#.....",
    ]

    static let palette = SpritePalette(
        body: SpritePalette.claudeOrange,
        feature: SpritePalette.claudeOrange,
        accent: SpritePalette.claudeOrange)

    /// Tinted variant, so the header mark can follow the fleet's urgency colour.
    static func palette(tinted color: NSColor) -> SpritePalette {
        return SpritePalette(body: color, feature: color, accent: color)
    }
}
