# レビュー手順: ローカル環境のソースを対象にしたレビュー

- 呼び出すもの
  - /code-review
  - /verify
  - /simplify
- /code-reviewの引数
  - medium
  - --fix
  - 今いるブランチの `origin/<デフォルトブランチ>...HEAD`
    - デフォルトブランチ名は `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` で調べる。先に `git fetch origin` で最新にする。
    - 今いるブランチがデフォルトブランチそのものなら、レビュー対象が無いので、その旨を伝えて終わる。
