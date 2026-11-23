---
name: split-pr
description: 大きすぎるPRを、GitHubのstacked PRに分割したいときに使う — 例:「PR #40を分割して」「split-pr 40」。レビューで付いた「PRを分割する」の指摘に対応するとき、fix-reviewからも呼ばれる。元のPRのコミットを、レビュー規約（review-rules.md）の目安に収まる区切りで分け、元のPRを一番下にしたstack（A ← B ← C）にする。元のブランチは履歴を書き換えてforce pushし、新しいPRはDraftで作ってレビューにはかけない。コミットの区切りで分けられなければ、分け方をユーザーに聞く。
---

# Split PR

見るべき差分が上限を超えたPRを、stacked PRに分割する。分割するかどうかは `fix-review` が決める。元のPRをA、新しいPRをB・Cと呼び、A ← B ← C と積む（Aのbaseは変えない。Bのbase = Aのhead、Cのbase = Bのhead）。

**一番大事な規則: 分け方に設計判断が要るときは、分割を始める前に、必ずユーザーに聞く。** 失敗時の戻し方とstackの途中のPRの扱いは `references/recovery.md`、PR本文の書き方は `references/body.md` を読む。

## Step 1: PR番号と呼び出し元

PR番号は必須（無ければ求める。ブランチから推測しない）。`fix-review` から呼ばれたかを控える。

## Step 2: 手元の状態と道具を確かめる

```bash
gh pr view <N> --json number,title,body,baseRefName,headRefName,headRefOid
git fetch origin <baseRefName> <headRefName>
git branch --show-current && git rev-parse HEAD && git status --porcelain
gh stack --version
```

次のどれかなら、停止して伝える: 今いるブランチが `headRefName` でない、またはHEADが `headRefOid` と違う（勝手にcheckoutしない）／未コミットの変更がある（Step 5で `git reset --hard` するため）／`gh stack` が無い（`gh extension install github/gh-stack`）。すでにstackの途中のPRなら、上下のPRをたどって形を調べる（`references/recovery.md`）。

## Step 3: 分け方を決める

分岐点（`git merge-base origin/<baseRefName> HEAD`）より後のコミットを、下から順に、上限に収まるだけまとめて区切る。**上限の値と測り方は、プラグインのルートの `review-rules.md` の「PRの大きさの上限」を最後まで読み、その方法で測る**（書き写さない）。数えないテストのファイルは、`review` と同じ手順（`git -c core.quotepath=false diff --name-status -M`。リネームは新旧両方のパス）で全体で1回決め、区切りの測定にも同じものを渡す。分け方を示すときは、数えなかったファイルと、判断できなかったファイル（テストかを聞く）を添える。

測れなければ、2回までリトライし、それでも駄目ならブランチもPRも変えずに停止して理由を伝える（上限内か分からないまま分けない）。

次の場合は、コミットの区切りでは分けられない。**分割の前に、コミットの一覧と大きさを添えてユーザーに聞く**: 1つのコミットだけで上限を超える／分岐点より後にマージコミットがある／区切りが1つにしかならない。ユーザーが分け方を示したら従い、やめると決めたら、何も変えずに終える（`fix-review` から呼ばれていたら、やめたと伝えて戻る）。区切りで分けられたときは、ユーザーに見せず進む。

## Step 4: 新しいブランチを作り、pushする

B・C…のブランチを、区切りの終わりのコミットに作る。名前は `<headRefName>-2`、`-3`…（同名のブランチが手元かoriginにあれば停止）。**Aを書き換える前に**、B・C…を作ってpushする（書き換えの途中で止まっても、上のコミットを失わないため）。

```bash
git branch <headRefName>-<k> <区切りの終わりのコミット>
git push -u origin <headRefName>-2 <headRefName>-3 ...
```

## Step 5: 元のブランチを組み替える

```bash
git reset --hard <Aの区切りの終わりのコミット>
git push --force-with-lease=<headRefName>:<headRefOid> origin <headRefName>
```

`--force-with-lease` には、Step 2の `headRefOid` を渡す（確認の後に誰かがpushしていたら、消さずに失敗させる）。

## Step 6: stackにしてPRを作る

```bash
gh stack link --base <baseRefName> <N> <headRefName>-2 <headRefName>-3 ...
```

`--open` は付けない。新しいPRは **Draftのまま**にする（`isDraft` が `false` なら `gh pr ready --undo <番号>`）。baseが1つ下のブランチになっているか確かめる。上にPRが積んである場合は、先にそのbaseを付け替える（`references/recovery.md`）。

## Step 7: PRの本文を書く

issueの参照（`Closes` はstackの一番上のPRにだけ）、対応するREQの割り当て、Aの `## 分割` の表を書く。割り当てを決められなければ、ユーザーに聞く。`references/body.md`。

## Step 8: 次に進む

`fix-review` から呼ばれたなら、新しいPRの番号とURLを渡して戻る。直接起動なら、`development:review` を呼ぶ。新しいPRはレビューにかけず、Draftのまま置く。新しいPRの番号とURLを伝え、レビューは別に頼むよう添える。
