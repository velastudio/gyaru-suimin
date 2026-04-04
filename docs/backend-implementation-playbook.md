# バックエンド実装プレイブック

## 1. 目的

`docs/backend-requirements.md` を起点に、要件を 1 つずつ崩しながら実装する。

このドキュメントの目的は以下。

- 実装順を固定する
- 1 コミットあたりの責務を小さく保つ
- 各作業で「何を確認してから着手するか」を明確にする
- 途中で方針がぶれないようにする

## 2. 進め方の固定ルール

毎回、以下の順で進める。

1. 次に着手するチェック項目を 1 つだけ選ぶ
2. 対応する要件を `docs/backend-requirements.md` で再確認する
3. その項目に必要な最小変更だけを入れる
4. その項目に対応する検証だけを行う
5. チェックを更新する
6. すぐにコミットする

同時に複数項目を進めない。
1 回のコミットで複数の責務を混ぜない。

## 3. コミットルール

### 3.1 基本原則

- 1 コミット 1 責務
- 実装と無関係な整形を混ぜない
- 検証が終わってからコミットする
- コミット前に「この差分は何を満たすためのものか」を 1 文で言える状態にする

### 3.2 コミットメッセージ形式

以下の形式で統一する。

```text
<type>: <scope> <summary>
```

例:

```text
chore: scaffold server package
feat: add health endpoint
feat: validate chat request payload
feat: add gemini service timeout handling
feat: wire ios app to backend responder
```

`type` の使い分けは以下。

- `chore`: 土台、設定、開発環境、スキャフォールド
- `feat`: 要件を満たす機能追加
- `fix`: 実装後に見つかった不具合修正
- `docs`: 要件整理や手順書更新
- `test`: テスト追加やテスト補強

## 4. 実装単位の分解

以下の順で進める。各項目は原則 1 コミットで完結させる。

### 4.1 フェーズ A: サーバ土台

- [x] A1. `server/` パッケージを新設する
  - 目的: Node.js パッケージ、TypeScript、Hono、Vercel 向け最小構成を置く
  - コミット例: `chore: scaffold server package`

- [x] A2. Vercel 用エントリポイントを用意する
  - 目的: `hono/vercel` と `export default` の構成を作る
  - コミット例: `feat: add vercel hono entrypoint`

- [x] A3. `vercel.json` を追加する
  - 目的: `/(.*)` を `/api/index` に rewrite する
  - コミット例: `chore: add vercel rewrites`

### 4.2 フェーズ B: ヘルスチェック

- [x] B1. `GET /health` を返すルートを追加する
  - 目的: `200` と `{"status":"ok"}` を返す
  - コミット例: `feat: add health endpoint`

### 4.3 フェーズ C: API 契約

- [x] C1. `POST /api/chat` のリクエストスキーマを定義する
  - 目的: `sessionId` と `message` を受ける形を固定する
  - コミット例: `feat: define chat request schema`

- [x] C2. リクエストバリデーションを実装する
  - 目的: 空文字、空白、1000 文字超過、不正 JSON を `400` で返す
  - コミット例: `feat: validate chat request payload`

- [x] C3. エラーレスポンス形式を統一する
  - 目的: `INVALID_REQUEST` `INTERNAL_SERVER_ERROR` `LLM_ERROR` を固定する
  - コミット例: `feat: standardize api error responses`

### 4.4 フェーズ D: Gemini 呼び出し

- [x] D1. システムプロンプトをサーバ側モジュールへ移す
  - 目的: クライアントから人格定義を外す準備をする
  - コミット例: `feat: add server managed system prompt`

- [x] D2. Gemini サービスを追加する
  - 目的: `@google/genai` を使い、モデル既定値と環境変数読み出しを実装する
  - コミット例: `feat: add gemini service`

- [x] D3. Gemini タイムアウトと異常応答の扱いを実装する
  - 目的: 8 秒タイムアウト、空文字や解釈不能応答を `502` に統一する
  - コミット例: `feat: handle gemini timeout and invalid responses`

