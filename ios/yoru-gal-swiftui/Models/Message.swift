import Foundation

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

