import Foundation

protocol GalResponder {
    func generateGalResponse(message: String) async throws -> String
}

