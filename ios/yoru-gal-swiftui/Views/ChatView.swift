import SwiftUI

struct ChatView: View {
    @StateObject private var vm: ChatViewModel

    private let onBackHome: () -> Void
    private let onGoSleep: () -> Void

    init(
        responder: any GalResponder,
        onBackHome: @escaping () -> Void,
        onGoSleep: @escaping () -> Void
    ) {
        _vm = StateObject(wrappedValue: ChatViewModel(responder: responder))
        self.onBackHome = onBackHome
        self.onGoSleep = onGoSleep
    }

    var canSend: Bool {
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
                    Circle()
                        .fill(LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 34, height: 34)
                        .overlay(Text("💅").font(.system(size: 14)))

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

            // Messages
            ZStack {
                Color(red: 0.06, green: 0.09, blue: 0.16).opacity(0.85).ignoresSafeArea()

                MessagesList(vm: vm)
            }

            // Input
            VStack {
                HStack(spacing: 12) {
                    TextField("ここに愚痴を書いてね...", text: $vm.inputText)
                        .textInputAutocapitalization(.sentences)
                        .disableAutocorrection(true)
                        .autocorrectionDisabled(true)
                        .submitLabel(.send)
                        .onSubmit {
                            vm.sendMessage()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                        .background(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )

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

private struct MessagesList: View {
    @ObservedObject var vm: ChatViewModel

    var body: some View {
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
                        ProgressView()
                            .tint(.white.opacity(0.7))
                        Text("考えてるよ…")
                            .foregroundStyle(.white.opacity(0.65))
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // MVPでは自動スクロールは簡略化しています。
                Color.clear.frame(height: 1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}

