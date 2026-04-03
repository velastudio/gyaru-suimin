# バックエンド要件定義書

## 1. 文書の目的

本書は、iOS アプリ「Yoru-Gal / ギャル睡眠」の初期バックエンド実装に必要な要件を定義する。

本バックエンドの主目的は以下とする。

- iOS クライアントから Gemini API の直接呼び出しを排除する
- ギャルキャラの人格プロンプトをサーバ側で一元管理する
- 将来の会話履歴保存や機能拡張に備え、API 契約を先に安定化する

## 2. 背景

現状の iOS 実装では、クライアントが Gemini API を直接呼び出している。

- 実装箇所: `ios/yoru-gal-swiftui/Services/GeminiDirectResponder.swift`
- 差し替え口: `ios/yoru-gal-swiftui/Services/BackendResponder.swift`
- 呼び出し元: `ios/yoru-gal-swiftui/YoruGalApp.swift`

この構成には以下の問題がある。

- API キーをクライアントに持たせる必要がある
- システムプロンプト変更のたびにアプリ更新が必要になる
- モデル切り替えや障害制御をクライアントで扱いづらい
- 将来の履歴保存や監査機能追加時に責務分離が崩れる

## 3. スコープ

### 3.1 対象

初期リリースの対象は以下とする。

- Cloudflare Workers 上で動作する HTTP API の実装
- Gemini API を呼び出すサーバロジック
- サーバ側でのシステムプロンプト管理
- iOS から呼び出す主要エンドポイントの提供
- 最低限の入力検証とエラーハンドリング

### 3.2 非対象

初期リリースでは以下は実装しない。

- データベース
- 会話履歴の永続化
- 認証、ログイン、ユーザー管理
- 課金
- 管理画面
- アプリケーション内でのレート制限
- ストリーミング応答
- プッシュ通知
- 複数モデル切り替え UI

## 4. システム構成

### 4.1 採用構成

- クライアント: iOS アプリ
- バックエンド: Hono + TypeScript
- 配置先: Cloudflare Workers
- LLM: Gemini API
- デプロイツール: Wrangler

### 4.2 採用理由

- Cloudflare Workers は private GitHub Organization リポジトリでも無料プランでデプロイ可能
- Free プランで 1 日 100,000 requests、MVP 規模には十分
- Hono は Cloudflare Workers を主要ターゲットとして公式サポートしており、相性が最良
- 現時点では単発の HTTP リクエストで十分であり、WebSocket や DB は不要

### 4.3 実装前提

- Hono アプリは `export default app` で Workers エントリとして公開する
- 環境変数は `process.env` ではなく Hono の `c.env`（Workers Bindings）から取得する
- バックエンドはリポジトリ内の `server/` を独立した Node.js パッケージとして構成する
- デプロイは `wrangler deploy`、ローカル確認は `wrangler dev` を使用する
- ローカル開発時のシークレットは `server/.dev.vars` に記載し、リポジトリにはコミットしない
- Gemini 呼び出しには `@google/genai` SDK を使わず、Gemini REST API を `fetch` で直接呼び出す
- SDK を使わない理由: Cloudflare Workers 上で `c.env` binding が崩れることが Spike 3 で確認された

## 5. 機能要件

### 5.1 提供機能

バックエンドは、ユーザーの入力テキストを受け取り、ギャル人格に基づく応答テキストを返す。

### 5.2 エンドポイント

#### `POST /api/chat`

ユーザーの入力を受け取り、LLM 応答を返す。

#### `GET /health`

デプロイ確認および疎通確認用の軽量なヘルスチェックを返す。

成功時:

```json
{
  "status": "ok"
}
```

### 5.3 リクエスト仕様

```json
{
  "sessionId": "uuid-string",
  "message": "今日しんどかった"
}
```

#### フィールド定義

| Name | Type | Required | Description |
|------|------|----------|-------------|
| sessionId | string | Yes | セッション識別子。初期版では受け取るが未使用。将来の履歴保存用に先行定義する |
| message | string | Yes | ユーザー入力テキスト |

