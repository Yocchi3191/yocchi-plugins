# 未対応の指摘を集める

指摘はPR上の3か所にあり、対応済みかの状態と合わせて1回のクエリで取る（100件超のPRは想定しない。`{owner}`・`{repo}`は`gh`が埋める）。

```bash
gh api graphql -F owner='{owner}' -F repo='{repo}' -F number=<N> -f query='
query($owner:String!,$repo:String!,$number:Int!){
  repository(owner:$owner,name:$repo){
    pullRequest(number:$number){
      comments(first:100){nodes{id url isMinimized body}}
      reviews(first:100){nodes{id url isMinimized state body}}
      reviewThreads(first:100){nodes{id isResolved comments(first:100){nodes{url path line body}}}}
    }
  }
}'
```

- `comments`: PR全体へのコメント（`review-pr`の結果もここ）
- `reviews`: 人が提出したレビューの本文
- `reviewThreads`: 差分の行に付いたスレッド

**未対応:** `comments`・`reviews`は`isMinimized`が`false`、`reviewThreads`は`isResolved`が`false`。時刻では判定しない（取得後に付いたものや、途中で止まった回の指摘が、次の回に正しく残るため）。

**自分の投稿は拾わない:** このskillは投稿の1行目に目印を入れる。対応報告は`<!-- fix-review -->`、スレッドへの個別の返信は`<!-- fix-review:reply -->`。1行目がどちらかのコメントは拾わない（「含む」ではなく「1行目」で判定する。引用しただけのコメントを取りこぼさないため）。投稿者では見分けない（どちらもユーザーのアカウントで投稿されるため）。

拾うのは指摘と質問だけ。お礼や相づちは拾わず、印も付けない。

**スレッドは最後のコメントまで読む:** 最後がこのskillの返信（`:reply`）で、その後に人のコメントが無ければ、返信は済んでおりresolveだけ残っている。Step 6では返信し直さず、resolveだけする。返信の後に人のコメントがあれば、それを新しい指摘・質問として扱う。

**回数を数える:**

- 対応の回数: 1行目が`<!-- fix-review -->`のコメントの件数（見出しの`<n>`に使う）
- 再レビューの回数: 1行目が`<!-- fix-review -->`で、2行目が`<!-- fix-review:rereview -->`のコメントの件数。質問に答えただけの回と、軽いものだけの回は数えない。分割した回は数え、「分割済み」とした回は数えない