### 4.5 フェーズ E: ルート統合

- [x] E1. `POST /api/chat` を Gemini サービスへ接続する
  - 目的: 正常時に `{"text": "..."}`
  - コミット例: `feat: wire chat route to gemini service`

- [x] E2. 例外ログと `sessionId` 相関ログを入れる
  - 目的: 本文を常時保存せず、失敗追跡可能にする
  - コミット例: `feat: add backend request logging`

### 4.6 フェーズ F: iOS 切り替え

- [x] F1. iOS 側で `sessionId` を保持する
  - 目的: セッション単位の API 契約を満たす
  - コミット例: `feat: add ios session id handling`

- [x] F2. `BackendResponder` を実装する
  - 目的: `POST /api/chat` を叩いて `text` を返す
  - コミット例: `feat: implement ios backend responder`

- [x] F3. `RootView.loadResponder()` をバックエンド経由へ切り替える
  - 目的: `GeminiDirectResponder` を本経路から外す
  - コミット例: `feat: switch ios app to backend responder`

- [x] F4. クライアント API キー依存を除去する
  - 目的: iOS に `GEMINI_API_KEY` を持たせない状態にする
  - コミット例: `chore: remove ios gemini api key dependency`

### 4.7 フェーズ G: レート制限

- [x] G1. `wrangler.toml` に `[[ratelimits]]` binding を追加する
  - 目的: Cloudflare Workers Rate Limiting を Worker に紐付ける
  - 設定値: `limit = 20`, `period = 60`
  - `namespace_id` は自分で決める正の整数の文字列。API やダッシュボードで発行するものではない（例: `"1001"`）
  - 同じアカウント内で同じ `namespace_id` を使う binding はカウンタを共有する。この Worker 専用にするなら他と重複しない値を使う
  - `period` は `10` か `60`（秒）のみ指定可能
  - コミット例: `chore: add rate limiting binding to wrangler config`

- [ ] G2. `@cloudflare/workers-types` を devDependency に追加し、tsconfig を更新する
  - 目的: `RateLimit` 型を使えるようにする
  - `npm install -D @cloudflare/workers-types`
  - `tsconfig.json` の `"types"` に `"@cloudflare/workers-types"` を追加する
  - コミット例: `chore: add cloudflare workers types`

- [ ] G3. `RATE_LIMITER` binding をレート制限ミドルウェアとして実装する
  - 目的: `POST /api/chat` の前段で `env.RATE_LIMITER.limit({ key })` を呼び、超過時に `429` と `RATE_LIMITED` を返す
  - key: `c.req.header('CF-Connecting-IP') ?? 'unknown'`
  - 型: `@cloudflare/workers-types` の `RateLimit`
  - ローカル開発（`wrangler dev`）ではレート制限は動作しない。デプロイ後に確認する
  - コミット例: `feat: add rate limiting middleware to chat endpoint`

## 5. 各ステップの着手テンプレート

毎回、着手前に次の 4 点を短く確認する。

```text
今回の項目:
対象要件:
変更範囲:
完了条件:
```

例:

```text
今回の項目: B1. GET /health を返すルートを追加する
対象要件: backend-requirements.md の 5.2 / 14
変更範囲: server/src/index.ts と health route のみ
完了条件: GET /health が 200 と {"status":"ok"} を返す
```

## 6. 各ステップの完了テンプレート

コミット前に、以下を満たしたら完了扱いにする。

- [ ] 変更は今回の項目に閉じている
- [ ] 要件書に書かれた振る舞いと一致している
- [ ] 最低限の検証が終わっている
- [ ] チェックを更新した
- [ ] すぐコミットできる粒度になっている

## 7. このブランチでの運用方針

この `codex/backend-setup` ブランチでは、上の順番を基本線として進める。

ただし以下の場合のみ順番を前後してよい。

- 先行タスクのために最小限の土台追加が必要なとき
- 直前コミットの不備を修正する小さな `fix` を入れるとき

それ以外は、未完の項目を飛ばして実装しない。
