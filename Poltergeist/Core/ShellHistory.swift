import Foundation

/// Reads zsh's history file and turns new commands into omens.
enum ShellHistory {
    /// Splits raw history bytes into commands. Handles zsh's extended format (`: 1700000000:0;cmd`),
    /// multi-line commands (lines ending in a backslash) and zsh's "metafied" bytes for non-ASCII text.
    static func commands(in data: Data) -> [String] {
        let text = String(decoding: unmetafy(data), as: UTF8.self)
        var commands: [String] = []
        var pending: String?
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            var line = String(line)
            if pending == nil, line.hasPrefix(": "), let semicolon = line.firstIndex(of: ";") {
                line = String(line[line.index(after: semicolon)...])
            }
            let joined = pending.map { $0 + "\n" + line } ?? line
            if joined.hasSuffix("\\") {
                pending = String(joined.dropLast())
            } else {
                pending = nil
                let command = joined.trimmingCharacters(in: .whitespacesAndNewlines)
                if !command.isEmpty { commands.append(command) }
            }
        }
        return commands
    }

    /// zsh writes bytes 0x83–0x9F as 0x83 followed by the byte XOR 32.
    static func unmetafy(_ data: Data) -> Data {
        guard data.contains(0x83) else { return data }
        var out = Data(capacity: data.count)
        var meta = false
        for byte in data {
            if meta { out.append(byte ^ 32); meta = false } else if byte == 0x83 { meta = true } else { out.append(byte) }
        }
        return out
    }

    /// Commands too dull to haunt anyone about.
    private static let boring: Set<String> = ["ls", "ll", "la", "cd", "pwd", "clear", "exit", "history", "l", "c"]

    private static let dramatic: [(pattern: String, why: String)] = [
        (#"git\s+push\b.*(--force\b|-f\b|--force-with-lease)"#, "force-pushed"),
        (#"git\s+reset\s+--hard"#, "threw away their work with a hard reset"),
        (#"\brm\s+-[a-zA-Z]*r[a-zA-Z]*f|\brm\s+-[a-zA-Z]*f[a-zA-Z]*r"#, "deleted something with rm -rf"),
        (#"^sudo\b"#, "used sudo"),
        (#"chmod\s+(-R\s+)?777"#, "made something world-writable"),
        (#"kill\s+-9|killall\b|pkill\b"#, "killed a process"),
        (#"(?i)drop\s+(table|database)"#, "dropped a database table"),
        (#"git\s+commit\b.*--amend"#, "rewrote their last commit"),
        (#"git\s+stash\s+(drop|clear)"#, "threw away stashed work"),
    ]

    /// Turns the newest commands into omens. `earlier` is the command just before them, to spot repeats across reads.
    static func omens(for commands: [String], after earlier: String?) -> [Omen] {
        var omens: [Omen] = []
        var previous = earlier
        var streak = 1
        for raw in commands {
            let command = redact(raw)
            streak = command == previous ? streak + 1 : 1
            previous = command
            let name = String(command.split(separator: " ").first ?? "")
            if boring.contains(name) { continue }
            if streak >= 3 {
                omens.append(Omen(detail: "They ran the same command \(streak) times in a row: \(command)", weight: .curious))
            } else if let hit = dramatic.first(where: { command.range(of: $0.pattern, options: .regularExpression) != nil }) {
                omens.append(Omen(detail: "They just \(hit.why): \(command)", weight: .startling))
            } else {
                omens.append(Omen(detail: "They just ran: \(command)", weight: .idle))
            }
        }
        return omens
    }

    /// Masks anything that looks like a secret before a command goes anywhere, even to the local model.
    static func redact(_ command: String) -> String {
        var s = command.count > 200 ? String(command.prefix(200)) + "…" : command
        let rules: [(String, String)] = [
            (#"(?i)(bearer|basic)\s+\S+"#, "$1 •••"),
            (#"(?i)\b([\w-]*(password|passwd|pwd|token|secret|apikey|api_key|api-key|auth)[\w-]*)(\s*[=:]\s*|\s+)("[^"]*"|'[^']*'|\S+)"#, "$1$3•••"),
            (#"://[^/\s:@]+:[^/\s@]+@"#, "://•••@"),
            (#"\b[A-Za-z0-9_\-+/=]{32,}\b"#, "•••"),
        ]
        for (pattern, template) in rules {
            s = s.replacingOccurrences(of: pattern, with: template, options: .regularExpression)
        }
        return s
    }
}
