---
name: review-pr
description: ユーザーが特定のPRのレビューを求めている場合に使う。PRからBASE_SHA/HEAD_SHA/要件/概要を解決して`development:review`に委譲し、結果をPRにコメントする。Critical・Importantの指摘があればDraftのまま`development:fix-review`へ引き継ぎ、無ければ（Minorだけでも）`gh pr ready`でreadyにする。submitやfix-reviewからも呼ばれる。直さずレビューだけが欲しいときは`development:review`を使う。
---

# Review PR

`development:review`の薄いアダプタ。PR形式の入力への変換と、PR状態の変更（ready／`fix-review`への引き継ぎ）だけを担う。細則（コマンド、issue参照、分割PR、分割指摘の文面）は `references/details.md` を読む。

## Step 1: PR番号とチェックアウト

PR番号は必須。無ければ求める（ブランチから推測しない）。PRのheadブランチを最新でチェックアウトしておく（一致しなければ`review`が止まる）。

## Step 2: 差分の範囲を決める

BASE_SHA = PRのbaseとheadの分岐点（`git merge-base`）、HEAD_SHA = headの最新コミット。デフォルトブランチではなくPRのbaseから求めるので、stacked PRでも動く。`gh pr view`が失敗したら、部分的なデータで進めず停止して報告する。

## Step 3: PR本文からPLAN_OR_REQUIREMENTSを解決する

Step 2で取得したPR本文からissue参照を探す:

```
/(?:Closes|Part of) #(\d+)/i
```

同じ本文内に`Closes #N`と`Part of #M`の両方が存在する場合は`Closes`を優先する — このPRが完全に解決することを意図しているissueを名指ししており、より具体的なシグナルだからである。

- **マッチした場合:** そのissueの本文を取得し、PLAN_OR_REQUIREMENTSとして使う:

```bash
gh issue view <matched-N> --json body -q .body
```

このコマンドが失敗した場合（issueが削除された、番号が誤っている、非公開でアクセスできない等）、処理を止めたりPLAN_OR_REQUIREMENTSを空のままにしたりせず、下記の「マッチしない場合」と同様にPR自身のタイトルと本文にフォールバックし、参照先issueを取得できなかった旨を最終報告に記載する。

PR本文に`## 分割`の節があり、その中に「このPRで対応しているREQ:」の行があれば、そのPRは`split-pr`で分割したstackの1つである。issueの本文に加えて、`## 分割`の節をPLAN_OR_REQUIREMENTSに添え、「このPRの要件は、この行に書かれたREQだけである。ほかのREQは、stackのほかのPRで満たす」と書き添える — issueのREQをすべてこのPRの要件にすると、ほかのPRで満たすREQが「足りない」と指摘されるため。

- **マッチしない場合:** 他の方法でissueを探しに行かない。代わりにPR自身のタイトルと本文（Step 2で取得済み）をPLAN_OR_REQUIREMENTSとして使う。`Closes`/`Part of`参照の無いPRは正常な状態であり、エラーではない。

## Step 4: DESCRIPTIONを解決する

PRが何を行うかの簡潔な要約。タイトルと本文（Step 2）から推測する — 1〜2文程度。

## Step 5: development:reviewに委譲する

`development:review`を呼び出し、上記で解決した4つの値（BASE_SHA、HEAD_SHA、PLAN_OR_REQUIREMENTS、DESCRIPTION）を渡す。これにより`review`はStep 0のショートカットを取り、レビュー役の起動へ直行する — `review`に「現在の作業ブランチ」からこれらを再算出させてはならず、ここから直接レビュー役を起動してもいけない。必ず`review`を経由させ、実際のレビューディスパッチを担う場所を一箇所に保つ。

## Step 6: レビュー結果に応じて行動する

`review`がレビュー結果を返さずに止まった場合（チェックアウト中のコミットがPRのheadと違う、など）は、`review`が伝えた理由をそのままユーザーに報告して停止する。PRへのコメント投稿も状態の変更もしない。