#### バリデーション要件

- `sessionId` は空文字を不可とする
- `sessionId` は初期版では UUID 形式までは検証しない
- `message` は空文字または空白のみを不可とする
- `message` は Unicode 文字数ベースで最大 1000 文字までとする
- 不正な JSON は `400` を返す

### 5.4 レスポンス仕様

成功時:

```json
{
  "text": "それな、まじでお疲れだよん。今日はもう寝よ？"
}
```

| Name | Type | Required | Description |
|------|------|----------|-------------|
| text | string | Yes | ギャル人格による最終応答テキスト |

### 5.5 エラー仕様

初期版では以下の HTTP ステータスを扱う。

| Status | 意味 |
|--------|------|
| 200 | 正常応答 |
| 400 | 入力不正 |
| 500 | サーバ内部エラー |
| 502 | LLM 応答異常または上流 API 異常 |

エラーコードは以下で固定する。

| Status | code |
|--------|------|
| 400 | `INVALID_REQUEST` |
| 500 | `INTERNAL_SERVER_ERROR` |
| 502 | `LLM_ERROR` |

エラーレスポンスはクライアントが扱いやすい最小 JSON を返す。

- `error.message` は英語で返す

```json
{
  "error": {
    "code": "INVALID_REQUEST",
    "message": "message is required"
  }
}
```

Gemini から空文字、`null`、または解釈不能なレスポンスが返った場合は成功扱いにせず、`502` と `LLM_ERROR` を返す。

## 6. プロンプト管理要件

### 6.1 基本方針

システムプロンプトは必ずサーバ側で管理する。クライアントは人格定義を持たない。

### 6.2 必須理由

- ギャルキャラの人格はアプリの中核価値である
- 文体や安全方針を即時に調整できる必要がある
- プロンプト変更のたびにアプリ審査を通す構成は避ける

### 6.3 実装要件

- 初期版ではサーバコード内の定数または専用モジュールとして保持する
- クライアントからシステムプロンプトを受け取らない
- モデルへの送信時は、必ずサーバ管理のシステムプロンプトを付与する

## 7. セッション要件

### 7.1 `sessionId` の扱い

- `sessionId` は初期版から必須フィールドとして定義する
- iOS 側は `UUID().uuidString` 等で生成して送信する
- サーバは初期版では `sessionId` を保存しなくてよい
- サーバは初期版では `sessionId` を文脈復元には使わない
- サーバは初期版では `sessionId` の妥当性を UUID 形式では判定せず、非空文字のみを検証する

### 7.2 将来拡張前提

将来、会話履歴 DB を導入する際は `sessionId` をキーとして履歴紐付けを行う。初期版で API 契約を固定しておくことで、クライアント互換性を維持する。

## 8. 非機能要件

### 8.1 可用性

- iOS 実機から到達可能な公開 URL を持つこと
- 開発環境と本番環境で URL を分離可能であること

### 8.2 性能

- 単発チャット応答として許容できる体感速度で応答すること
- Gemini 呼び出し単体のタイムアウトは 8 秒とする

具体的な SLA は初期版では定めないが、無制限待ち状態は許容しない。リクエスト全体の上限は Cloudflare Workers の実行制限に従い、Gemini 呼び出しが 8 秒でタイムアウトした場合は `502` と `LLM_ERROR` を返す。

### 8.3 保守性

- ルート、スキーマ、LLM 呼び出し、プロンプト定義を分離すること
- システムプロンプト変更時に API 契約へ影響を与えないこと
- 例外発生時に原因追跡可能なログを残すこと

## 9. セキュリティ要件

### 9.1 必須要件

- Gemini API キーはサーバ環境変数で管理する
- API キーを iOS アプリに含めない
- 入力長制限を設ける
- 初期版ではブラウザクライアントをサポートしないため、CORS ヘッダーは付与しない

### 9.2 初期版で採用しない制御

- アプリケーション内レート制限

