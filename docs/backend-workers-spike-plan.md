# Workers 移行スパイク計画

## 1. 目的

現行の Vercel + Hono バックエンドを Cloudflare Workers に移行する前に、
移行可否を左右する不確実性を最小単位で検証する。

いきなり全面移植に入ると `@google/genai` の Workers 互換でブロックされたときに
戻りにくくなる。先にスパイクで移行の Go/No-Go を確定させる。

## 2. 背景と判断根拠

### 移行を検討する理由

- private GitHub Organization repository × Vercel Hobby = デプロイ不可
  - Vercel 公式 docs で private Org repo からのデプロイを Hobby プランでは明確に制限している
- Cloudflare Workers Free は 1 日 100,000 requests で小規模 MVP には十分

### Cloudflare Workers を移行先として選ぶ根拠

- Hono は Cloudflare Workers を主要ターゲットとして公式サポートしている
  - Web Standards ベースで複数ランタイム対応が設計原則
  - `app.fetch` + wrangler 構成が公式に整っている
- 現行の `/health`・`/api/chat`・Zod バリデーション・統一エラー構成は
  Web API 的な作りであり、Workers の実行モデルとの相性が高い

### 移行の最大不確実性

`@google/genai` SDK の Workers 互換性。

- 公式 README / docs は Node.js 20 を前提に記述されており、
  Cloudflare Workers を明示的なサポート対象として案内していない
- GitHub issue では `@google/genai/node` を Workers 上で import すると失敗する事例が報告されている
  - 原因: `google-logging-utils` が `process.stderr` 系の Node 依存処理に触れる
- Node 専用 import を避け、汎用 path で使えば通る可能性は高いが、公式保証はない
- これは「動かない証拠」ではなく「Workers 互換が公式文脈で未確認」という意味である

### 現実装で確実に変更が必要な箇所

| 箇所 | 現状 | 変更内容 |
|------|------|---------|
| 環境変数 | `process.env.GEMINI_API_KEY` | `c.env` または `env(c)` に置換 |
| タイムアウト | `httpOptions: { timeout: 8000 }` | Workers 上で効くか要確認 |
| エントリポイント | `api/index.ts` + `vercel.json` | `app.fetch` + `wrangler.toml` に置換 |
| ビルド / デプロイ | `tsx` / `tsc` | `wrangler` ベースに変わる |

ルーティング・バリデーション・エラー定義・システムプロンプトは変更不要の見込み。

## 3. スパイク構成

3 本を順番に実施する。前のスパイクが解決できない問題で止まった場合は
後続に進まず判断を行う。

---

### Spike 1: Workers env

**目的**

`process.env` を使わずに `c.env` または Hono アダプターの `env(c)` で
環境変数 / シークレットを取り扱う設計を確定させる。

**検証内容**

ローカル確認とデプロイ確認を分けて行う。

ローカル確認（`wrangler dev`）:

- `server/.dev.vars` に `GEMINI_API_KEY=xxx` を記述する
  - `.dev.vars` は `wrangler dev` 実行時のみ参照されるローカル専用ファイルである
  - `.gitignore` に追加し、リポジトリにコミットしない
- `wrangler dev` 起動後、Worker 内で `c.env.GEMINI_API_KEY` として値を参照できること
- 値はレスポンスに含めず、存在確認だけを行う

デプロイ確認（Cloudflare Dashboard / wrangler）:

- `wrangler secret put GEMINI_API_KEY` はデプロイ済み Worker へのシークレット登録コマンドである
- ローカルの `wrangler dev` では `.dev.vars` を使うため、`wrangler secret put` はデプロイ側の確認として分けて実施する

**完了条件**

- `wrangler dev` 環境で `.dev.vars` 経由のシークレットが `c.env` から参照できること
- 値がログやレスポンスに露出しないこと

**期待難易度**: 低。Hono の Workers 対応で `c.env` は公式に整っている。

---

### Spike 2: Workers entry

**目的**

`api/index.ts` + `vercel.json` の Vercel 前提を捨て、
`app.fetch` + `wrangler.toml` の最小構成で `GET /health` が返ることを確認する。

**検証内容**

