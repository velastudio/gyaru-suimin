import SwiftUI

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
                    .overlay(
                        RoundedRectangle(cornerRadius: 999)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
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

