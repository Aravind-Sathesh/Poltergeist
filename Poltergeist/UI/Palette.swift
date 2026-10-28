import SwiftUI

/// Poltergeist is always dark: it's a ghost, whatever the system appearance says.
enum Palette {
    static let night = Color(red: 0.055, green: 0.04, blue: 0.10)
    static let dusk = Color(red: 0.12, green: 0.07, blue: 0.21)
    static let surface = Color.white.opacity(0.04)
    static let ghost = Color(red: 0.75, green: 1, blue: 0.88) // the pale green of the app icon's ghost
    static let text = Color(red: 0.93, green: 0.91, blue: 0.97)
    static let faded = Color(red: 0.58, green: 0.54, blue: 0.70)
    static let warning = Color(red: 1, green: 0.74, blue: 0.45)

    static let background = LinearGradient(colors: [dusk, night], startPoint: .top, endPoint: .bottom)
    static let whisperFont = Font.system(size: 15, design: .serif)
}

/// The app's ghost, glowing and gently floating.
struct GhostMark: View {
    var size: CGFloat = 26
    var floats = true
    @State private var up = false

    var body: some View {
        Image(nsImage: GhostIcon.image)
            .resizable()
            .renderingMode(.template)
            .foregroundStyle(Palette.ghost)
            .frame(width: size, height: size)
            .shadow(color: Palette.ghost.opacity(0.7), radius: size / 3)
            .offset(y: floats && up ? -size / 12 : size / 12)
            .animation(floats ? .easeInOut(duration: 1.8).repeatForever(autoreverses: true) : nil, value: up)
            .onAppear { up = true }
    }
}

/// The ghost's own lines, for the moments Gemma isn't speaking.
enum Haunted {
    static let idleLines = [
        "Watching. Always watching.",
        "Listening through the walls.",
        "Counting your keystrokes.",
        "Breathing on the back of your neck.",
        "Sitting in the corner of your screen.",
        "Reading over your shoulder.",
        "Waiting for you to look away.",
        "Rearranging things you won't notice.",
        "Humming in the fans.",
        "Remembering the one before you.",
    ]

    /// Changes every minute, so each visit feels a little different.
    static var idleLine: String {
        idleLines[Int(Date().timeIntervalSince1970 / 60) % idleLines.count]
    }
}
