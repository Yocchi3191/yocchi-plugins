# レビュー手順: PRのソースを対象にしたレビュー(1回目)

呼び出すもの

1. 独自観点レビュアー（`development:reviewer`）。`references/prepare.md` に従って入力を用意して渡す
2. /code-review
3. /simplify

/code-reviewの引数

- medium
- --fix
- --comment
- PR番号(ex. PR#123 なら、123)

独自観点レビュアーの結果の扱い

- `レビュー作業: 中断` を返したら、2と3は実行せず、サマリ投稿へ進む。
- 指摘は修正せず、サマリにそのまま載せる。直すかどうかは人間が決める。
