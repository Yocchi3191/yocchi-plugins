---
name: review
description: ユーザーがPRの存在を前提とせず、現在の作業ブランチをレビューしてほしいときに使う。たとえば "reviewして"、"今の変更をレビューして"、"コードレビューして"。会話の文脈を持たないレビュー用サブエージェントを起動し、ブランチの分岐点から最新コミットまでの差分をレビューし、差分の大きさが上限（400行・32,000バイト）を超えていれば警告を添える。PRをready for reviewに変換することは決して行わない — それはreview-prとfix-reviewの役目である（review-prはPR番号が渡されたときにこのskillをラップする）。
---

# Review

PRの存在を前提とせず、現在の作業ブランチの差分に対してコードレビューを実行する。これは`development:submit`の"レビュー版"にあたるskillで、`submit`が変更をPRに変換するのに対し、`review`は変更をレビューするだけである — 作業の途中、PRがまだ存在しない段階、あるいはセカンドオピニオンが欲しいときにいつでも使える。`development:review-pr`は、入力が「現在のブランチ」ではなくPR番号である場合に、このskillの上に被せる薄いアダプタである。

## Step 0: BASE_SHA/HEAD_SHA/PLAN_OR_REQUIREMENTS/DESCRIPTIONは既に揃っているか？

この呼び出しの時点でこれら4つがすべて解決済みとして渡されている場合(例: `development:review-pr`がPRの実際のbase/headとbodyから解決して渡すケース) — Step 1〜3は完全にスキップし、渡された値のままStep 4に進む。以下のStep 1〜3は、何も渡されなかったときに「現在のブランチ」からこれらの値を導出するためだけに存在する。

## Step 1: 現在のブランチからBASE_SHAとHEAD_SHAを算出する

```bash
git branch --show-current
```

これが何も出力しない場合(detached HEAD)は、reviewには名前付きブランチが必要であることをユーザーに伝えて停止する。

```bash
gh repo view --json defaultBranchRef -q .defaultBranchRef.name
```

現在のブランチがこのデフォルトブランチ*そのもの*である場合は、レビュー対象が無いことをユーザーに伝えて停止する — レビューには独自のコミットを持つブランチが必要である。

ここで、`<default-branch>`をデフォルトブランチ名に置き換えたうえで:

```bash
git merge-base HEAD origin/<default-branch>
git rev-parse HEAD
```

- `BASE_SHA` = `git merge-base`の出力 — 現在のブランチがリポジトリのデフォルトブランチから分岐した地点。
- `HEAD_SHA` = 現在のブランチの最新コミット(`git rev-parse HEAD`)。

このブランチにPRが存在するかどうかに関わらず、無条件にこれを行う — これらのSHAをユーザーに尋ねたり、先にPRの存在を要求したり、PRを探しに行ったりすることは決してしない。

**スコープの制約:** これは常にリポジトリの*デフォルト*ブランチとの差分を取る。スタックされたブランチ(例: デフォルトブランチではなく別のfeatureブランチを元にしたブランチ)の場合、報告される差分にはそのベースブランチ自身のコミットも含まれてしまう — non-defaultなベースを検出・対象化する手段は無い。これはバグではなく既知の制約として扱うこと: 異なるベースが必要な呼び出し元(例: 別のPRにスタックされたPRをレビューする`review-pr`)は、このStepに頼らず、自分自身でBASE_SHAを解決してStep 0経由で渡す必要がある。

## Step 2: PLAN_OR_REQUIREMENTSを決定する

- **この呼び出しにissue番号が渡されている場合:** そのissueの本文を取得し、PLAN_OR_REQUIREMENTSとして使う:

```bash
gh issue view <N> --json body -q .body
```

- **issue番号が渡されていない場合:** issue番号を探しに行かない。コミットログと差分の内容(`git log <BASE_SHA>..<HEAD_SHA>`、`git diff <BASE_SHA>..<HEAD_SHA>`)から、このブランチが何を達成しようとしているかの簡潔な要約を推定し、それをPLAN_OR_REQUIREMENTSとして使う。ここでissue番号が無いのは正常な状態であり、エラーではない。

## Step 3: DESCRIPTIONを決定する

Step 2で使ったのと同じコミットログ/差分から推定した、実装内容の簡潔な要約 — 1〜2文。

## Step 4: チェックアウト中のコミットがHEAD_SHAと一致するか確かめる

レビュー役は差分の前後の文脈を、チェックアウト中のファイルを読んで確認する。そのため、チェックアウト中のコミットがレビュー対象と違うと、差分と文脈が食い違う。

```bash
git rev-parse HEAD
```

出力が`HEAD_SHA`と違う場合は、レビュー対象のブランチをチェックアウトし、最新の状態に更新（pull）してから呼び直すようユーザーに伝えて停止する。このskillがチェックアウトや更新をすることはしない — 作業中の変更を巻き込みかねないため。

コミットしていない変更があるかも確かめる:

```bash
git status --porcelain --untracked-files=no
```

出力があっても停止はしない（作業の途中でも使えるskillなので）。代わりにStep 7で、文脈として読むファイルがコミット時点と違う可能性があることをレビュー役に伝える。

