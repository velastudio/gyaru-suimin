# Repository Instructions

- `docs/backend-implementation-playbook.md` に従って作業すること。
- 実装に着手する前に `docs/backend-requirements.md` の該当要件を確認すること。
- 1コミット1責務を守り、複数の実装項目を同じコミットに混ぜないこと。
- Workers 移行スパイクに着手する前に `docs/backend-workers-spike-plan.md` を必ず読むこと。
- Workers 移行スパイクは `Spike 1 -> Spike 2 -> Spike 3` の順番を守り、飛ばさないこと。
- `Spike 3` の結果が出るまで `server/src/routes/chat.ts` `server/src/schemas/chat.ts` `server/src/errors/apiError.ts` と iOS コードを変更しないこと。
- ローカル検証は `.dev.vars`、デプロイ確認は `wrangler secret put` を使い、混同しないこと。
- `Spike 3` が失敗した場合は自己判断で進めず、Gemini REST API への直接 `fetch` に切り替えるか判断を待つこと。
