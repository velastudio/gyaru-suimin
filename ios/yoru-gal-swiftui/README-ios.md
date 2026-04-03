# Yoru-Gal iOS MVP（SwiftUI版）

このフォルダ配下の Swift ファイルで、元の React アプリと同等の体験（`home` / `chat` / `sleep`、テキストだけでバックエンドに送信）を SwiftUI で再現します。

## Xcodeでの作り方（最短）
1. Xcode で `iOS App (SwiftUI)` を新規作成
2. 以下のファイルを、そのSwiftUIプロジェクトに追加します（`ios/yoru-gal-swiftui/` 内のファイル）
   - `YoruGalApp.swift`
   - `Models/Message.swift`
   - `Services/GalResponder.swift`
   - `Services/BackendResponder.swift`
   - `ViewModels/ChatViewModel.swift`
   - `Views/HomeView.swift`
   - `Views/ChatView.swift`
   - `Views/SleepView.swift`
   - `Views/MessageRow.swift`
3. テンプレで生成される `@main` 構造体（`YourApp.swift`）は不要なので、生成されたものを削除して `YoruGalApp.swift` を `@main` として使ってください
4. `Deployment Target` は特に厳しくありません（まずは iOS 16 以上推奨）

## バックエンド URL
`Info.plist` に以下を追加してください
- `BACKEND_BASE_URL`（`String`）

例:

- 本番: `https://yoru-gal-server.akigabe31.workers.dev`

これが未設定の場合、`chat` 画面で「準備中…」ではなくエラーメッセージを表示します。

## 構成
`Services/GalResponder.swift` が差し替えポイントです。

- 現在は `BackendResponder` を本経路として使用します
- `sessionId` は iOS 側で生成し、`POST /api/chat` に `message` と一緒に送信します
- 人格プロンプトや Gemini API キーはクライアントに持たせません

