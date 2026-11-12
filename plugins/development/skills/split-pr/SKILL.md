---
name: split-pr
description: 大きすぎるPRを、GitHubのstacked PRに分割したいときに使う — 例:「PR #40を分割して」「split-pr 40」。review-prが付ける「PRを分割する」の指摘に対応するとき、fix-reviewからも呼ばれる。元のPRのコミットを、レビュー規約（review-rules.md）の上限に収まる区切りで分け、元のPRを一番下にしたstack（A ← B ← C）にする。元のブランチは履歴を書き換えてforce pushし、新しいPRはDraftで作ってレビューにはかけない。コミットの区切りで分けられなければ、分け方をユーザーに聞く。
---

# Split PR

見るべき差分が上限を超えたPRを、GitHubのstacked PRに分割する。分割するかどうかは、`review-pr`と`fix-review`が決める。

分割後の形は次のとおり。元のPRをA、新しいPRをB・Cと呼ぶ:

- A ← B ← C と数珠つなぎに積む。Aのbaseは変えない。Bのbase = Aのheadブランチ、Cのbase = Bのheadブランチ
- Aには、一番下の区切りまでのコミットが残る。B・Cには、その上のコミットが順に入る

## Step 1: PR番号と呼び出し元を確かめる

このskillは常にPR番号を必要とする。指定が無ければ求める — 現在のブランチから推測しない。

呼び出し元を控えておく。`fix-review`から呼ばれたときは、`fix-review`がその旨を伝える。それ以外はユーザーが直接起動したものとして扱う。

## Step 2: 手元の状態と道具を確かめる

```bash
gh pr view <N> --json number,title,body,baseRefName,headRefName,headRefOid
git fetch origin <baseRefName> <headRefName>
git branch --show-current
git rev-parse HEAD
git status --porcelain
gh stack --version
```

次のどれかに当たれば、停止してユーザーに伝える:

- 今いるブランチが`headRefName`ではない、または`git rev-parse HEAD`が`headRefOid`と一致しない — 分けるコミットを、PRと同じものに揃えるため。勝手にcheckoutしない
- `git status --porcelain`が何か出力した — Step 5で`git reset --hard`するので、作業中の変更を消さないため
- `gh stack --version`が失敗した — stackの作成に`gh stack`拡張（https://github.com/github/gh-stack ）を使うため。`gh extension install github/gh-stack`で入れてもらう

`baseRefName`・`headRefName`・`headRefOid`・タイトル・本文を控えておく。

**すでにstackに入っているPRの場合:** 分割してできたBが、さらに上限を超えていた場合などである。stackの形を調べる:

```bash
gh pr list --base <headRefName> --state open --json number,headRefName
gh pr list --head <baseRefName> --state open --json number,baseRefName
```

1つ目は、このPRの上に積んだPR（上のPR）、2つ目は、このPRの下のPR（下のPR）を返す。下のPRがあれば、さらにその`baseRefName`で同じように下へたどり、下のPRが無くなるまで繰り返す。一番下のPRの`baseRefName`がstackのtrunkである。上のPRも同じように上へたどる。どれかで2件以上返ってきたら、stackが枝分かれしているので、停止してユーザーに伝える。

このPRをBとすると、分割した後のstackは、A ← B1 ← B2 ← C の形にする（B1 = 分割した後のB）。次の2つは、別々に判定する:

- **下のPRがあるか:** あれば、このPRはBで、本文はB・C…の形に書き直す（Step 7）。無ければ、このPRがAで、本文は全体の説明として残す
- **上のPRがあるか:** あれば、Cのbaseを、このPRから作った一番上の新しいブランチに付け替え、stack全体をlinkし直す（Step 6）。Cのコミットは分割する前のBのコミットの上に積まれているので、Cをrebaseする必要はない

どちらも無ければ、以降の手順をそのまま進める。

## Step 3: 分け方を決める

分ける対象は、Aのbaseから分岐した地点より後のコミットである:

```bash
git merge-base origin/<baseRefName> HEAD
git log --reverse --format='%H %s' <分岐点>..HEAD
git log --merges --format='%H' <分岐点>..HEAD
```

コミットの区切りで、下から順に、上限に収まるだけのコミットをまとめていく。上限の値と測り方は、プラグインのルート（このskillのディレクトリの2つ上）にある`review-rules.md`の「PRの大きさの上限」に書いてある。この節を最後まで読み、そこに書かれた方法で、区切りごとに`<区切りの始まり>`から`<区切りの終わり>`までの差分を測り、上限と比べる。`review`と同じ規約で判定するので、上限の値や測り方はここに書き写さない。

Aの区切りの始まりは分岐点、B以降の区切りの始まりは1つ下の区切りの終わりのコミットになる。

1. 分岐点の次のコミットから順に、1つずつ区切りに足して測る
2. 足すと上限を超えるコミットが来たら、その手前で区切りを閉じ、そのコミットから次の区切りを始める
3. 最後のコミットまで繰り返す

