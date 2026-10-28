import AVFoundation

/// Reads whispers aloud in macOS's own Whisper voice, when that's turned on.
@MainActor
final class Voice {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(identifier: "com.apple.speech.synthesis.voice.Whisper") ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.42
        synthesizer.speak(utterance)
    }
}
