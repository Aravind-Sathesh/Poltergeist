import Foundation

/// Something the ghost noticed. `detail` is one plain sentence Gemma turns into a whisper.
struct Omen: Equatable, Sendable {
    enum Weight: Int, Comparable, Sendable {
        case idle = 1     // an ordinary command
        case curious = 2  // a pattern worth remarking on: a repeated command, hours in one app
        case startling = 3 // something dramatic: a force push, a dying battery. Interrupts the cooldown.

        static func < (a: Weight, b: Weight) -> Bool { a.rawValue < b.rawValue }
    }

    let detail: String
    let weight: Weight
    var seen = Date()

    /// The most interesting omen: heaviest first, then the newest.
    static func pick(_ omens: [Omen]) -> Omen? {
        omens.max { ($0.weight, $0.seen) < ($1.weight, $1.seen) }
    }
}

/// Plain-English durations for omens, like "3 hours 12 minutes".
func spoken(_ interval: TimeInterval) -> String {
    let minutes = Int(interval / 60)
    let (h, m) = (minutes / 60, minutes % 60)
    func unit(_ n: Int, _ word: String) -> String { "\(n) \(word)\(n == 1 ? "" : "s")" }
    if h == 0 { return unit(m, "minute") }
    return m == 0 ? unit(h, "hour") : "\(unit(h, "hour")) \(unit(m, "minute"))"
}
