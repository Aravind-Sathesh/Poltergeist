import AppKit
import SwiftUI

/// POLTERGEIST_SNAPSHOT=folder renders the panel and an apparition to PNGs with made-up whispers, then quits.
/// SwiftUI renders them directly at 4x, so this needs no window and no screen-recording permission.
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

    @MainActor
    static func render(_ haunting: Haunting, to folder: URL) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        write(HauntView(haunting: haunting), to: folder.appending(path: "panel.png"))
        write(ApparitionView(text: whispers[0].text, types: false) {}, to: folder.appending(path: "apparition.png"))
    }

    /// Renders at 4x so the screenshots stay sharp even scaled and tilted in the cover.
    @MainActor
    private static func write(_ view: some View, to file: URL) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 4
        guard let image = renderer.cgImage else { return }
        try? NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?.write(to: file)
    }
}
