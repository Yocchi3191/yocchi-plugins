# レビュー手順: ローカル環境のソースを対象にしたレビュー

- 差分（`origin/<base>...HEAD`）が空なら、指摘事項なしとして終了する
- 呼び出すもの
  - /code-review
  - /verify
  - /simplify
- /code-reviewの引数
  - medium
  - --fix
  - `origin/<base>...HEAD`
- baseは、先に `git fetch origin` で最新にしたうえで、次の順で決める
  1. ユーザーが明示したブランチ
  2. stacked PRの親ブランチ（積み上げ中と分かるときは、親をユーザーに確認して使う）
  3. デフォルトブランチ（`gh repo view --json defaultBranchRef -q .defaultBranchRef.name`）
