import AppKit

/// The menu bar glyph, drawn at runtime so it stays crisp on any display and
/// can change colour with the state of yabai.
enum MenubarIcon {

    enum State {
        case running
        case stopped
        case busy

        var color: NSColor {
            switch self {
            case .running:
                return NSColor(srgbRed: 0.13, green: 0.72, blue: 0.31, alpha: 1)
            case .stopped:
                return NSColor(srgbRed: 0.45, green: 0.45, blue: 0.48, alpha: 1)
            case .busy:
                return NSColor(srgbRed: 0.20, green: 0.47, blue: 0.94, alpha: 1)
            }
        }
    }

    private static let side: CGFloat = 18

    private static var cache: [State: NSImage] = [:]

    static func image(for state: State) -> NSImage {
        if let cached = cache[state] { return cached }
        let made = render(state: state)
        cache[state] = made
        return made
    }

    private static func render(state: State) -> NSImage {
        let scale = min(max(NSScreen.main?.backingScaleFactor ?? 2, 1), 2)
        let pixels = Int(side * scale)

        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return NSImage(size: NSSize(width: side, height: side))
        }
        representation.size = NSSize(width: side, height: side)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: representation)
        if let context = NSGraphicsContext.current?.cgContext {
            // The context already maps the representation's point size onto its
            // pixel size, so the drawing below is expressed in points.
            draw(state: state, in: context)
        }
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: NSSize(width: side, height: side))
        image.addRepresentation(representation)
        image.isTemplate = false
        return image
    }

    /// Draws the binary space partitioning glyph: one tall pane on the left,
    /// two stacked panes on the right.
    private static func draw(state: State, in context: CGContext) {
        context.setShouldAntialias(true)
        context.setAllowsAntialiasing(true)

        let inset: CGFloat = 2
        let gap: CGFloat = 1.5
        let radius: CGFloat = 1.8
        let top = side - inset
        let bottom = inset
        let left = inset
        let right = side - inset

        let totalWidth = right - left
        let leftWidth = (totalWidth - gap) * 0.48
        let rightWidth = totalWidth - gap - leftWidth
        let rightX = left + leftWidth + gap
        let rightHeight = (top - bottom - gap) / 2

        let panes: [CGRect] = [
            CGRect(x: left, y: bottom, width: leftWidth, height: top - bottom),
            CGRect(x: rightX, y: bottom, width: rightWidth, height: rightHeight),
            CGRect(x: rightX, y: bottom + rightHeight + gap, width: rightWidth, height: rightHeight)
        ]

        context.setStrokeColor(state.color.cgColor)
        context.setFillColor(state.color.cgColor)

        for pane in panes {
            let path = CGPath(
                roundedRect: pane,
                cornerWidth: radius,
                cornerHeight: radius,
                transform: nil
            )
            if state == .stopped {
                // Outlined: an empty glyph reads as "not running".
                context.setLineWidth(1.3)
                context.addPath(path)
                context.strokePath()
            } else {
                context.addPath(path)
                context.fillPath()
            }
        }
    }
}
