---
name: submit
description: 現在の作業ツリーの変更をコミットしてDraft PRを開きたいときに使う — 例:「submitして」「今の変更をPRにして」。未コミットの変更を推定メッセージでコミットし、head/baseを自動検出してpushし、pr-template.mdからDraft PRを作成する。designのADRメモはPR本文に展開して削除し、implの作業メモは本文の材料にする。PRを作成したら、確認せずに続けてreview-prでレビューする。PRをready for reviewにはしない（review-prとfix-reviewの役目）。
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

**baseブランチ:** ユーザーがbaseブランチを明示した場合は、その値をそのまま`<base-branch>`として使う。明示されていない場合は、リポジトリのデフォルトブランチを検出してそれを使う:

```bash
gh repo view --json defaultBranchRef -q .defaultBranchRef.name
```

現在のブランチが`<base-branch>`そのものである場合、submitする対象が無い旨をユーザーに伝えて停止する — PRにはbaseと異なるheadブランチが必要である。

pushする前に、新しく送るものがあるかを確認する:

```bash
git rev-list --count '@{u}' 2>/dev/null && git rev-list --count '@{u}..HEAD'
```

- **最初のコマンドが失敗する**（upstreamが未設定 — ブランチが一度もpushされていない）: pushする。
- **2番目のコマンドが`0`を出力する**（ローカルHEADがupstreamより先のコミットを持たない）: pushをスキップする — 送るものが無い。
- **それ以外:** pushする。

```bash
git push -u origin <head-branch>
```

## Step 4: テンプレートを埋めてDraft PRを作成する

このskill自身のディレクトリ（この`SKILL.md`と同じ場所）にある`pr-template.md`を読み込み、プレースホルダを埋める。PR本文の構造はこのテンプレートだけを正とし、ここに重複して書かない。Step 1で作業メモを読んでいれば、その内容は`<SUMMARY>`・`<STRUCTURE>`・`<FLOW>`・`<ADR>`などを埋める材料として使う。作業メモの文面をそのまま貼らず、テンプレートの該当欄に合う形に整理して書く（ADRメモは対象外で、`<ADR>`欄の規則に従う）:

- `<ISSUE_NUMBER>`: 今回の呼び出しにissue番号が渡されていれば、それを埋めて`Closes #<ISSUE_NUMBER>`行を残す。issue番号が渡されていなければ、その行ごと削除する — 何も続かない中途半端な`Closes #`を残さないこと、また、issue番号が無いことをエラー扱いにしないこと。
- `<SUMMARY>`: コミットされた変更が何をするものかを、diff（およびissue番号が渡されていればissue本文）から推定した簡潔な要約。作業メモに更新したREQの記録があれば、どのREQをなぜ更新したかも書く。
- `<ADR>`: Step 1で読み込んだADRメモの内容をそのまま入れる。ADRメモが無く、作業メモに設計の判断があれば、その判断を整理して入れる。どちらも無ければ、`## 設計判断`セクションごと削除する — 空の見出しを残さないこと。
- `<SCREENSHOT>`: 利用者が目にする画面（UI）の見た目が変わる変更なら「（人間が貼る）」と書いて残す。画面が変わらなければ、この行ごと削除する。
- `<STRUCTURE>` / `<FLOW>`: コミットされた変更から推定した、このPRの構造（クラス図）と導線をMermaidで書く。導線はクラスをまたぐ流れならシーケンス図、1つの処理内の分岐が主役ならフローチャートにする。図が必要なほど大きくない変更は、文章1〜2行にしてよい。片方だけ書くことが無ければ、その項目だけ削除する。どちらも書くことが無ければ、`## 実装の設計`セクションごと削除する — 空の見出しを残さないこと。
- `<TEST_METHODS>`: PR全体の差分（`git fetch origin <base-branch>`したうえでの`git diff origin/<base-branch>...HEAD`。Step 3で決めた`<base-branch>`を使い、手元のbaseが古くても他人の変更が混ざらないようにする。コミット済みの分も含めるため、Step 2の`git diff --cached`ではない）から、追加・変更したテストメソッド名を抜き出し、REQ番号順に箇条書きにする。メソッド名に`REQ_<n>_`（`<n>`は数字。命名規則は`issue_<番号>_REQ_<n>_…`）を含まないものは末尾に「（REQ番号なし）」、複数のREQ番号を含むもの（命名規則は1メソッドに1つのREQ）は末尾に「（複数REQ）」と添えて載せる — 黙って落とさないこと。テストが1つも無ければ「なし」と書く。
- `<UNCOVERED_REQ>`: issue本文（下の「PRタイトルは…」の項で取得する）の`REQ-<n>:`のうち、`[人間確認]`が付いていないものを、`<TEST_METHODS>`のメソッド名に含まれるREQ番号と、番号`<n>`で突き合わせ（issue側は`REQ-<n>`、メソッド名側は`REQ_<n>_`と表記が違う。`REQ_1`が`REQ_10`に一致しないよう、`REQ_<n>_`と後ろの`_`まで含めて照合する）、対応が無いREQ番号を列挙する。「（REQ番号なし）」「（複数REQ）」のテストは突き合わせに含まれず、実際にはテストがあるREQが列挙されうる。その場合は列挙のまま出し、レビューでメソッド名の修正を促す。無ければ「なし」。issue番号が渡されていない場合と、issue本文に`REQ-<n>:`が1つも無い場合は、この行ごと削除する。
- `<TEST_APPROACH>`: PR全体の差分（`<TEST_METHODS>`と同じ）のテストコードから読み取れる作り方（スタブ、入力のエミュレートなど）を1〜3行で書く。
- `<HUMAN_CHECKS>`: issue本文の`[人間確認]`付きREQを、`- [ ] REQ-<n>: …`の形でそのまま列挙する。確認方法はissue側にあるので、ここには書かない。`[人間確認]`付きREQが無ければ、`## 動作確認`セクションごと削除する。

