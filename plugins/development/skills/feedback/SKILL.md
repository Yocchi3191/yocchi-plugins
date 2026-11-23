---
name: feedback
description: ユーザーがdevelopmentプラグイン自体（submit、review、test-infra-setup、designなどのskillやスクリプト）について不満・戸惑い・機能要望を口にしたときに使う——自分自身のプロジェクトのコードについての話ではない場合に限る。自然な言い回しにも反応する。例:「developmentのreviewが使いにくい」「submitにこの機能が欲しい」「developmentのここが不便」。developmentへのフィードバックを起票するよう明示的に呼ばれた場合も使う。状況をヒアリングし、Yocchi3191/yocchi-pluginsの既存GitHub issueとの重複を確認した上で、ユーザーの明示的な承認を得てから新規issueを作成する（または既存issueにコメントする）——承認を得る前に起票することは決してない。
---

# Feedback

development プラグイン自体（`submit` / `review` / `test-infra-setup` / `design` などのskillやスクリプト）への要望・クレームを受け付け、`Yocchi3191/yocchi-plugins` リポジトリのGitHub issueとして記録する。**扱うのは development というツール自体へのフィードバックだけ** — ユーザー自身のプロジェクトの仕様やバグは対象外なので、そちらの話であれば通常通り会話や別skillに任せる。

## Step 1: 種別と状況をヒアリング

確認すべき情報:

- 種別: バグ / 機能要望 / 使い勝手の不満
- 具体的な状況: 何をしようとしたか・何が起きたか・期待していた動作
- バグの場合は再現手順も

最初のメッセージにこれらの情報がすでに含まれているなら、それをそのまま使い、聞き直さない。欠けている項目だけを、まとめて一度に尋ねる。曖昧な訴え（「使いにくい」「イマイチ」など）だけで終わらせず、具体的な状況まで掘り下げること — 具体性がないとissueとして役に立たない。ただし掘り下げは「聞き方を工夫してまとめて聞く」であって、一問一答で一項目ずつ往復することではない。

仕様書のような箇条書きに固める必要はない。自然な文章のままでよい — フィードバックは仕様ではなく訴えなので、無理に falsifiable な一文へ切り詰めない。

## Step 2: 重複チェック

既存の似たissueがあれば、二重報告や議論の分散を防ぐために先に見つける。

```bash
gh issue list --repo Yocchi3191/yocchi-plugins --search "<keywords>" --state all
```

類似issueが見つかったら、番号とタイトルを提示し、「既存issueにコメント追加」か「新規issue作成」かを呼び出し元に選んでもらう。見つからなければそのままStep 3へ。

## Step 3: 内容を提示し、承認を得る

`issue-template.md`（このskillのディレクトリ内）を埋めたタイトル・本文案を呼び出し元に見せる。**明示的な承認を得るまでissueは作成しない・コメントも投稿しない。** 内容の修正依頼があれば反映してから再度見せる。

## Step 4: ラベルを用意する

種別ごとに専用ラベルを分け、`機能要望`と`使い勝手の不満`が同じラベルに埋もれて見分けられなくならないようにする:

- バグ → `feedback` + `bug`
- 機能要望 → `feedback` + `enhancement`
- 使い勝手の不満 → `feedback` + `usability`

`bug`・`enhancement` は標準ラベルとして通常存在する。`feedback`・`usability` は存在しない場合が多いので、なければ先に作る:

```bash
gh label create feedback --repo Yocchi3191/yocchi-plugins --color "c5def5" --description "developmentプラグイン利用者からのフィードバック"
gh label create usability --repo Yocchi3191/yocchi-plugins --color "fef2c0" --description "使い勝手・体験に関する指摘"
```

すでに存在する場合はこのコマンドはエラーになるだけなので無視してよい。

## Step 5: 起票する

タイトルの先頭に種別プレフィックス（`[バグ]` / `[機能要望]` / `[使い勝手]`）を付け、一覧（`gh issue list`など）で種別が一目でわかるようにする。

新規issue:

```bash
gh issue create --repo Yocchi3191/yocchi-plugins \
  --title "[バグ|機能要望|使い勝手] <title>" \
  --body "$(cat <<'EOF'
<issue-template.md を埋めた本文>
EOF
)" \
  --label feedback --label <bug|enhancement|usability>
```

既存issueへの追記（Step 2で選ばれた場合）:

```bash
gh issue comment <N> --repo Yocchi3191/yocchi-plugins --body "$(cat <<'EOF'
<今回のフィードバック内容>
EOF
)"
```

作成・コメント後、issueのURLを伝えて完了。
