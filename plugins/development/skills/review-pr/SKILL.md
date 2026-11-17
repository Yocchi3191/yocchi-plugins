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

## Step 3: 要件と概要を決める

PR本文の`Closes #N`（無ければ`Part of #M`）のissue本文を要件とする。無い・取得失敗ならPRのタイトルと本文を使う（エラーにしない）。`## 分割`の節がある分割PRは、「このPRで対応しているREQ」だけをこのPRの要件とする。概要はタイトルと本文から1〜2文で書く。

## Step 4: reviewに委譲する

4つの値（BASE_SHA、HEAD_SHA、要件、概要）を渡して`development:review`を呼ぶ。**`review`を必ず経由し**、ここから直接レビュー役を起動しない。`review`が結果を返さず止まったら、理由を報告して停止する（コメントも状態変更もしない）。

## Step 5: 結果をPRに反映する

1. 差分が上限を超えていれば、「PRを分割する」をImportantの指摘として足し、Assessmentをマージ不可側にする
2. **状態を変える前に**、結果を `gh pr comment` で投稿する。失敗したら止まる
3. 結果に応じて動く:
   - **差分の大きさを測れなかった:** ready にも`fix-review`にもせず停止し、理由を伝える
   - **Critical・Importantが1件でもある:** Draftのまま、`development:fix-review`をPR番号で呼ぶ。自分では指摘を直さない（レビュー側は読み取り専用）
   - **Critical・Importantが無い（無指摘、またはMinorだけ）:** `gh pr ready <N>`でreadyにする。Minorはコメントに残るだけで直さない。PRのURLと要約を報告する
