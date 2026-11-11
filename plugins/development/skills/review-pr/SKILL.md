---
name: review-pr
description: ユーザーが特定のPRのレビューを求めている場合に使う — 例:「PR #40をレビューして」「review-pr 40」。PR自体からBASE_SHA/HEAD_SHA/PLAN_OR_REQUIREMENTS/DESCRIPTIONを解決し、実際のレビューは`development:review`に委譲する。差分の大きさがレビュー規約（review-rules.md）の上限を超えていれば、PRの分割をImportantの指摘として足す。レビュー結果はPR状態を変更する前に`gh pr comment`でPRへ投稿する。指摘が無ければ`gh pr ready`でPRをready for reviewに変換し、指摘があればDraftのまま`development:fix-review`に対応を引き継ぐ。submitやfix-reviewからも続けて呼ばれる。指摘があるとfix-reviewが修正とpushまで行うので、直さずにレビューだけが欲しい場合は`development:review`を使う。
---

# Review PR

入力が「現在の作業ブランチ」ではなくPR番号である場合の、`development:review`に対する薄いアダプタ。レビュー本体は`review`が担い、このskillはそれをPR形式の入力に合わせるアダプタと、PRが存在して初めて意味を持つロジック（指摘が無ければready for reviewへ切り替え、あれば`fix-review`へ引き継ぐ処理）だけを担う。

## Step 1: PR番号は必須

このskillは常にPR番号を必要とする。指定が無ければ求める — 現在のブランチから推測することは絶対にしない（それは`review`の仕事であり、このskillの仕事ではない）。

また、PRのheadブランチを最新の状態でチェックアウトしておく必要がある。レビュー役は前後の文脈をチェックアウト中のファイルから読むためで、一致しなければ`review`が止まる。

## Step 2: PRからBASE_SHAとHEAD_SHAを解決する

```bash
gh pr view <N> --json baseRefName,headRefName,title,body
```

その出力から実際の`baseRefName`・`headRefName`の値を取得し、以下のすべてのコマンド内の`<baseRefName>`/`<headRefName>`をそれらの値に置き換える — 以下の2つのブロックはどちらもこの値に依存している。

両方のrefをfetchし、ローカルのgitがdiffを取れるようコミットを用意する:

```bash
git fetch origin <baseRefName> <headRefName>
```

```bash
git merge-base origin/<baseRefName> origin/<headRefName>
git rev-parse origin/<headRefName>
```

- `BASE_SHA` = `git merge-base`の出力 — PRのheadブランチが実際のbaseブランチから分岐した地点（リポジトリのデフォルトブランチとは限らない — これにより、デフォルトブランチのみを対象とする`review`自身の自己算出とは異なり、別のPRに積み上げたPRに対しても`review-pr`が正しく動作する）。
- `HEAD_SHA` = PRのheadブランチの最新コミット（`git rev-parse origin/<headRefName>`）。

**適用範囲についての補足:** これはPRのheadブランチが`origin`上に存在することを前提としている（`submit`でpushしたブランチなら常に成立する）。フォーク由来のPRのheadブランチはこの方法では解決できない — この点はスコープ外とし、`submit`が`origin`へのpushについて置いている前提と同じである。

`gh pr view <N>`が失敗した場合（該当PRが無い、リポジトリ指定が誤っている等）、処理を止めてユーザーに報告する。部分的なデータのまま処理を進めてはならない。

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
- 何が問題か: 見るべき差分が上限を超えている（<行数>行・<バイト数>バイト。上限は<規約の行数>行・<規約のバイト数>バイト。`.gitattributes`で`linguist-generated`が指定されたファイルは数えていない）
- なぜ問題か: <規約の「根拠」を1〜2文に要約したもの。出典のURLを添える>
- 修正案: 単体で動く単位か、レビューしやすい単位でPRを分ける。全体を同時にマージしないと動かない場合は、stacked PRに分けてまとめてマージする。どこで分けるかに設計判断が要る場合や、上限を少し超える程度で分けると動かなくなる場合は、分けるか見送るかをユーザーが判断する
```

指摘を足したら、Assessmentもそれに合わせて「マージ可能ではない」側にする。

そのうえで、PR状態を変更する前にその結果をPRへ投稿する:

```bash
gh pr comment <N> --body "$(cat <<'EOF'
<reviewが報告したレビュー結果: Strengths/Issues/Assessment（上限を超えていれば、上の指摘を足したもの）と、差分の大きさの1行>
EOF
)"
```

`review`は上限を超えていると「このままPRにすると、review-prが分割を求めます」という警告文も添えるが、これはPRがまだ無いときに向けた文なので、コメントには載せない。載せるのは差分の大きさの1行だけで、上限超過は上の指摘で伝える。

このコマンドが失敗した場合（権限不足、PRが裏で閉じられた、一時的なAPIエラー等）は、投稿できたかのように`gh pr ready`や`fix-review`の呼び出しへ進まず、処理を止めてユーザーに報告する。

まずこのコメントを投稿し、その後で結果に応じて動く — こうすることで、実際にPR状態を変える`gh pr ready`（下記）とは別に、PRには常にレビュー内容の記録が残る:

- **指摘が一件も無い場合:** コメント投稿後、対象PRをready for reviewに切り替える:

```bash
gh pr ready <N>
```

その上で、PRのURLと簡潔なレビューサマリをユーザーに報告する。

- **指摘が一件でもある場合**（重さを問わない — Minorだけでも）: コメント投稿後、PRをDraftのままにし（`gh pr ready`は実行しない）、続けて`development:fix-review`をPR番号`<N>`で呼び出す。指摘への対応、再レビューの要否の判断（このskillをもう一度呼ぶ）、readyへの切り替えは、すべて`fix-review`が担う。このskill自身は指摘を直さない — レビューする側が読み取り専用であるという前提を保つため。