測るスクリプトが失敗したら、同じコマンドを2回までリトライする。それでも失敗した場合は、ブランチもPRも変えずに停止し、測れなかったこととその理由をユーザーに伝える — 上限に収まるか分からないまま分けないため。

次のどれかに当たれば、コミットの区切りでは分けられない。分け方に設計判断が要るので、分割を始める前にユーザーに聞く:

- 1つのコミットだけで上限を超える（コミットの途中で分ける必要がある）
- 分岐点より後にマージコミットがある（履歴が一直線でないと、stackにできないため）
- 区切りが1つにしかならない（全体が上限に収まっていて、分ける必要が無い）

聞くときは、コミットの一覧と、それぞれの大きさを添える。ユーザーが分け方を示したらそれに従い、分割をやめると決めたら、ブランチもPRも変えずに終える。`fix-review`から呼ばれていた場合は、分割をやめたことを伝えて`fix-review`に戻る — `fix-review`は、その指摘を見送ったものとして、残りの指摘の対応を続ける。ユーザーが直接起動した場合は、そのまま終わる。

コミットの区切りで分けられた場合は、分け方をユーザーに見せずにStep 4へ進む。

## Step 4: 新しいブランチを作り、pushする

B・C…のブランチを、それぞれの区切りの終わりのコミットに作る。名前は`<headRefName>-2`、`<headRefName>-3`…とする（`x-2`を分割すると`x-2-2`になる）。同じ名前のブランチが手元かoriginにすでにあれば、停止してユーザーに伝える:

```bash
git branch <headRefName>-<k> <区切りの終わりのコミット>
git push -u origin <headRefName>-2 <headRefName>-3 ...
```

Aのブランチを書き換える前に、B・C…を作ってpushしておく — 書き換えの途中で止まっても、上のコミットが失われないようにするため。

pushが失敗した場合は、Step 5へ進まず停止してユーザーに伝える。Aはまだ書き換えていないことと、作ったブランチの消し方（originにpushできたものは`git push origin --delete <ブランチ>`、手元は`git branch -D <ブランチ>`）を添える — 一部だけ残ると、呼び直したときに「同じ名前のブランチがある」で止まるため。

## Step 5: 元のブランチを組み替える

Aのブランチを、Aの区切りの終わりまで戻し、force pushする:

```bash
git reset --hard <Aの区切りの終わりのコミット>
git push --force-with-lease=<headRefName>:<headRefOid> origin <headRefName>
```

`--force-with-lease`には、Step 2で控えた`headRefOid`を渡す — 確認の後に誰かがpushしていたら、それを消さずに失敗させるため。

pushが失敗した、または止められた場合は、停止してユーザーに伝える。次のことを添える:

- B・C…のブランチはpush済みで、PRはまだ無い
- Aのブランチは手元だけ戻してあり、originはまだ元のまま
- 続けるなら、ユーザーが上の`git push`を実行した後に「続けて」と伝えれば、この回のStep 6から進める（このskillを最初から呼び直すと、Step 2で手元とPRのheadが一致せず止まる）
- やめるなら、`git reset --hard <headRefOid>`で手元を戻し、B・C…のブランチを`git push origin --delete <ブランチ>`と`git branch -D <ブランチ>`で消す

## Step 6: stackにしてPRを作る

`gh stack link`で、AのPRとB・C…のブランチを下から順にstackにする。PRの無いブランチには、すぐ下のブランチをbaseにしたPRが作られる:

```bash
gh stack link --base <baseRefName> <N> <headRefName>-2 <headRefName>-3 ...
```

**上のPRがある場合（Step 2）:** 先に、上のPRのbaseを、このPRから作った一番上の新しいブランチに付け替える。そのうえで、stack全体を下から順に並べてlinkする。`--base`にはstackのtrunkを渡す:

```bash
gh pr edit <上のPRの番号> --base <一番上の新しいブランチ>
gh stack link --base <trunk> <下のPRたち> <N> <新しいブランチたち> <上のPRたち>
```

`--open`は付けない。

`gh stack link`が失敗したら、同じコマンドを2回までリトライする。それでも失敗した場合は、停止してユーザーに伝える。このときAはすでに切り詰めてforce push済みで、上のコミットはPRの無いブランチにしか無い。次のことを添える:

- Aはforce push済みで、AのPRからはB・C…の分の変更が消えている
- B・C…のブランチはpush済みで、PRは無い（一部だけ作られていれば、その番号）
- 続けるなら、失敗の原因（`gh stack`のエラー出力）を解決した後に「続けて」と伝えれば、この回のStep 6から進める
- やめるなら、`git reset --hard <headRefOid>`で手元を戻し、`git push --force-with-lease=<headRefName>:<Aの区切りの終わりのコミット> origin <headRefName>`でAを元に戻す。上のPRのbaseを付け替えていれば、`gh pr edit <上のPRの番号> --base <headRefName>`で戻す。stackが作られていれば`gh stack unstack <stackの番号>`で解除し（PRは閉じられない）、作られたPRがあれば閉じ、B・C…のブランチを`git push origin --delete <ブランチ>`と`git branch -D <ブランチ>`で消す