PRタイトルは要約から、あるいはissue番号が渡されていればissueのタイトルから導く。issue番号が渡されていれば、REQの突き合わせに使うため、本文もここで取得する。取得に失敗したら、`gh pr create`の前に停止し、PRはまだ無い（コミット・pushは済んでいる）とユーザーに伝える:

```bash
gh issue view <N> --json title,body
```

PRの本文はバッククォートや引用符を含みうる複数行のmarkdownで、ユーザーが書いたADRメモもそのまま入るため、シェルに埋め込まず一時ファイル（リポジトリ外の一時ディレクトリ）に書き出してから渡す:

```bash
gh pr create --draft --base <base-branch> --title "<title>" --body-file <埋めたテンプレートを書いた一時ファイル>
```

作成後、`--body-file` 用の一時ファイルは削除する。作成されたPRのURLをユーザーに報告する。ここで`gh pr ready`を実行することは絶対にない — レビュー可能状態への変換は`review-pr`と`fix-review`の責務である（Step 6で`review-pr`へ引き継ぐ）。

`gh pr create`が失敗した場合は、Step 5へ進まず停止する — ADRメモの内容がPRに残っていないまま削除してしまうのを防ぐため。

## Step 5: ADRメモを削除する — PR作成に成功した場合のみ

ADRメモが無ければこのステップはスキップする。

内容はPR本文に残ったので、`<adr-path>`を削除する。gitで追跡されているか（過去に誤ってコミットされていないか）で扱いが変わる:

```bash
git ls-files --error-unmatch -- ':(top)<adr-path>'
```

- **失敗する（未追跡）:** ファイルを削除するだけでよい。
- **成功する（追跡済み）:** ブランチ上からも消すため、削除をコミットしてpushする:

```bash
git rm -f -- ':(top)<adr-path>'
git commit -m "ADRメモを削除（内容はPR本文に展開済み）"
git push
```

## Step 6: レビューへ引き継ぐ

Step 5のコミットやpushが失敗した場合は、Step 6へ進まずユーザーに伝えて停止する — 手元とPRのheadがずれたままレビューを始めても、`fix-review`が手元の状態の確認で止まるため。

PRの作成に成功したら（Step 5があればその後で）、ユーザーに確認せず、続けて`development:review-pr`を作成したPRの番号で呼び出す。以降、指摘があれば`review-pr`が`fix-review`へ引き継ぎ、指摘が無くなればどちらかがready for reviewに切り替える。

PRを作るたびにユーザーがレビューを頼み直す手間をなくすため、この引き継ぎは省かない。
