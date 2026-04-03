import Foundation

protocol GalResponder {
    func generateGalResponse(sessionId: String, message: String) async throws -> String
}

