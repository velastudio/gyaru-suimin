import Foundation

/// 将来的に「バックエンド経由」に切り替えるための差し替え先（MVPでは未設定想定）。
struct BackendResponder: GalResponder {
    let baseURL: URL

    func generateGalResponse(message: String) async throws -> String {
        // MVP段階ではバックエンドが未作成でもコンパイルできるように、
        // 実行時には明確にエラーを返します。
        struct NotImplementedError: LocalizedError {
            var errorDescription: String? { "BackendResponder は未設定です（baseURL を設定してください）。" }
        }
        throw NotImplementedError()
    }
}

