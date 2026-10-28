import AppKit

/// POLTERGEIST_SNAPSHOT=folder renders the open panel and an apparition to PNGs with made-up whispers, then quits.
/// The app draws its own windows, so this needs no screen-recording permission.
enum Snapshot {
    static var folder: URL? {
        ProcessInfo.processInfo.environment["POLTERGEIST_SNAPSHOT"].map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    static var whispers: [Whisper] {
        func ago(_ minutes: Double) -> Date { Date().addingTimeInterval(-minutes * 60) }
        return [
            Whisper(text: "Three hours in Xcode. The previous owner stayed all night until their fingers bled.",
                    omen: "Xcode has been the frontmost app for 3 hours 12 minutes.", date: ago(1)),
            Whisper(text: "That force-push makes me miss the last owner. They were gentler with the code.",
                    omen: "They just force-pushed: git push --force origin main", date: ago(14)),
            Whisper(text: "npm install brings so many new neighbors. Some of them have been hiding in your folders since the start.",
                    omen: "They just ran: npm install", date: ago(41)),
            Whisper(text: "Killing AnotherGhostProcess? You cannot banish what has already woven itself into the marrow of your machine.",
                    omen: "They just killed a process: pkill -x AnotherGhostProcess", date: ago(65)),
        ]
    }

    /// Renders a view to a PNG at 2x, so the screenshots stay sharp on retina and in the cover.
    @MainActor
    static func write(_ view: NSView, to file: URL) {
        let size = view.bounds.size
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2), bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
        rep.size = size
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: file)
    }
}