レビュー結果が返ってきたら、`review`が添えた差分の大きさを見る。上限を超えていた場合は、レビュー役の指摘とは別に、次の指摘をIssuesに1件足す。`<規約の…>`の部分は、プラグインのルート（このskillのディレクトリの2つ上）にある`review-rules.md`の「PRの大きさの上限」から埋める。重さはImportantで固定する — `fix-review`はCritical・Importantを直したときだけ再レビューを頼むので、分割した後に、上限内に収まったかをこのskillで測り直させるため:

```
**Important** PRを分割する
- 場所: PR全体
- 何が問題か: 見るべき差分が上限を超えている（<行数>行・<バイト数>バイト。上限は<規約の行数>行・<規約のバイト数>バイト。`.gitattributes`で`linguist-generated`が指定されたファイルと、`review`がテストとして数えなかったファイルは数えていない）
- なぜ問題か: <規約の「根拠」を1〜2文に要約したもの。出典のURLを添える>
- 修正案: 単体で動く単位か、レビューしやすい単位でPRを分ける。全体を同時にマージしないと動かない場合は、stacked PRに分けてまとめてマージする。どこで分けるかに設計判断が要る場合や、上限を少し超える程度で分けると動かなくなる場合は、分けるか見送るかをユーザーが判断する
```

指摘を足したら、Assessmentもそれに合わせて「マージ可能ではない」側にする。

そのうえで、PR状態を変更する前にその結果をPRへ投稿する:

```bash
gh pr comment <N> --body "$(cat <<'EOF'
<reviewが報告したレビュー結果: Strengths/Issues/Assessment（上限を超えていれば、上の指摘を足したもの）と、差分の大きさの1行（`review`が「数えなかったテスト」の行を添えていれば、その行も）>
EOF
)"
```

`review`は上限を超えていると「このままPRにすると、review-prが分割を求めます」という警告文も添えるが、これはPRがまだ無いときに向けた文なので、コメントには載せない。載せるのは差分の大きさの1行（と、`review`が添えた「数えなかったテスト」の行）だけで、上限超過は上の指摘で伝える。「数えなかったテスト」の行に、テストかどうか判断できなかったファイルが並んでいれば、その行はそのまま載せる — PRの上で、ユーザーが答えられるようにするため。

このコマンドが失敗した場合（権限不足、PRが裏で閉じられた、一時的なAPIエラー等）は、投稿できたかのように`gh pr ready`や`fix-review`の呼び出しへ進まず、処理を止めてユーザーに報告する。

まずこのコメントを投稿し、その後で結果に応じて動く — こうすることで、実際にPR状態を変える`gh pr ready`（下記）とは別に、PRには常にレビュー内容の記録が残る:

- **差分の大きさを測れなかった場合:** `review`はリトライしたうえで「差分の大きさを測れなかった」を添えて返す。このときは、コメントに大きさの1行の代わりにその旨を載せて投稿し、指摘の有無にかかわらず、`gh pr ready`も`fix-review`の呼び出しもせずに停止する。測れなかったことと、その理由をユーザーに伝える — 上限を超えているか分からないまま、PRをreadyにしないため。

- **指摘が一件も無い場合:** コメント投稿後、対象PRをready for reviewに切り替える:

```bash
gh pr ready <N>
```

その上で、PRのURLと簡潔なレビューサマリをユーザーに報告する。

- **指摘が一件でもある場合**（重さを問わない — Minorだけでも）: コメント投稿後、PRをDraftのままにし（`gh pr ready`は実行しない）、続けて`development:fix-review`をPR番号`<N>`で呼び出す。指摘への対応、再レビューの要否の判断（このskillをもう一度呼ぶ）、readyへの切り替えは、すべて`fix-review`が担う。このskill自身は指摘を直さない — レビューする側が読み取り専用であるという前提を保つため。
