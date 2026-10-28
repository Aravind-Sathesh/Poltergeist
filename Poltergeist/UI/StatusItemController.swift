import AppKit

/// The ghost in the menu bar. It flickers when it whispers; its menu keeps the last few things it said.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let haunting: Haunting
    private var shownWhisper: Whisper.ID?

    init(haunting: Haunting) {
        self.haunting = haunting
        super.init()
        item.button?.image = GhostIcon.image
        item.button?.toolTip = "Poltergeist"
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        watchWhispers()
    }

    private func watchWhispers() {
        withObservationTracking {
            let newest = haunting.whispers.first
            if let newest, newest.id != shownWhisper { flicker() }
            shownWhisper = newest?.id
            item.button?.toolTip = newest?.text ?? "Poltergeist"
            item.button?.appearsDisabled = haunting.restingUntil != nil
        } onChange: { [weak self] in
            Task { @MainActor in self?.watchWhispers() }
        }
    }

    /// Fades the ghost in and out a few times, like a bad bulb.
    private func flicker() {
        guard let button = item.button else { return }
        let steps: [CGFloat] = [0.15, 1, 0.3, 1, 0.1, 0.8, 0.2, 1]
        for (i, alpha) in steps.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09 * Double(i)) { button.alphaValue = alpha }
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(NSMenuItem(title: statusLine, action: nil, keyEquivalent: ""))
        if !haunting.whispers.isEmpty {
            menu.addItem(.separator())
            for whisper in haunting.whispers.prefix(5) {
                let entry = action("") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(whisper.text, forType: .string) }
                entry.attributedTitle = Self.title(for: whisper)
                entry.toolTip = "Because: \(whisper.omen)\nClick to copy."
                menu.addItem(entry)
            }
        }
        menu.addItem(.separator())
        let now = action("Whisper Now") { [haunting] in haunting.summon() }
        now.isEnabled = !haunting.isWhispering
        menu.addItem(now)

        let levels = NSMenu()
        for level in Haunting.Level.allCases {
            let choice = action(level.title) { [haunting] in haunting.level = level }
            choice.state = haunting.level == level ? .on : .off
            levels.addItem(choice)
        }
        let levelItem = NSMenuItem(title: "Haunting", action: nil, keyEquivalent: "")
        levelItem.submenu = levels
        menu.addItem(levelItem)

        let aloud = action("Speak Whispers Aloud") { [haunting] in haunting.speaksAloud.toggle() }
        aloud.state = haunting.speaksAloud ? .on : .off
        menu.addItem(aloud)
        if haunting.restingUntil == nil {
            menu.addItem(action("Rest for an Hour") { [haunting] in haunting.rest(for: 3600) })
        } else {
            menu.addItem(action("Wake the Ghost") { [haunting] in haunting.rest(for: nil) })
        }
        let login = action("Open at Login") { [haunting] in haunting.opensAtLogin.toggle() }
        login.state = haunting.opensAtLogin ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Exorcise Poltergeist", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private var statusLine: String {
        if let error = haunting.errorMessage { return error }
        if haunting.isWhispering { return "Whispering…" }
        if let until = haunting.restingUntil { return "Resting until \(until.formatted(date: .omitted, time: .shortened))" }
        return "Watching. Always watching."
    }

    /// The whisper wrapped to a readable width, with how long ago it was said underneath.
    private static func title(for whisper: Whisper) -> NSAttributedString {
        var lines: [String] = [""]
        for word in whisper.text.split(separator: " ") {
            if lines[lines.count - 1].count + word.count > 46 { lines.append("") }
            lines[lines.count - 1] += (lines[lines.count - 1].isEmpty ? "" : " ") + word
        }
        let title = NSMutableAttributedString(string: lines.joined(separator: "\n"), attributes: [.font: NSFont.menuFont(ofSize: 0)])
        let ago = whisper.date.formatted(.relative(presentation: .named))
        title.append(NSAttributedString(string: "\n\(ago)", attributes: [.font: NSFont.menuFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]))
        return title
    }

    private func action(_ title: String, _ run: @escaping () -> Void) -> NSMenuItem {
        ClosureMenuItem(title: title, run: run)
    }
}

/// A menu item that runs a closure, so the menu needs no selector per action.
private final class ClosureMenuItem: NSMenuItem {
    private let run: () -> Void

    init(title: String, run: @escaping () -> Void) {
        self.run = run
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError("not used") }

    @objc private func fire() { run() }
}
