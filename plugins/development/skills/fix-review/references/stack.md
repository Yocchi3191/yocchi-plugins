# stackのrebase（Step 3・Step 7）

stackの履歴が一直線でなくなると、rebaseするまでstackをマージできない（出典: https://docs.github.com/en/pull-requests/reference/stacked-pull-requests ）。そこで、下のPRが進んだときは自分をrebaseし、自分がpushしたときは上のPRをrebaseする。

## Step 3: 下のPRが先に進んでいたら、自分をrebaseする

このPRがstackの途中にあり（baseブランチが、ほかの開いているPRのheadブランチ）、そのbaseにこのPRが含まない新しいコミットがあるときだけ、仕分けの前にrebaseする。下のPRの `fix-review` はStep 7で上のPRもrebaseするが、それが止まって人に任された場合に備える。

```bash
gh pr view <N> --json baseRefName
gh pr list --head <baseRefName> --state open --json number
git fetch origin <baseRefName>
git merge-base --is-ancestor origin/<baseRefName> HEAD
```

2つ目がPRを1件も返さなければ、stackの途中ではないのでrebaseしない（`main` などが進んだだけのPRはここでは扱わない）。4つ目が成功すれば、baseは先に進んでいないのでrebaseしない。どちらでもなければ、`--no-trunk` を付けて（trunkには触れない）rebaseしてpushする。

```bash
gh stack checkout <N>
（stackの各ブランチをoriginに揃える）
gh stack rebase --downstack --no-trunk
gh stack push
```

`gh stack checkout` は、手元にstackの情報が無ければGitHubから取ってくる。

## stackの各ブランチをoriginに揃える

`--no-trunk` はfetchも手元のブランチの更新もしない。手元が古いまま `gh stack push` すると、originの新しいコミットを巻き戻してしまう。rebaseの前に、`gh stack view --json` の `branches` のうち、`isMerged` が `false` で、対象より下のもの（Step 3は今のブランチより下、Step 7は上）を1つずつoriginと比べる。

```bash
git fetch origin
git rev-parse <ブランチ> origin/<ブランチ>
git merge-base --is-ancestor <ブランチ> origin/<ブランチ>
git fetch origin <ブランチ>:<ブランチ>
```

- 同じコミットなら、何もしない
- 手元がoriginの祖先なら、手元が遅れているだけなので、4つ目でfast-forwardする
- それ以外（手元が進んでいる、分岐している、fast-forwardに失敗）は、どちらが正しいか決められないので、停止して伝える

## 止まったとき（Step 3）

- rebaseがコンフリクトした、または別のworktreeの変更などで止まった: `gh stack rebase --abort` で戻して停止し、伝える
- `gh stack checkout` が失敗した、または入力を求めた: そこで停止する
- pushが失敗した、止められた: 停止し、手元はrebase済みでoriginは元のままであることと、`git reset --hard <headRefOid>` でこのPRの手元を戻せることを伝える。下のブランチも手元でrebaseされているかもしれないので、`gh stack view --json` の `head`（rebase前の値）で戻せることも添える
- rebaseとpushのあと、`git branch --show-current` が `headRefName` と違えば `git switch <headRefName>` で戻す
- rebaseしたら、Step 6の対応報告にその旨を書く。指摘の行番号はrebase前のhead（`headRefOid`）のファイルを指すので、仕分けでは、そのコミットのファイルで該当行を確かめる

## Step 7: 自分がpushしたら、上のPRをrebaseする

今回このPRにpushし（Step 3のrebaseを含む）、このPRのheadをbaseにする開いているPRがあれば、再レビューの前に上のPRをrebaseする。`--no-trunk` を付け、先にfetchする。分割した直後は手元にstackの情報が無いので `gh stack checkout` で取る。

```bash
git fetch origin
gh stack checkout <N>
（上のPRのブランチをoriginに揃える）
gh stack rebase --upstack --no-trunk
gh stack push
```

止まったとき: コンフリクトや別のworktreeの変更なら、先に `gh stack rebase --abort` で戻す。揃えられなかった、`gh stack checkout` が失敗した・入力を求めた、pushが失敗した、のいずれも、そこでやめる。上のPRのrebaseが済んでいないことを伝え、rebaseは人に任せる。rebaseとpushのあと、`git branch --show-current` が `headRefName` と違えば `git switch <headRefName>` で戻す。この後の再レビューやreadyへの切り替えは、そのまま進めてよい。
