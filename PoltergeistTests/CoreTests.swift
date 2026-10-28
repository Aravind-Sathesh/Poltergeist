import XCTest
@testable import Poltergeist

final class CoreTests: XCTestCase {
    func testParsesExtendedPlainAndMultilineHistory() {
        let raw = ": 1793192191:0;cd ~/code\n: 1793192192:0;docker run \\\n  --rm hello\nnpm test\n\n"
        XCTAssertEqual(ShellHistory.commands(in: Data(raw.utf8)), ["cd ~/code", "docker run \n  --rm hello", "npm test"])
    }

    func testUnmetafiesNonASCII() {
        // "é" is C3 A9; zsh doesn't metafy those, but 0x83 0xA3 decodes to 0x83.
        XCTAssertEqual(ShellHistory.unmetafy(Data([0x61, 0x83, 0xA3, 0x62])), Data([0x61, 0x83, 0x62]))
        XCTAssertEqual(ShellHistory.commands(in: Data("echo café".utf8)), ["echo café"])
    }

    func testRedactsSecrets() {
        XCTAssertEqual(ShellHistory.redact("export OPENAI_API_KEY=sk-abc123"), "export OPENAI_API_KEY=•••")
        XCTAssertEqual(ShellHistory.redact("mysql --password hunter2"), "mysql --password •••")
        XCTAssertEqual(ShellHistory.redact("curl -H 'Authorization: Bearer xyz'"), "curl -H 'Authorization: ••• •••")
        XCTAssertEqual(ShellHistory.redact("git clone https://me:tok@github.com/x/y"), "git clone https://•••@github.com/x/y")
        XCTAssertEqual(ShellHistory.redact("echo ghp_abcdefghijklmnopqrstuvwxyz0123456789"), "echo •••")
        XCTAssertEqual(ShellHistory.redact("git push origin main"), "git push origin main")
    }

    func testClassifiesCommands() {
        let omens = ShellHistory.omens(for: ["ls", "git push -f origin main", "npm test"], after: nil)
        XCTAssertEqual(omens.map(\.weight), [.startling, .idle])
        XCTAssertEqual(omens[0].detail, "They just force-pushed: git push -f origin main")
        // Repeats count across reads of the history file.
        let repeats = ShellHistory.omens(for: ["npm test", "npm test"], after: "npm test")
        XCTAssertEqual(repeats.map(\.weight), [.idle, .curious])
        XCTAssertEqual(repeats[1].detail, "They ran the same command 3 times in a row: npm test")
    }

    func testPicksHeaviestThenNewest() {
        let old = Omen(detail: "a", weight: .curious, seen: Date(timeIntervalSince1970: 1))
        let new = Omen(detail: "b", weight: .curious, seen: Date(timeIntervalSince1970: 2))
        let idle = Omen(detail: "c", weight: .idle, seen: Date(timeIntervalSince1970: 3))
        XCTAssertEqual(Omen.pick([old, idle, new])?.detail, "b")
    }

    func testCleansReplies() {
        XCTAssertEqual(Prompt.clean("Seen: x\nWhisper: \"Deleting logs again. 👻\""), "Deleting logs again.")
        XCTAssertEqual(Prompt.clean("  You again.  "), "You again.")
        XCTAssertNil(Prompt.clean("\n"))
    }

    func testSpokenDurations() {
        XCTAssertEqual(spoken(3 * 3600 + 12 * 60), "3 hours 12 minutes")
        XCTAssertEqual(spoken(3600), "1 hour")
        XCTAssertEqual(spoken(5 * 60), "5 minutes")
    }
}
