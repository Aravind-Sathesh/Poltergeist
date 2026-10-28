import Foundation
import Observation
import ServiceManagement

/// Something the ghost said.
struct Whisper: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let omen: String
    var date = Date()

    /// The shell command that prompted it, if any: shell omens read "They just ran: <command>".
    var command: String? {
        guard omen.hasPrefix("They "), let colon = omen.range(of: ": ") else { return nil }
        return "$ " + omen[colon.upperBound...]
    }
}

/// Gathers omens from the senses and decides when the ghost speaks.
@Observable
@MainActor
final class Haunting {
    enum Level: String, CaseIterable {
        case faint, restless, possessed

        var interval: TimeInterval {
            switch self {
            case .faint: 30 * 60
            case .restless: 10 * 60
            case .possessed: 2 * 60
            }
        }

        var name: String { rawValue.capitalized }

        var cadence: String {
            switch self {
            case .faint: "about every 30 minutes"
            case .restless: "about every 10 minutes"
            case .possessed: "every couple of minutes"
            }
        }
    }

    private(set) var whispers: [Whisper] = []
    private(set) var isWhispering = false
    private(set) var errorMessage: String?
    private(set) var restingUntil: Date?

    var level: Level = Level(rawValue: UserDefaults.standard.string(forKey: "level") ?? "") ?? .restless {
        didSet { UserDefaults.standard.set(level.rawValue, forKey: "level") }
    }

    var speaksAloud = UserDefaults.standard.bool(forKey: "speaksAloud") {
        didSet { UserDefaults.standard.set(speaksAloud, forKey: "speaksAloud") }
    }

    var opensAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set { try? newValue ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister() }
    }

    private let senses = Senses()
    private let voice = Voice()
    private let ollama = OllamaClient()
    private var omens: [Omen] = []
    private var lastWhisper = Date()
    private var timer: Timer?

    func start() {
        lastWhisper = Date().addingTimeInterval(-level.interval + 60) // first whisper about a minute after launch
        senses.onOmen = { [weak self] in self?.receive($0) }
        senses.start()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.considerSpeaking() }
        }
    }

    /// Snapshot mode only: shows made-up whispers instead of watching anything.
    func haunt(with whispers: [Whisper]) {
        self.whispers = whispers
    }

    func rest(for interval: TimeInterval?) {
        restingUntil = interval.map { Date().addingTimeInterval($0) }
        omens.removeAll()
    }

    /// "Whisper Now" from the menu: speaks even when idle or resting, about the best omen or the hour.
    func summon() {
        let omen = Omen.pick(omens) ?? Omen(detail: "They summoned you on purpose. It is \(Date().formatted(date: .omitted, time: .shortened)).", weight: .curious)
        Task { await speak(about: omen) }
    }

    private func receive(_ omen: Omen) {
        omens.append(omen)
        if omens.count > 50 { omens.removeFirst(omens.count - 50) }
        if omen.weight == .startling { considerSpeaking() }
    }

    private func considerSpeaking() {
        if let until = restingUntil, until > Date() { return }
        restingUntil = nil
        omens.removeAll { Date().timeIntervalSince($0.seen) > 15 * 60 } // stale news isn't spooky
        guard !isWhispering, !senses.isIdle, let omen = Omen.pick(omens) else { return }
        let gap = Date().timeIntervalSince(lastWhisper)
        guard gap >= level.interval || (omen.weight == .startling && gap >= 60) else { return }
        Task { await speak(about: omen) }
    }

    private func speak(about omen: Omen) async {
        guard !isWhispering else { return }
        isWhispering = true
        defer { isWhispering = false }
        do {
            let text = try await ollama.whisper(omen)
            errorMessage = nil
            omens.removeAll()
            lastWhisper = Date()
            whispers.insert(Whisper(text: text, omen: omen.detail), at: 0)
            if whispers.count > 20 { whispers.removeLast() }
            #if DEBUG
            FileHandle.standardError.write(Data("[\(omen.weight)] \(omen.detail)\n  -> \(text)\n".utf8))
            #endif
            if speaksAloud { voice.speak(text) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