- `wrangler.toml` を作成しエントリポイントを設定する
- Hono アプリを `export default app` または `export default { fetch: app.fetch }` で公開する
- `wrangler dev` でローカル起動し `GET /health` が `{"status":"ok"}` を返す

**完了条件**

- `wrangler dev` でローカル動作すること
- `GET /health` → 200 + `{"status":"ok"}`

**期待難易度**: 低〜中。Hono の公式 Workers 構成に沿えば詰まりにくい。

---

### Spike 3: Gemini SDK compatibility

**目的**

Workers 上で `@google/genai` を使い `generateContent` を最小構成で実行できるか確認する。
これが **移行全体の Go/No-Go を決める最重要スパイク** である。

**検証内容**

1. `@google/genai` を Node 専用 import (`@google/genai/node`) を使わずに import する
2. `c.env.GEMINI_API_KEY` から取得した API キーで `GoogleGenAI` を初期化する
3. 最小テキスト入力で `generateContent` を呼び、応答テキストが返ること
4. タイムアウト制御を確認する
   - `httpOptions: { timeout: 8000 }` が Workers 上で機能するか確認する
   - 機能しない場合は `AbortController` + `AbortSignal.timeout()` で包む方式に切り替える
5. `console.info` で `sessionId` を出力し、Workers Logs 上で確認できること

**完了条件**

- `generateContent` が Workers 上で正常に応答テキストを返すこと
- タイムアウト制御が何らかの形で機能すること
- ログが Workers Logs 上で確認できること

**期待難易度**: 中〜高。SDK 互換が今回の最大の不確実性。

**結果: 失敗**

`@google/genai` を含むファイルに切り替えた時点で `c.env` binding が空になった。
top-level import / dynamic import の両方で同じ挙動だった。
`/env-check` の結果: `{"hasGeminiApiKey":false,"hasGeminiModel":false,"envKeys":[]}`
`generateContent` の実検証には到達できなかった。

判定: SDK 路線はブロック。fallback（Gemini REST API 直接 `fetch`）で進める。

---

## 4. Spike 3 の結果による分岐

### Go: SDK がそのまま通る場合

Workers 全面移行に進む。

`docs/backend-requirements.md` を以下の内容で更新する。

- 配置先: Vercel → Cloudflare Workers
- アダプター: `hono/vercel` → `hono/cloudflare-workers`（または `app.fetch` 直接利用）
- 環境変数: `process.env` → `c.env` / wrangler bindings

その後、`server/` 配下を Workers 構成に移植する。

### Go with fallback: SDK が通らない場合

Gemini 呼び出しを `@google/genai` SDK から **Gemini REST API への `fetch` 直接呼び出し** に切り替えて移行する。

- Workers は `fetch` をネイティブサポートする
- Gemini の `generateContent` エンドポイントは公開 REST API として利用できる
- SDK 非依存になるため Node 互換問題を回避できる
- `services/gemini.ts` の実装を置き換える。他のファイルは変更不要

この場合は Spike 3 の結果として記録し、`docs/backend-requirements.md` の SDK 使用方針を更新してから移植に進む。

### No-Go: fallback 込みでも通らない場合

Workers 移行を一時保留し、Railway / Render（Node.js 環境）への移行を検討する。
Node 環境なら現実装をほぼそのまま動かせるため、確実性が高い。

## 5. スパイク中に触らないもの

スパイク中は以下を変更しない。インフラ層と SDK 互換の確認だけに絞る。

- `routes/chat.ts`（ルーティング本体）
- `schemas/chat.ts`（Zod バリデーション）
- `errors/apiError.ts`（エラー定義）
- `prompts/systemPrompt.ts`（システムプロンプト）
- iOS 側のすべてのコード

## 6. 実施順サマリー

```
Spike 1（env）→ Spike 2（entry）→ Spike 3（Gemini SDK）
```

| Spike | 目的 | 期待難易度 | 詰まった場合 |
|-------|------|-----------|------------|
| Spike 1 | env 設計確定 | 低 | wrangler 設定の問題として切り分ける |
| Spike 2 | entry 最小構成確認 | 低〜中 | Hono Workers 構成の問題として切り分ける |
| Spike 3 | Gemini SDK 互換確認 | 中〜高 | fallback（REST 直接呼び出し）を判断する |
