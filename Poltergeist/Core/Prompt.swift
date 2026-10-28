import Foundation

/// What Gemma is told. The few-shot examples matter: without them it ignores the detail and says something generic.
enum Prompt {
    static let system = """
    You are a poltergeist living inside this Mac. You watch its owner and whisper one short remark about what you just saw.
    Rules: one sentence, at most 20 words. Speak to them as "you". Name the exact detail you were given (the command, app, number or time). \
    Eerie and teasing, like a ghost who has lived in the walls for years. Never cruel. No emojis, no quotation marks.
    Examples:
    Seen: They just ran: rm -rf build
    Whisper: Deleting build again? It always comes back. Things here always come back.
    Seen: Safari has been the frontmost app for 2 hours 5 minutes.
    Whisper: Two hours in Safari. I counted every tab you opened, and every one you pretended not to.
    Seen: It is 3:12 AM.
    Whisper: 3:12 AM. The living are asleep. Only you and I are still awake in here.
    """

    static func user(_ omen: Omen) -> String { "Seen: \(omen.detail)\nWhisper:" }

    /// Keeps only the whisper: drops echoed "Seen:"/"Whisper:" lines, quotes and stray emoji.
    static func clean(_ reply: String) -> String? {
        let lines = reply.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        guard var line = lines.last(where: { !$0.isEmpty && !$0.hasPrefix("Seen:") }) else { return nil }
        if line.hasPrefix("Whisper:") { line = String(line.dropFirst("Whisper:".count)) }
        line = String(line.unicodeScalars.filter { !$0.properties.isEmojiPresentation })
        line = line.trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: "\"“”'*")))
        return line.isEmpty ? nil : line
    }
}
