import AppKit

/// Draws a string-literal bitmap as a grid of filled rects.
///
/// Rects rather than a scaled bitmap image: pixels stay hard-edged at any size
/// with no interpolation or antialiasing to disable, and there is no
/// intermediate image allocated per frame.
///
/// `origin` is the sprite's **top-left** corner, and the caller is expected to be
/// drawing in a top-down (flipped) coordinate space, as `FleetContentView` is.
enum PixelRenderer {
    static func draw(
        bitmap: [String],
        topLeft origin: CGPoint,
        pixelSize: CGFloat,
        palette: SpritePalette,
        alpha: CGFloat,
        in context: CGContext
    ) {
        context.saveGState()
        context.setAlpha(alpha)
        context.setShouldAntialias(false)

        for (rowIndex, row) in bitmap.enumerated() {
            for (columnIndex, character) in row.enumerated() {
                guard let color = palette.color(for: character) else { continue }
                let rect = CGRect(
                    x: origin.x + CGFloat(columnIndex) * pixelSize,
                    y: origin.y + CGFloat(rowIndex) * pixelSize,
                    width: pixelSize,
                    height: pixelSize
                )
                context.setFillColor(color.cgColor)
                context.fill(rect)
            }
        }
        context.restoreGState()
    }
}
