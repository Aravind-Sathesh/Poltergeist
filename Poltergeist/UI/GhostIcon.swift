import AppKit

/// A little sheet ghost, drawn in code so it's a proper template image (SF Symbols has no ghost).
enum GhostIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            draw(in: rect)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Poltergeist"
        return image
    }()

    /// Body with a domed head and a three-scallop hem, eyes cut out. Works at any size.
    static func draw(in rect: NSRect) {
        let w = rect.width, h = rect.height
        func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: rect.minX + x * w, y: rect.minY + y * h) }
        let body = NSBezierPath()
        body.move(to: p(0.16, 0.18))
        body.line(to: p(0.16, 0.55))
        body.appendArc(withCenter: p(0.5, 0.55), radius: 0.34 * w, startAngle: 180, endAngle: 0, clockwise: true)
        body.line(to: p(0.84, 0.18))
        let scallop = 0.68 / 3
        for i in 0..<3 {
            let right = 0.84 - scallop * CGFloat(i), left = right - scallop
            body.curve(to: p(left, 0.18), controlPoint1: p(right - scallop * 0.1, 0.0), controlPoint2: p(left + scallop * 0.1, 0.0))
        }
        body.close()
        NSColor.black.setFill()
        body.fill()
        NSGraphicsContext.current?.compositingOperation = .destinationOut
        for x in [0.38, 0.62] {
            NSBezierPath(ovalIn: NSRect(origin: p(x - 0.065, 0.52), size: NSSize(width: 0.13 * w, height: 0.17 * h))).fill()
        }
        NSGraphicsContext.current?.compositingOperation = .sourceOver
    }
}