## Step 5: 差分とコミットログをファイルに書き出す

レビュー役はgitコマンドを実行できないので、差分とコミットログを事前にファイルへ書き出して渡す。書き出し先は`.git`の中の決まったパスで、毎回上書きする（作業ツリーを汚さず、ファイルも溜まらない）:

```bash
set -e
out="$(git rev-parse --absolute-git-dir)/development-review"
mkdir -p "$out"
git diff -M <BASE_SHA>..<HEAD_SHA> > "$out/diff.patch"
git log <BASE_SHA>..<HEAD_SHA> > "$out/log.txt"
test -s "$out/diff.patch"
echo "$out"
```

どれかのコマンドが失敗した場合、または差分が空の場合は、レビュー役を起動せず、理由をユーザーに伝えて停止する — 空の差分をレビューさせると「指摘なし」が返り、呼び出し元の`review-pr`がPRをreadyにしてしまうため。

## Step 6: 差分の大きさを測る

人が1回で集中して読める量には目安がある。レビューが1時間以内に終わると不具合を見つけやすく、1時間に収まるのは200〜400行程度のPRだと言われている（出典: https://zenn.dev/isana/articles/ideal-size-of-pull-request-and-why ）。このskillでは上限を次の2つとし、どちらかを超えたら「上限超過」とする:

- 行数: 追加と削除の行の合計が400行
- バイト数: 追加と削除の行の中身の合計が32,000バイト（1行80桁 × 400行）

バイト数も見るのは、Markdownのように1行が1段落になる差分だと、行数が少なくても読む量が多いため。全角文字はUTF-8で3バイトになり、表示幅（2桁）より1.5倍多く数えられる。日本語の多い差分には少し厳しめに働くが、意図した側に倒している。

```bash
git diff -M <BASE_SHA>..<HEAD_SHA> -- . ':(exclude,attr:linguist-generated)' ':(exclude,attr:linguist-generated=true)' \
  | LC_ALL=C awk '/^diff --git /{h=0} /^@@/{h=1; next} h && /^[-+]/{n++; b+=length($0)-1} END{printf "lines=%d bytes=%d\n", n, b}'
```

- 自動生成ファイル（lockfile、Unityの`.meta`など、人が直接編集しないファイル）は数えない。どれが自動生成かは、リポジトリの`.gitattributes`で`linguist-generated`が指定されているかで決める。GitHubがPRの差分で最初から折りたたむのと同じ指定である。このskillは独自の除外リストを持たない — 数えたくないファイルがあれば、リポジトリの`.gitattributes`に書いてもらう。
- `.gitattributes`はチェックアウト中のものが読まれる。Step 4でチェックアウト中のコミットが`HEAD_SHA`と一致することは確認済みである。
- リネームしただけのファイルは`-M`で差分が0行になるので、数に入らない。削除したファイルは数に入る。

結果（行数・バイト数・上限超過かどうか）を控えておく。上限を超えていてもここでは停止せず、Step 7に進む — 中身のレビューは常に行い、大きさの判定はStep 8で結果に添えるだけにする。分割を見送るとユーザーが判断した場合でも、中身のレビューを受けずに進むことが無いようにするため。

## Step 7: レビュー役を起動する

Agentツールで`development:reviewer`エージェントを1つ起動する。会話の文脈を持たない新しいエージェントに任せるのは、実装した本人の思い込みを持ち込まずに差分を見させるためである。レビュー役はファイルを読む道具しか持たないので、コードやgitの状態を変えることはできない。

プロンプトには次の値を渡す。レビューの観点と出力形式はエージェント定義に書かれているので、ここで重ねて指示しない:

- リポジトリのパス: `git rev-parse --show-toplevel`の出力
- レビュー範囲: `BASE_SHA`と`HEAD_SHA`
- 差分ファイルのパス: Step 5で出力されたパスの下の`diff.patch`
- コミットログファイルのパス: Step 5で出力されたパスの下の`log.txt`
- 変更の概要: Step 3の結果
- 要件: Step 2の結果
- （Step 4でコミットしていない変更があった場合のみ）作業ツリーにコミットしていない変更があり、読んだファイルの内容がコミット時点と違う可能性があること

## Step 8: 結果を報告する — PRの状態は決して変更しない

レビュー役のStrengths / Issues / Assessmentをそのままユーザーに報告する。あわせて、Step 6で測った差分の大きさを1行で添える:

```
差分の大きさ: <行数>行・<バイト数>バイト（上限: 400行・32,000バイト）
```

上限を超えていた場合は、続けて「このままPRにすると、review-prが分割を求めます」と1行添える。PRの存在を前提としない`review`では、大きさは警告にとどめ、指摘（Issues）には入れない。指摘として扱うのは`review-pr`である。

レビューの結果がどうであれ — Critical/Importantな指摘が一件も無いクリーンな結果であっても — このskillは`gh pr ready`、`gh pr merge`、その他PRの状態を変更するコマンドを一切実行しない。Draft PRをready for reviewに変換するのは`review-pr`と`fix-review`の責務であり、このskillの責務ではない。`review`はPRの存在すら前提としないため、PRの状態について一切関与しない。
