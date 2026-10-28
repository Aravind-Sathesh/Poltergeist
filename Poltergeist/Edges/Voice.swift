import AVFoundation
import UserNotifications

/// How a whisper reaches you: a notification banner, and optionally macOS's own Whisper voice.
@MainActor
final class Voice: NSObject, UNUserNotificationCenterDelegate {
    private let synthesizer = AVSpeechSynthesizer()

    func start() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        Task { _ = try? await center.requestAuthorization(options: [.alert, .sound]) }
    }

    func post(_ text: String) {
        let content = UNMutableNotificationContent()
        content.body = text
        content.threadIdentifier = "whispers"
        Task { try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)) }
    }

    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(identifier: "com.apple.speech.synthesis.voice.Whisper") ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.42
        synthesizer.speak(utterance)
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }
}
