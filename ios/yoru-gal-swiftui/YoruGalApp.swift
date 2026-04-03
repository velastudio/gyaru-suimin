import SwiftUI

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

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.09, blue: 0.16).ignoresSafeArea()

            switch rootView {
            case .home:
                HomeView(
                    isMuted: $isMuted,
                    onGoChat: {
                        rootView = .chat
                    },
                    onGoSleep: {
                        rootView = .sleep
                    }
                )

            case .chat:
                Group {
                    if let responder {
                        ChatView(
                            responder: responder,
                            onBackHome: { rootView = .home },
                            onGoSleep: { rootView = .sleep }
                        )
                    } else if let responderError {
                        VStack(spacing: 16) {
                            Text(responderError)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white)
                                .padding()
                            Button("ホームへ戻る") {
                                rootView = .home
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        ProgressView("準備中…")
                            .tint(.white)
                    }
                }
                .task {
                    if responder != nil || responderError != nil { return }
                    await loadResponder()
                }

            case .sleep:
                SleepView(onBackHome: { rootView = .home })
            }
        }
    }

    private func loadResponder() async {
        do {
            responder = try BackendResponder.fromInfoPlist()
            responderError = nil
        } catch {
            responder = nil
            responderError = error.localizedDescription
        }
    }
}

@main
struct YoruGalApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

