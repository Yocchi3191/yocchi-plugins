---
name: submit
description: 現在の作業ツリーの変更をコミットしてDraft PRを開きたいときに使う — 例:「submitして」「今の変更をPRにして」。未コミットの変更を推定メッセージでコミットし、head/baseブランチを自動検出してpushし、リポジトリ側のPRテンプレート（無ければpr-template.md）からDraft PRを作成する。designがこのブランチのADRメモを残していれば、PR本文に展開してメモを削除する。PRを作成したら、確認せずに続けてreview-prでレビューする。PRをready for reviewに変換することは自分ではしない — それはreview-prとfix-reviewの役目である。
---

# Submit

作業ツリーの内容を、pushされたブランチとDraft PRに変換する。

## Step 1: headブランチとADRメモを検出する

headブランチは現在チェックアウトされているブランチそのもの:

```bash
git branch --show-current
```

これが何も出力しない場合（detached HEAD）、submitにはPRを開くための名前付きブランチが必要である旨をユーザーに伝えて停止する — まずブランチをcheckoutまたは作成してもらう。

次に、`design` が残したADRメモ（`<ドキュメント置き場>/adr/<head-branch>.md`）を探す。リポジトリルート（`git rev-parse --show-toplevel`）の `docs/adr/<head-branch>.md`、`doc/adr/<head-branch>.md` の順に確認し、最初に見つかったものを`<adr-path>`（リポジトリルートからの相対パス）とする。どちらも無ければADRメモ無しとして扱う — エラーではない。

`<adr-path>`が見つかった場合は、その内容を読み込んでおく（Step 4でPR本文に使う）。このメモはPR本文に展開した後に削除する一時ファイルであり、コミットには含めない。

## Step 2: 未コミットの変更をコミットする

以下のpathspecはリポジトリルート基準（`:/`・`:(top,...)`）で書く — カレントディレクトリがサブディレクトリでも、リポジトリ全体を対象にし、ADRメモだけを除外するため。`<adr-path>`が無い場合は各コマンドの`':(top,exclude)<adr-path>'`を省く。

```bash
git status --porcelain -- ':/' ':(top,exclude)<adr-path>'
```

- **出力なし（クリーン）:** コミット対象なし — そのままStep 3へ進む。空コミットは絶対に作成しない。
- **何らかの出力がある（staged・unstaged・untrackedのいずれか）:** ADRメモ以外のすべてをstageし、変更内容から推定したメッセージでコミットする — メッセージをユーザーに尋ねることは絶対にしない:

```bash
git add -A -- ':/' ':(top,exclude)<adr-path>'
git diff --cached
```

推定するメッセージが「何が変わったか」を正しく反映するように（ファイル数や行数だけでなく）、`--stat`だけでなくstaged diff全体を読むこと — diffが大きすぎて全文を読めない場合のみ、切り詰めのガードとして`git diff --cached --stat`にフォールバックする。何が変わったかを簡潔に説明するコミットメッセージを推定し（なぜ変えたかはPR本文の役割なのでここには書かない）、コミットする:

```bash
git commit -m "<推定したメッセージ>"
```

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

### 4-1: 使うテンプレートを決める

リポジトリ側のPRテンプレートを優先する。リポジトリルート基準で次を順に探し（ファイル名の大文字小文字は区別しない）、最初に見つかったものを使う:

1. `.github/pull_request_template.md`
2. `pull_request_template.md`
3. `docs/pull_request_template.md`

- **見つかった:** 4-2へ進む。
- **どれも無いが、`.github/PULL_REQUEST_TEMPLATE/` ディレクトリにテンプレートがある:**
  - 1つだけ: それを使って4-2へ進む。
  - 複数: 自動で選ばず、候補のファイル名を示してユーザーにどれを使うか選んでもらい、選ばれたものを使って4-2へ進む。
- **どれも無く、`.github/PULL_REQUEST_TEMPLATE/` も空または無い:** このskill自身のディレクトリ（この`SKILL.md`と同じ場所）にある`pr-template.md`をフォールバックとして使う。4-3へ進む。

### 4-2: リポジトリ側テンプレートを埋める

テンプレートの構造（見出し・順序・チェックリスト）は変えず、見出しやコメントの意図に沿って各欄を埋める:

- issue番号が渡されていれば、`Closes #<ISSUE_NUMBER>`を本文の先頭に足す（テンプレートに該当欄があればそこに入れる）。渡されていなければ足さない。
- 概要・変更内容に当たる欄は、コミットされた変更の要約（diff、およびissue番号が渡されていればissue本文から推定）で埋める。
- ADRメモがある場合、設計・背景に当たる欄があればそこへ、無ければ末尾に`## 設計判断`を足して、内容をそのまま入れる。ADRメモが無ければ足さない。
- 埋められない欄は空のまま残さず「該当なし」と書く。

### 4-3: フォールバックテンプレート（`pr-template.md`）を埋める

PR本文の構造はこのテンプレートだけを正とし、ここに重複して書かない:

- `<ISSUE_NUMBER>`: 今回の呼び出しにissue番号が渡されていれば、それを埋めて`Closes #<ISSUE_NUMBER>`行を残す。issue番号が渡されていなければ、その行ごと削除する — 何も続かない中途半端な`Closes #`を残さないこと、また、issue番号が無いことをエラー扱いにしないこと。
- `<SUMMARY>`: コミットされた変更が何をするものかを、diff（およびissue番号が渡されていればissue本文）から推定した簡潔な要約。
- `<ADR>`: Step 1で読み込んだADRメモの内容をそのまま入れる。ADRメモが無ければ、`## 設計判断`セクションごと削除する — 空の見出しを残さないこと。

### 4-4: PRを作成する（どちらのテンプレートでも共通）

PRタイトルは要約から、あるいはissue番号が渡されていればissueのタイトルから導く:

```bash
gh issue view <N> --json title -q .title
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
