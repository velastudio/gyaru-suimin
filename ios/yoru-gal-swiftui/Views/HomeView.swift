import SwiftUI

struct HomeView: View {
    @Binding var isMuted: Bool
    let onGoChat: () -> Void
    let onGoSleep: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer().frame(height: 40)

            VStack(spacing: 18) {
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
                            .overlay(Text("💅").font(.system(size: 36)))
                            .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 2))
                    }

                VStack(spacing: 6) {
                    Text("今日もお疲れさま。")
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

                HStack(spacing: 12) {
                    Button(action: { isMuted.toggle() }) {
                        HStack {
                            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            Text("リラックス音")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(Color.white.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }

                    Button(action: onGoSleep) {
                        HStack {
                            Image(systemName: "moon.stars.fill")
                            Text("そのまま寝る")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(Color.white.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            Text("Yoru-Gal MVP v1.0")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.35))
                .padding(.bottom, 24)
        }
    }
}

