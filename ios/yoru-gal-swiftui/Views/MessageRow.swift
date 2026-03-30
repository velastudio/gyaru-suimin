import SwiftUI

struct MessageRow: View {
    let message: Message

    var body: some View {
        HStack {
            if message.sender == .user {
                Spacer()
            }

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

            if message.sender == .gal {
                Spacer()
            }
        }
        .padding(.horizontal, 4)
    }
}

