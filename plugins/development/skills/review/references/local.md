# レビュー手順: ローカル環境のソースを対象にしたレビュー

- 差分（下記の範囲）が空なら、指摘事項なしとして終了する
- 呼び出すもの
  - /code-review
  - /verify
  - /simplify
- /code-reviewの引数
  - medium
  - --fix
  - 今いるブランチの `origin/<デフォルトブランチ>...HEAD`
    - デフォルトブランチ名は `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` で調べる。先に `git fetch origin` で最新にする。