作られたPRの番号と状態を確かめる:

```bash
gh pr view <headRefName>-<k> --json number,url,isDraft,baseRefName
```

`isDraft`が`false`なら、`gh pr ready --undo <番号>`でDraftに戻す — 新しいPRは、このskillではレビューにかけないため（Step 8）。`baseRefName`が1つ下のブランチになっていなければ、停止してユーザーに伝える。

## Step 7: PRの本文を書く

本文はバッククォートや引用符を含みうるので、一時ファイル（リポジトリ外の一時ディレクトリ）に書き出し、`gh pr edit <番号> --title <タイトル> --body-file <一時ファイル>`で書き換える。

**issueの参照:** 分割するPR（このPR）の本文から`Closes #<issue>`と`Part of #<issue>`を探し、issueごとに次のとおり書く。本文にissueの参照が無ければ、どのPRにも書かない。上のPRがあれば、その本文の参照は変えない。

- `Closes #<issue>`なら、このPRから分けたPRのうち一番上のPRにだけ`Closes #<issue>`を書き、ほか（このPRを含む）は`Part of #<issue>`にする — stackの一番上のPRだけが`Closes`を持つようにするため。一番下から順にマージされるので、一番上がマージされたときに全部そろう
- `Part of #<issue>`なら、分けたPRをすべて`Part of #<issue>`にする — 元のPRがissueの一部だけを扱っていたので、分けたPRのどれもissueを閉じないため

**対応するREQ:** issueの本文に`REQ-<n>:`があれば、このPRが受け持つREQのそれぞれが、分けたPRのどれで満たされるかを決める。このPRの本文に「このPRで対応しているREQ:」の行があれば、受け持つREQはその行のREQだけで、ほかのREQは割り当て直さない。コミットのメッセージ、テストのメソッド名（`REQ_<n>_`）、差分から判断する。どのPRで満たされるか決められないREQがあれば、本文を書く前にユーザーに聞く — 分割した後の`review-pr`は、PRごとにここで決めたREQだけを要件としてレビューするので、割り当てを誤ると、ほかのPRで満たされるREQが「足りない」と指摘されるため。issueの参照が無い、またはREQが無ければ、この割り当てはしない。

**A:** 本文は作業全体の説明として残す — 元は1つのPRなので、全体の設計を示す場所を1か所に残し、分けたPRがぶつ切りにならないようにするため。issueの参照を上のとおりに直し、末尾に次の節を足す:

```
## 分割

このPRは大きさの上限を超えたので、stacked PRに分割した。全体の説明はこの本文に残している。

このPRで対応しているREQ: <AのREQ。割り当てをしなかった場合は、この行を省く>

| PR | 対応するREQ | コミット |
|---|---|---|
| #<A>（このPR） | REQ-1, REQ-2 | <短いSHA> <件名>（区切りに入ったコミットを並べる） |
| #<B> | REQ-3 | … |
```

割り当てをしなかった場合は、表の「対応するREQ」の列を省く。

下のPRがあるPR（Step 2）を分割した場合は、このPRの本文の「全体の説明は #<A> にある」が指すPRが、全体の説明を持つAである。このPRのタイトルと本文は、新しいPRと同じ規則で書き直し、Aの本文の`## 分割`の表に、新しいPRの行を足す（このPRの行のREQとコミットも直す）。Aのタイトルは変えない。このPRの本文に「全体の説明は #<A> にある」や「このPRで対応しているREQ:」が無ければ（手で組んだstackなど）、どのPRが全体の説明を持つかと、このPRが受け持つREQを、本文を書く前にユーザーに聞く。

**B・C…:** タイトルは、そのPRに入ったコミットが何をするかを表すものにする。stackの何番目かは書かない — 順番はstackの構造で分かり、番号を入れると分割のたびに振り直しが要るため。本文は次のとおり:

```
<issueの参照>

## 概要
<このPRに入ったコミットが何をするかの説明。コミットとその差分から書く>

## 分割

全体の説明は #<A> にある。このPRは、#<A> を分割したstackの1つである。

このPRで対応しているREQ: <このPRのREQ。割り当てをしなかった場合は、この行を省く>

## コミット
- <短いSHA> <件名>
```

## Step 8: 次に進む

**`fix-review`から呼ばれた場合:** 再レビューはせず、新しいPRの番号とURLを渡して`fix-review`に戻る。指摘のうち、どれが新しいPRへ移ったかは`fix-review`が判定する。

**ユーザーが直接起動した場合:** `development:review-pr`をAの番号`<N>`で呼び出す。分割した後の差分が上限内に収まったかを、`review-pr`が測り直す。

どちらの場合も、新しいPRはレビューにかけずDraftのまま置く。新しいPRの番号とURLをユーザーに伝え、レビューは別に頼むよう添える。
