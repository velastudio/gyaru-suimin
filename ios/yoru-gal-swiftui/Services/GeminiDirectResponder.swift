import Foundation

struct GeminiDirectResponder: GalResponder {
    enum GeminiError: LocalizedError {
        case missingApiKey
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .missingApiKey:
                return "GEMINI_API_KEY が設定されていません。"
            case .invalidResponse:
                return "Gemini からの応答を解釈できませんでした。"
            }
        }
    }

    private let apiKey: String
    private let model: String

    init(apiKey: String, model: String = "gemini-3-flash-preview") {
        self.apiKey = apiKey
        self.model = model
    }

    func generateGalResponse(sessionId _: String, message: String) async throws -> String {
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

        // REST の JSON 形は Gemini 公式の "system_instruction" / "generationConfig" に合わせます。
        struct Part: Encodable { let text: String }
        struct Content: Encodable { let parts: [Part] }
        struct SystemInstruction: Encodable { let parts: [Part] }

        struct GenerationConfig: Encodable {
            let temperature: Double
        }

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

        let payload = Payload(
            system_instruction: SystemInstruction(parts: [Part(text: systemInstruction)]),
            contents: [Content(parts: [Part(text: message)])],
            generationConfig: GenerationConfig(temperature: 0.8)
        )
        request.httpBody = try JSONEncoder().encode(payload)

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
        else {
            throw GeminiError.missingApiKey
        }
        return GeminiDirectResponder(apiKey: apiKey)
    }
}

