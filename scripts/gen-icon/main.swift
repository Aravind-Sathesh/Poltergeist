// Regenerates Poltergeist/Assets.xcassets/AppIcon.appiconset: the menu bar ghost, glowing on a night-purple tile.
// Run from the Poltergeist directory (it reuses the app's ghost drawing):
// swiftc Poltergeist/UI/GhostIcon.swift scripts/gen-icon/main.swift -o build/gen-icon && build/gen-icon
import AppKit

let out = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Poltergeist/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func render(pixels: Int) -> Data? {
    let size = CGFloat(pixels)
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
                                     hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let tile = NSRect(x: size * 0.06, y: size * 0.06, width: size * 0.88, height: size * 0.88)
    let path = NSBezierPath(roundedRect: tile, xRadius: size * 0.2, yRadius: size * 0.2)
    NSGradient(colors: [NSColor(red: 0.10, green: 0.06, blue: 0.22, alpha: 1), NSColor(red: 0.30, green: 0.14, blue: 0.48, alpha: 1)])?.draw(in: path, angle: 90)
    // A soft glow behind the ghost, then the ghost itself in pale green-white.
    NSGradient(colors: [NSColor(red: 0.6, green: 1, blue: 0.8, alpha: 0.35), NSColor(red: 0.6, green: 1, blue: 0.8, alpha: 0)])?
        .draw(in: NSBezierPath(ovalIn: tile.insetBy(dx: size * 0.08, dy: size * 0.08)), relativeCenterPosition: .zero)
    let ghost = NSImage(size: NSSize(width: size * 0.56, height: size * 0.56), flipped: false) { rect in
        GhostIcon.draw(in: rect)
        NSColor(red: 0.92, green: 1, blue: 0.95, alpha: 1).set()
        rect.fill(using: .sourceIn)
        return true
    }
    ghost.draw(in: NSRect(x: size * 0.22, y: size * 0.2, width: size * 0.56, height: size * 0.56))
    return rep.representation(using: .png, properties: [:])
}

var images: [[String: String]] = []
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(base)x\(base)\(scale == 2 ? "@2x" : "").png"
        if let data = render(pixels: base * scale) { try data.write(to: out.appendingPathComponent(name)) }
        images.append(["idiom": "mac", "size": "\(base)x\(base)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["version": 1, "author": "xcode"]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys]).write(to: out.appendingPathComponent("Contents.json"))
try JSONSerialization.data(withJSONObject: ["info": ["version": 1, "author": "xcode"]], options: [.sortedKeys]).write(to: out.deletingLastPathComponent().appendingPathComponent("Contents.json"))
print("wrote \(images.count) icons")
