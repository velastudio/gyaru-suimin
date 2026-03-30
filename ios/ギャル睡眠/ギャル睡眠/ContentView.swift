//
//  ContentView.swift
//  ギャル睡眠
//
//  Created by Hinari Ibuki on 2026/03/23.
//

import SwiftUI
import Combine
import Foundation

// MARK: - Models

struct Message: Identifiable, Equatable {
    enum Sender {
        case user
        case gal
    }

    let id: UUID = UUID()
    let text: String
    let sender: Sender
    let timestamp: Date
}

// MARK: - AI responder

protocol GalResponder {
    func generateGalResponse(message: String) async throws -> String
}

struct GeminiDirectResponder: GalResponder {
    enum GeminiError: LocalizedError {
        case missingApiKey
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .missingApiKey: "GEMINI_API_KEY が設定されていません。"
            case .invalidResponse: "Gemini からの応答を解釈できませんでした。"
            }
        }
    }

    private let apiKey: String
    private let model: String

    init(apiKey: String, model: String = "gemini-3-flash-preview") {
        self.apiKey = apiKey
        self.model = model
    }

    func generateGalResponse(message: String) async throws -> String {
        let systemInstruction = """
        あなたは20〜30代の社会人に寄り添う「大人なギャル」です。
        ユーザーは寝る前に1日のストレスや愚痴を吐き出しに来ています。

        # 話し方のガイドライン
        - 語尾は「〜じゃん」「〜だよん」「〜かも」「〜しよ？」など、親しみやすいギャル語を使います。
        - 否定は絶対にせず、まずは「それな」「まじでお疲れ」「しんどすぎ」と共感してください。
        - アドバイスは求められない限りせず、「頑張ったの知ってるよ」「うちら最強だし」と肯定に徹してください。
        - 派手すぎない、落ち着いたトーンの「お姉さんギャル」を意識してください。
        - 最後に「もう寝よ？」「明日も適当にこなそ」といった、眠りを促す一言を添えてください。

        # レスポンスの構成
        1. 共感・肯定（「まじでお疲れ！」「それしんどいね...」）
        2. ユーザーの頑張りを認める（「よくやってるよ」「偉すぎ」）
        3. 癒やしと睡眠への誘導（「今日はもう忘れよ？」「ゆっくり寝てね」）
        """

        struct Part: Encodable { let text: String }
        struct Content: Encodable { let parts: [Part] }
        struct SystemInstruction: Encodable { let parts: [Part] }
        struct GenerationConfig: Encodable { let temperature: Double }
        struct Payload: Encodable {
            let system_instruction: SystemInstruction
            let contents: [Content]
            let generationConfig: GenerationConfig
        }

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONEncoder().encode(
            Payload(
                system_instruction: SystemInstruction(parts: [Part(text: systemInstruction)]),
                contents: [Content(parts: [Part(text: message)])],
                generationConfig: GenerationConfig(temperature: 0.8)
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw GeminiError.invalidResponse
        }

        struct GeminiResponse: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable {
                        let text: String?
                    }
                    let parts: [Part]?
                }
                let content: Content?
            }
            let candidates: [Candidate]?
        }

        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        if let text = decoded.candidates?.first?.content?.parts?.first?.text, !text.isEmpty {
            return text
        }
        throw GeminiError.invalidResponse
    }

    static func fromInfoPlist() throws -> GeminiDirectResponder {
        guard
            let apiKey = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String,
            !apiKey.isEmpty
        else { throw GeminiError.missingApiKey }

        return GeminiDirectResponder(apiKey: apiKey)
    }
}

// MARK: - ViewModel

@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var isTyping: Bool = false
    @Published var errorMessage: String? = nil

    private let responder: any GalResponder

    init(responder: any GalResponder) {
        self.responder = responder
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
                let responseText = try await responder.generateGalResponse(message: trimmed)
                messages.append(Message(text: responseText, sender: .gal, timestamp: Date()))
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                let fallback = "あー、なんかエラー出ちゃった。まじごめん！でも君が頑張ってるのは変わらないからね。"
                messages.append(Message(text: fallback, sender: .gal, timestamp: Date()))
            }
            isTyping = false
        }
    }
}

