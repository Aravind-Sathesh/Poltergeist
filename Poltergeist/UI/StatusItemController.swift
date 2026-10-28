import AppKit

/// The ghost in the menu bar. Clicking it opens the haunt panel; each new whisper makes it flicker and appear on screen.
@MainActor
final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let haunting: Haunting
    private let panel: HauntPanel
    private let apparition = Apparition()
    private var shownWhisper: Whisper.ID?

    init(haunting: Haunting) {
        self.haunting = haunting
        panel = HauntPanel(haunting: haunting)
        super.init()
        item.button?.image = GhostIcon.image
        item.button?.toolTip = "Poltergeist"
        item.button?.target = self
        item.button?.action = #selector(toggle)
        watchWhispers()
    }

    @objc private func toggle() {
        guard let button = item.button else { return }
        panel.toggle(below: button)
    }

    private func watchWhispers() {
        withObservationTracking {
            let newest = haunting.whispers.first
            if let newest, newest.id != shownWhisper {
                flicker()
                if !panel.isOpen, Snapshot.folder == nil { apparition.show(newest.text, under: item.button) }
            }
            shownWhisper = newest?.id
            _ = haunting.errorMessage
            _ = haunting.isWhispering
            item.button?.appearsDisabled = haunting.restingUntil != nil
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.watchWhispers()
                self?.panel.refit()
            }
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

    /// Snapshot mode: writes the open panel and an apparition to `folder`, then quits.
    func snapshot(to folder: URL) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [self] in
            if let button = item.button { panel.show(below: button) }
            apparition.show(Snapshot.whispers[0].text, under: nil, types: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [self] in
                Snapshot.write(panel.contentView, to: folder.appending(path: "panel.png"))
                if let view = apparition.contentView { Snapshot.write(view, to: folder.appending(path: "apparition.png")) }
                NSApp.terminate(nil)
            }
        }
    }
}
