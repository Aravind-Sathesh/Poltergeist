import Foundation

enum OllamaError: LocalizedError, Equatable {
    case offline
    case modelMissing
    case badResponse

    var errorDescription: String? {
        switch self {
        case .offline: "Gemma is asleep. Open the Ollama app to wake it."
        case .modelMissing: "Gemma isn't downloaded. Run: ollama pull \(OllamaClient.model)"
        case .badResponse: "Gemma mumbled something unreadable."
        }
    }
}

/// Talks to Ollama on this Mac and nowhere else, so your shell history never leaves it.
struct OllamaClient: Sendable {
    // 12b names the actual command or app; e2b mostly says generic spooky things. ~2-3 s a whisper is fine in the background.
    static let model = "gemma4:12b"
    private static let base = URL(string: "http://127.0.0.1:11434")!

    func whisper(_ omen: Omen) async throws -> String {
        let body: [String: Any] = [
            "model": Self.model,
            "messages": [["role": "system", "content": Prompt.system], ["role": "user", "content": Prompt.user(omen)]],
            "stream": false,
            "think": false,
            "keep_alive": "5m",
            "options": ["temperature": 0.9, "num_predict": 80],
        ]
        struct Reply: Decodable { struct Message: Decodable { let content: String }; let message: Message }
        let data = try await post("api/chat", body: body, timeout: 120)
        guard let reply = try? JSONDecoder().decode(Reply.self, from: data), let text = Prompt.clean(reply.message.content) else {
            throw OllamaError.badResponse
        }
        return text
    }

    private func post(_ path: String, body: [String: Any], timeout: TimeInterval) async throws -> Data {
        var request = URLRequest(url: Self.base.appending(path: path))
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            switch (response as? HTTPURLResponse)?.statusCode {
            case 200: return data
            case 404: throw OllamaError.modelMissing
            default: throw OllamaError.badResponse
            }
        } catch let error as URLError where error.code == .cannotConnectToHost || error.code == .networkConnectionLost {
            throw OllamaError.offline
        }
    }
}
