import Foundation

struct BackendResponder: GalResponder {
    private struct ChatRequest: Encodable {
        let sessionId: String
        let message: String
    }

    private struct ChatResponse: Decodable {
        let text: String
    }

    private struct ErrorEnvelope: Decodable {
        struct APIError: Decodable {
            let code: String
            let message: String
        }

        let error: APIError
    }

    enum BackendError: LocalizedError {
        case invalidResponse
        case serverError(String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "バックエンドの応答を解釈できませんでした。"
            case let .serverError(message):
                return message
            }
        }
    }

    let baseURL: URL

    func generateGalResponse(sessionId: String, message: String) async throws -> String {
        let endpoint = baseURL.appendingPathComponent("api/chat")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            ChatRequest(sessionId: sessionId, message: message)
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }

        if (200...299).contains(http.statusCode) {
            let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
            return decoded.text
        }

        if let decoded = try? JSONDecoder().decode(ErrorEnvelope.self, from: data) {
            throw BackendError.serverError(decoded.error.message)
        }

        throw BackendError.invalidResponse
    }
}

