---
name: review
description: ユーザーがPRの存在を前提とせず、現在の作業ブランチをレビューしてほしいときに使う。たとえば "reviewして"、"今の変更をレビューして"、"コードレビューして"。会話の文脈を持たないレビュー用サブエージェントを起動し、ブランチの分岐点から最新コミットまでの差分をレビューし、差分の大きさがレビュー規約（review-rules.md）の上限を超えていれば警告を添える。baseはデフォルトブランチのほか、stacked PRの積み上げ元の親ブランチにもできる。PRをready for reviewに変換することは決して行わない — それはreview-prとfix-reviewの役目である（review-prはPR番号が渡されたときにこのskillをラップする）。
---

# Review

ローカルの作業ブランチでも、PRのようにリモートから来る変更でも、同じようにレビューできるskill。**実装した本人の思い込みを持ち込まないため、会話の文脈を持たないレビュー役に任せる**（これがこのskillの核）。`submit` が変更をPRに変換するのに対し、`review` はレビューするだけで、作業の途中、PRがまだ無い段階、セカンドオピニオンが欲しいときに使える。`review-pr` は、入力がPR番号の場合に、このskillの上に被せる薄いアダプタである。

差分の書き出しと大きさの測り方（Step 5・6）の細則は `references/prepare.md` を読む。

## Step 0: 4つの値は既に揃っているか

BASE_SHA・HEAD_SHA・PLAN_OR_REQUIREMENTS・DESCRIPTIONがすべて渡されていれば（例: `review-pr` がPRのbase/headと本文から解決して渡す）、Step 1〜3は飛ばしてStep 4へ進む。Step 1〜3は、何も渡されなかったときに、現在のブランチから値を作るための手順である。

## Step 1: BASE_SHAとHEAD_SHAを決める

`git branch --show-current` が空（detached HEAD）なら、名前付きブランチが要ると伝えて停止する。

baseは次の順で決める。

1. ユーザーが明示したブランチ
2. stacked PRの積み上げ元の親ブランチ（積み上げ中と分かるときは、親をユーザーに確認して使う）。親のコミットが差分に混ざらず、レビューする差分が小さく読みやすくなる
3. リポジトリのデフォルトブランチ（`gh repo view --json defaultBranchRef -q .defaultBranchRef.name`）

現在のブランチがbaseそのものなら、レビュー対象が無いと伝えて停止する。`BASE_SHA` は `git merge-base HEAD origin/<base>`、`HEAD_SHA` は `git rev-parse HEAD`。PRの有無に関わらず、SHAをユーザーに尋ねたり、PRを探しに行ったりしない。

## Step 2: PLAN_OR_REQUIREMENTSとDESCRIPTION

issue番号が渡されていれば、その本文（`gh issue view <N> --json body -q .body`）を要件にする。無ければ、issue番号を探しに行かず、`git log` と差分から、このブランチが達成しようとしていることを推定して要件とする（issue番号が無いのは正常）。概要は、同じ材料から推定した実装内容の1〜2文。

## Step 3: チェックアウトを確かめる

レビュー役は前後の文脈をチェックアウト中のファイルから読む。`git rev-parse HEAD` が `HEAD_SHA` と違えば、レビュー対象をチェックアウトして更新してから呼び直すよう伝えて停止する（このskillは作業中の変更を巻き込むので、checkoutも更新もしない）。コミットしていない変更が `git status --porcelain --untracked-files=no` にあっても停止せず、Step 6でレビュー役に、読むファイルがコミット時点と違うかもしれないと伝える。

## Step 4: 差分を書き出し、大きさを測る

レビュー役はgitを実行できないので、差分とコミットログを事前にファイルに書き出す。**差分が空なら、レビュー役を起動せず停止する**（空を「指摘なし」と受け取った `review-pr` が、PRをreadyにしてしまうため）。差分の大きさは `review-rules.md` の規約で測る。**上限を超えても停止せず、中身のレビューは必ず行う。** 測れなければ、その旨を添えてレビューを続ける。手順は `references/prepare.md`。

## Step 5: レビュー役を起動する

Agentツールで `development:reviewer` を1つ起動する。レビュー役はファイルを読む道具だけを持つので、コードやgitの状態を変えられない。観点と出力形式はエージェント定義にあるので、重ねて指示しない。プロンプトには次を渡す: リポジトリのパス（`git rev-parse --show-toplevel`）、BASE_SHAとHEAD_SHA、差分ファイルとコミットログファイルのパス、概要、要件、（コミットしていない変更があれば）その旨。

## Step 6: 結果を報告する

レビュー役のStrengths / Issues / Assessmentをそのまま報告し、差分の大きさの1行と、数えなかったテストの行を添える（書式は `references/prepare.md`）。上限を超えていれば「このままPRにすると、review-prが分割を求めます」と1行添える。**大きさは警告にとどめ、Issuesには入れない**（指摘として扱うのは `review-pr`）。

レビュー結果がクリーンでも、**`gh pr ready`、`gh pr merge` など、PRの状態を変えるコマンドは一切実行しない**。PRをreadyにするのは `review-pr` と `fix-review` の責務である。
