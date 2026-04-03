import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var isTyping: Bool = false
    @Published var errorMessage: String? = nil

    private let responder: any GalResponder
    private let sessionId: String

    init(
        responder: any GalResponder,
        sessionId: String = UUID().uuidString
    ) {
        self.responder = responder
        self.sessionId = sessionId
    }

    func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isTyping else { return }

        inputText = ""
        errorMessage = nil

        messages.append(Message(text: trimmed, sender: .user, timestamp: Date()))
        isTyping = true

        Task {
            do {
                let responseText = try await responder.generateGalResponse(
                    sessionId: sessionId,
                    message: trimmed
                )
                messages.append(Message(text: responseText, sender: .gal, timestamp: Date()))
            } catch {
                let fallback = "あー、なんかエラー出ちゃった。まじごめん！でも君が頑張ってるのは変わらないからね。"
                errorMessage = error.localizedDescription
                messages.append(Message(text: fallback, sender: .gal, timestamp: Date()))
            }
            isTyping = false
        }
    }
}

