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
    static let whisperFont = Font.system(size: 15, design: .serif).italic()
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
