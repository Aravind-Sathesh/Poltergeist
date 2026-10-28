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
            Whisper(text: "NoSuchGhostProcess is not dead, you silly creature. I am still here, watching you from behind the glass.",
                    omen: "They just killed a process: pkill -x NoSuchGhostProcess", date: ago(1)),
            Whisper(text: "Forcefully rewriting history? You think you can erase the past, but I still remember every line.",
                    omen: "They just force-pushed: git push --force origin main", date: ago(14)),
            Whisper(text: "Three hours and twelve minutes in Xcode. You are building your little world while mine slowly fades away.",
                    omen: "Xcode has been the frontmost app for 3 hours 12 minutes.", date: ago(38)),
            Whisper(text: "npm test five times. Do you really think those tests will find what is hiding in the code?",
                    omen: "They ran the same command 5 times in a row: npm test", date: ago(65)),
            Whisper(text: "412 files. You keep collecting things you will never look at again.",
                    omen: "Their Downloads folder holds 412 files.", date: ago(130)),
        ]
    }

    /// Renders a view, or a window's whole frame when given its content view's superview, to a PNG.
    @MainActor
    static func write(_ view: NSView, to file: URL) {
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: file)
    }
}