Cloudflare Workers でも共有ストアなしの in-memory レート制限は実効性を持たないため、初期版では `429` を要件に含めない。乱用対策が必要になった時点で、共有ストアまたは外部レイヤーを前提に別途設計する。

### 9.3 初期版で不要なもの

- ユーザー認証
- ロール管理
- データ暗号化ストレージ

認証は不要とする。初期版は iOS クライアント専用 API とし、Web ブラウザ向け公開利用は対象外とする。

## 10. ログ・監視要件

初期版では外部監視基盤は必須としないが、以下は最低限必要とする。

- リクエスト処理成功・失敗の記録
- 上流 LLM API 異常の記録
- 例外スタックまたは原因の記録
- `sessionId` をログ相関用に記録する

初期版では、ユーザーの `message` 本文は通常ログに記録しない。必要な場合でも平文の常時保存は行わず、デバッグ時の一時的な限定出力に留める。

## 11. iOS 連携要件

### 11.1 クライアント側変更

iOS 側は以下の変更を行う前提とする。

- `GeminiDirectResponder` を使用しない
- `BackendResponder` を実装する
- `RootView.loadResponder()` で `BackendResponder` を生成する
- リクエスト時に `sessionId` と `message` を送信する

### 11.2 クライアント責務

クライアントは以下のみを責務とする。

- ユーザー入力送信
- セッション ID 生成
- 応答表示
- エラー表示

人格プロンプト、モデル名、LLM ベンダー設定はクライアント責務に含めない。

### 11.3 Web 版との関係

`.yoru-gal-tmp` 配下の Web 実装は初期バックエンド切り替えの対象外とする。初期版では iOS クライアント連携のみを要件に含め、Web 版をバックエンド経由へ移すかは別途判断する。

## 12. ディレクトリ要件

バックエンド実装はリポジトリ内に独立ディレクトリを切ることを前提とする。

例:

```text
server/
  package.json
  wrangler.toml
  src/
    index.ts
    routes/chat.ts
    services/gemini.ts
    prompts/systemPrompt.ts
    schemas/chat.ts
```

構成名は最終実装時に調整してよいが、責務分離は維持すること。

`wrangler.toml` には少なくとも以下の設定を含めること。

```toml
name = "yoru-gal-server"
main = "src/index.ts"
compatibility_date = "2026-04-03"
```

## 13. 環境変数要件

少なくとも以下を扱えること。

| Name | Required | Description |
|------|----------|-------------|
| GEMINI_API_KEY | Yes | Gemini API 呼び出し用キー |
| GEMINI_MODEL | No | 使用モデル名。未指定時の既定値は `gemini-3-flash-preview` とする |
| APP_ENV | No | 実行環境識別子 |

## 14. 受け入れ条件

以下を満たした時点で、初期バックエンド要件を満たしたと判定する。

- `GET /health` が `200` と `{"status":"ok"}` を返す
- `POST /api/chat` が定義通りの JSON を受け取る
- `sessionId` と `message` の検証が行われる
- サーバ側システムプロンプトを付与して Gemini を呼び出す
- 正常時に `text` を返す
- 異常時に JSON エラーを返す
- API キーがクライアントに存在しない
- iOS から `BackendResponder` 経由で疎通できる
- Cloudflare Workers 上の公開 URL で実機確認できる

## 15. 今後の拡張候補

本書の対象外だが、将来拡張候補として以下を想定する。

- `sessionId` ベースの会話履歴保存
- DB 導入
- abuse 対策の強化
- モデレーション追加
- A/B テスト可能なプロンプト切り替え
- モデル切り替え戦略
- 管理用メトリクス

## 16. 最終方針

初期バックエンドは、Cloudflare Workers 上で動作する軽量な stateless API とする。

固定方針は以下とする。

- DB なし
- Auth なし
- エンドポイントは `POST /api/chat` および `GET /health`
- `sessionId` は初期版から必須
- システムプロンプトはサーバ側で必ず管理
- iOS は `BackendResponder` 経由でのみ接続

この方針により、実装速度を保ちながら、将来の履歴保存や運用改善に耐える最小構成を実現する。
