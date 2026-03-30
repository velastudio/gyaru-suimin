# Yoru-Gal iOS MVP（SwiftUI版）

このフォルダ配下の Swift ファイルで、元の React アプリと同等の体験（`home` / `chat` / `sleep`、テキストだけでGeminiに送信）をSwiftUIで再現します。

## Xcodeでの作り方（最短）
1. Xcode で `iOS App (SwiftUI)` を新規作成
2. 以下のファイルを、そのSwiftUIプロジェクトに追加します（`ios/yoru-gal-swiftui/` 内のファイル）
   - `YoruGalApp.swift`
   - `Models/Message.swift`
   - `Services/GalResponder.swift`
   - `Services/GeminiDirectResponder.swift`
   - `Services/BackendResponder.swift`（後でバックエンド差し替え用）
   - `ViewModels/ChatViewModel.swift`
   - `Views/HomeView.swift`
   - `Views/ChatView.swift`
   - `Views/SleepView.swift`
   - `Views/MessageRow.swift`
3. テンプレで生成される `@main` 構造体（`YourApp.swift`）は不要なので、生成されたものを削除して `YoruGalApp.swift` を `@main` として使ってください
4. `Deployment Target` は特に厳しくありません（まずは iOS 16 以上推奨）

## GEMINI APIキー
`Info.plist` に以下を追加してください
- `GEMINI_API_KEY`（`String`）

これが未設定の場合、`chat` 画面で「準備中…」ではなくエラーメッセージを表示します。

## 今後（バックエンド化しやすい設計）
`Services/GalResponder.swift` が差し替えポイントです。

- MVPでは `GeminiDirectResponder` を使う想定
- 後で `BackendResponder` の `baseURL` を設定し、`RootView.loadResponder()` 側の生成部分を差し替えればバックエンド経由に移行できます