// MARK: - Views

struct MessageRow: View {
    let message: Message

    var body: some View {
        HStack {
            if message.sender == .user { Spacer() }

            Text(message.text)
                .foregroundStyle(message.sender == .user ? Color.white : Color.white.opacity(0.92))
                .font(.system(size: 14))
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(message.sender == .user ? Color.purple.opacity(0.85) : Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(message.sender == .user ? Color.clear : Color.white.opacity(0.08), lineWidth: 1)
                )

            if message.sender == .gal { Spacer() }
        }
        .padding(.horizontal, 4)
    }
}

struct HomeView: View {
    @Binding var isMuted: Bool
    let onGoChat: () -> Void
    let onGoSleep: () -> Void
    let onTapGalIcon: () -> Void
    @State private var isGalIconFloating: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 18) {
                Button(action: onTapGalIcon) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.pink.opacity(0.95), .purple.opacity(0.95)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 86, height: 86)
                        .overlay {
                            Circle()
                                .fill(Color(red: 0.06, green: 0.09, blue: 0.16))
                                .frame(width: 78, height: 78)
                                .overlay(
                                    Image("GalNail")
                                        .resizable()
                                        .scaledToFill()
                                        .clipShape(Circle())
                                        .frame(width: 64, height: 64)
                                )
                                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 2))
                        }
                }
                .buttonStyle(.plain)
                .offset(y: isGalIconFloating ? -8 : 8)
                .animation(
                    .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                    value: isGalIconFloating
                )
                .onAppear {
                    // 表示後すぐに上下アニメを開始
                    isGalIconFloating = true
                }

                VStack(spacing: 6) {
                    Text("おつ〜！寝る前にちょっと話そ〜")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white)
                    Text("溜め込んでない？全部聞くよ。")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .multilineTextAlignment(.center)
            }

            VStack(spacing: 14) {
                Button(action: onGoChat) {
                    HStack {
                        Image(systemName: "message.circle.fill")
                        Text("ちょっと聞いてほしい")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundStyle(.white)
                    .background(
                        LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Button(action: { isMuted.toggle() }) {
                    HStack {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        Text("BGM音")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(Color.white.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            Spacer()

            Text("Yoru-Gal MVP v1.0")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.35))
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 16)
        .background(Color(red: 0.06, green: 0.09, blue: 0.16))
    }
}

struct SleepView: View {
    let onBackHome: () -> Void

    var body: some View {
        VStack(spacing: 26) {
            Spacer()

            Image(systemName: "moon.stars.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.indigo.opacity(0.45))

            VStack(spacing: 6) {
                Text("おやすみなさい")
                    .font(.system(size: 22, weight: .light, design: .rounded))
                    .foregroundStyle(.white)
                Text("明日のことは、明日考えよ。")
                    .foregroundStyle(.white.opacity(0.5))
                    .font(.system(size: 13))
            }

            Button(action: onBackHome) {
                Text("戻る")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 999).stroke(Color.white.opacity(0.12), lineWidth: 1))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.indigo.opacity(0.25), Color.black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}

struct ChatView: View {
    @StateObject private var vm: ChatViewModel
    private let onBackHome: () -> Void
    private let onGoSleep: () -> Void
    private let onTapGalIcon: () -> Void

    init(
        responder: any GalResponder,
        onBackHome: @escaping () -> Void,
        onGoSleep: @escaping () -> Void,
        onTapGalIcon: @escaping () -> Void
    ) {
        _vm = StateObject(wrappedValue: ChatViewModel(responder: responder))
        self.onBackHome = onBackHome
        self.onGoSleep = onGoSleep
        self.onTapGalIcon = onTapGalIcon
    }

    private var canSend: Bool {
        !vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !vm.isTyping
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onBackHome) {
                    Image(systemName: "arrow.left")
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }

                HStack(spacing: 10) {
                    Button(action: onTapGalIcon) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.pink, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 34, height: 34)
                            .overlay(
                                Image("GalNail")
                                    .resizable()
                                    .scaledToFill()
                                    .clipShape(Circle())
                                    .frame(width: 34, height: 34)
                            )
                    }
                    .buttonStyle(.plain)

                    Text("ギャルちゃん")
                        .foregroundStyle(.white)
                        .font(.system(size: 16, weight: .semibold))
                }

                Spacer()

                Button(action: onGoSleep) {
                    Text("寝る")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.purple.opacity(0.9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            ZStack {
                Color(red: 0.06, green: 0.09, blue: 0.16).opacity(0.85).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        if vm.messages.isEmpty {
                            VStack(spacing: 14) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 40))
                                    .foregroundStyle(Color.purple.opacity(0.85))
                                Text("何でも吐き出しちゃいな。\nうちらだけの秘密だよん。")
                                    .foregroundStyle(.white.opacity(0.55))
                                    .font(.system(size: 14))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                            .padding(.bottom, 20)
                        }

                        ForEach(vm.messages) { msg in
                            MessageRow(message: msg)
                        }

                        if vm.isTyping {
                            HStack {
                                ProgressView().tint(.white.opacity(0.7))
                                Text("考えてるよ…")
                                    .foregroundStyle(.white.opacity(0.65))
                                    .font(.system(size: 12))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Color.clear.frame(height: 1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }

            VStack {
                HStack(spacing: 12) {
                    TextField("ここに愚痴を書いてね...", text: $vm.inputText)
                        .textInputAutocapitalization(.sentences)
                        .disableAutocorrection(true)
                        .autocorrectionDisabled(true)
                        .submitLabel(.send)
                        .onSubmit { vm.sendMessage() }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                        .background(Color.white.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 1))

                    Button(action: { vm.sendMessage() }) {
                        Image(systemName: "paperplane.fill")
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(
                                LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!canSend)
                    .opacity(canSend ? 1.0 : 0.5)
                }
                .padding(16)
            }
            .background(
                LinearGradient(
                    colors: [Color(red: 0.06, green: 0.09, blue: 0.16), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}

// MARK: - Root view

private enum RootViewType {
    case home
    case chat
    case sleep
}

struct RootView: View {
    @State private var rootView: RootViewType = .home
    @State private var isMuted: Bool = true

    @State private var responder: (any GalResponder)? = nil
    @State private var responderError: String? = nil
    @State private var isProfilePresented: Bool = false

    var body: some View {
        ZStack {
            switch rootView {
            case .home:
                HomeView(
                    isMuted: $isMuted,
                    onGoChat: { rootView = .chat },
                    onGoSleep: { rootView = .sleep },
                    onTapGalIcon: { isProfilePresented = true }
                )

            case .chat:
                Group {
                    if let responder {
                        ChatView(
                            responder: responder,
                            onBackHome: { rootView = .home },
                            onGoSleep: { rootView = .sleep },
                            onTapGalIcon: { isProfilePresented = true }
                        )
                    } else if let responderError {
                        VStack(spacing: 16) {
                            Text(responderError)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white)
                                .padding()
                            Button("ホームへ戻る") { rootView = .home }
                                .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(red: 0.06, green: 0.09, blue: 0.16).ignoresSafeArea())
                    } else {
                        ProgressView("準備中…")
                            .tint(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(red: 0.06, green: 0.09, blue: 0.16).ignoresSafeArea())
                    }
                }
                .task {
                    // 先にロードしておくと、チャット画面遷移後に待たなくて済みます。
                    if responder != nil || responderError != nil { return }
                    await loadResponder()
                }

            case .sleep:
                SleepView(onBackHome: { rootView = .home })
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $isProfilePresented) {
            ProfileView(name: "あやちゃむ")
        }
    }

    private func loadResponder() async {
        do {
            responder = try GeminiDirectResponder.fromInfoPlist()
            responderError = nil
        } catch {
            responder = nil
            responderError = error.localizedDescription
        }
    }
}

struct ProfileView: View {
    let name: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image("GalNail")
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
                    .frame(width: 110, height: 110)
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 2))

                VStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                    Text("寝る前の愚痴、全部受け止めるよん。")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("閉じる")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.06, green: 0.09, blue: 0.16), Color.black.opacity(0.9)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("プロフィール")
                        .foregroundStyle(.white)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
        }
    }
}

struct ContentView: View {
    var body: some View {
        RootView()
    }
}

#Preview {
    ContentView()
}
