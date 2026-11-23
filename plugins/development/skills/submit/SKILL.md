---
name: submit
description: 現在の作業ツリーの変更をコミットしてDraft PRを開きたいときに使う — 例:「submitして」「今の変更をPRにして」。未コミットの変更を推定メッセージでコミットし、head/baseを自動検出してpushし、pr-template.mdからDraft PRを作成する。designのADRメモはPR本文に展開して削除し、implの作業メモは本文の材料にする。PRを作成したら、確認せずに続けてreviewでレビューする。PRをready for reviewにはしない（人間が行う）。
---

# Submit

作業ツリーの内容をDraft PRに変換する。ADRメモと作業メモの細則は `references/memo.md` を読む。

## Step 1: headブランチとメモを検出する

headは現在のブランチ（`git branch --show-current`）。空（detached HEAD）なら、名前付きブランチが要ると伝えて停止する。

`design` が残したADRメモを探す: リポジトリルート（`git rev-parse --show-toplevel`）の `docs/adr/<head-branch>.md`、`doc/adr/<head-branch>.md` の順に見て、最初に見つかったものを `<adr-path>`（ルートからの相対）とする。無ければADRメモ無し（エラーではない）。内容は読み込み、Step 4でPR本文に使う。**このメモは削除する一時ファイルなので、コミットしない。**

`impl` の作業メモも読む（置き場の決め方と使い方は `references/memo.md`）。

## Step 2: 未コミットの変更をコミットする

pathspecはリポジトリルート基準（`:/`・`:(top,...)`）で書く。`<adr-path>` が無ければ除外を省く。

```bash
git status --porcelain -- ':/' ':(top,exclude)<adr-path>'
```

- **出力なし:** コミット対象なし。Step 3へ進む。**空コミットは絶対に作らない。**
- **出力あり:** ADRメモ以外をすべてstageし、変更内容から推定したメッセージでコミットする。**メッセージをユーザーに尋ねない。**

```bash
git add -A -- ':/' ':(top,exclude)<adr-path>'
git diff --cached
git commit -m "<推定したメッセージ>"
```

`--stat` ではなくdiff全体を読む（大きすぎるときだけ `--stat`）。書くのは「何が変わったか」で、なぜ変えたかはPR本文の役割。

## Step 3: baseブランチを決めてpushする

baseは次の順で決める。

1. ユーザーが明示したブランチ
2. stacked PRの積み上げ元の親ブランチ（ユーザーが親PR・親ブランチに触れたとき。親をユーザーに確認する。分からなければ3へ）
3. リポジトリのデフォルトブランチ（`gh repo view --json defaultBranchRef -q .defaultBranchRef.name`）

headがbaseそのものなら、submitする対象が無いと伝えて停止する。

pushの前に、送るものがあるか確かめる: `git rev-list --count '@{u}' 2>/dev/null && git rev-list --count '@{u}..HEAD'`。最初のコマンドが失敗（upstream未設定）ならpushする。2番目が `0` ならpushしない。それ以外はpushする。

```bash
git push -u origin <head-branch>
```

## Step 4: テンプレートを埋めてDraft PRを作成する

同じディレクトリの `pr-template.md` を読み、プレースホルダを埋める。PR本文の構造と各欄の埋め方は、テンプレートの注釈だけを正とし、ここに重ねて書かない。作業メモの文面はそのまま貼らず、該当欄に合う形に整理する。

- **issue番号:** 渡されていれば `Closes #<N>` を残し、`gh issue view <N> --json title,body` で本文を取得する（タイトルと、REQの突き合わせに使う）。取得に失敗したら、`gh pr create` の前に停止し、PRはまだ無い（コミット・pushは済み）と伝える。渡されていなければ、その行ごと削除する（エラーにしない）
- **差分:** `git fetch origin <base-branch>` のうえで `git diff origin/<base-branch>...HEAD`
- **PRタイトル:** 要約、またはissueのタイトルから導く

本文はバッククォートや引用符を含みうるので、シェルに埋め込まず、リポジトリ外の一時ファイルに書いて渡す。

```bash
gh pr create --draft --base <base-branch> --title "<title>" --body-file <一時ファイル>
```

作成後、一時ファイルを削除し、PRのURLを報告する。**`gh pr ready` は絶対に実行しない**（レビュー可能状態への変換は人間が行う）。`gh pr create` が失敗したら、Step 5へ進まず停止する（ADRメモの内容がPRに残らないまま消さないため）。

## Step 5: ADRメモを削除する（PR作成に成功した場合のみ）

ADRメモが無ければスキップする。内容はPR本文に残ったので削除する。gitで追跡されているかで扱いが変わる:

```bash
git ls-files --error-unmatch -- ':(top)<adr-path>'
```

- **失敗（未追跡）:** ファイルを削除するだけ
- **成功（追跡済み）:** 削除をコミットしてpushする（`git rm -f -- ':(top)<adr-path>'`、メッセージ「ADRメモを削除（内容はPR本文に展開済み）」、`git push`）

## Step 6: レビューへ引き継ぐ

Step 5のコミットやpushが失敗したら、ユーザーに伝えて停止する（手元とPRのheadがずれたままレビューを始めると、`review` が止まるため）。

成功したら、**ユーザーに確認せず**、続けて `development:review` を呼ぶ。この引き継ぎは省かない。
