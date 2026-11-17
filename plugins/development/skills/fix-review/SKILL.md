---
name: fix-review
description: PRに付いたレビュー指摘に対応したいときに使う — 例:「レビュー対応して」「PR #40の指摘を直して」「fix-review 40」。review-prが指摘ありと判断したときにも、review-prから続けて呼ばれる。PRのコメントからまだ対応していない指摘を集め（review-prの結果も人のコメントも対象）、直し方が1つに決まるものは確認せずに直し、判断が要るものだけユーザーに聞く。直したらコミット・pushし、対応内容をPRに返信する。Critical・Importantを直したときはreview-prで再レビューし（繰り返しは2回まで）、Minorだけならready for reviewに切り替える。review-prが求めるPRの分割は、分割するとユーザーが決めたら、ほかの指摘を直す前にsplit-prに渡し、分割した後に再レビューする。
---

# Fix Review

PRに付いたレビュー指摘に対応する。レビューそのもの（指摘を出すこと）は`review-pr`の責務であり、このskillは出された指摘を直す側だけを担う。

## Step 1: PR番号は必須

このskillは常にPR番号を必要とする。指定が無ければ求める — 現在のブランチから推測しない。

## Step 2: まだ対応していない指摘を集める

PR全体のコメント・レビュー本文・行コメントのスレッドから、未対応の指摘と質問を集める。自分の過去の投稿は拾わない。未対応かどうかの判定基準は`references/collect.md`に従う。1件も無ければ、伝えて停止する。

## Step 3: 仕分ける

仕分ける前に、今いるブランチがPRのheadブランチであり、その最新コミットと一致していて、未コミットの変更が無いことを確かめる:

```bash
gh pr view <N> --json headRefName,headRefOid
git branch --show-current
git rev-parse HEAD
git status --porcelain
```

ブランチ名か最新コミットのどちらかが一致しない場合、または`git status --porcelain`が何か出力した場合は、停止してユーザーに伝える — このあと指摘の正誤や「直っている」かを手元のコードで判定するので、レビューされたのと違うコードやpushしていないコミットを根拠にしないため。また、別のブランチに修正を積んだり、ユーザーの作業中の変更を修正のコミットに巻き込んだりするのを防ぐため。勝手にcheckoutもしない（作業ツリーに未コミットの変更があると巻き込むため）。

指摘は信じず、コードを読んで正しさを確かめ、「直す」「対応しない」「判断が要る」「直っている」「答える」に分ける。「判断が要る」は設計判断・仕様の判断・手戻りになりそうなものだけで、それ以外は聞かずに自動で進める。**重さ**は、reviewが付けたCritical・Importantは重い。重さの無い指摘（人のコメントなど）は、ほかの指摘と比べて見積もる。**迷ったら重い側。** 軽いものは直さず、Step 6で「対応しません」と理由を返す。

## Step 4: 判断が要るものをまとめて聞く

直し始める前に**まとめて**聞く。「PRを分割する」の指摘は先に聞き、分割を済ませてから残りを聞く。別issueの起票は承認後。

## Step 5: 直して、コミット・pushする

**1件ごとにコミット**する（その指摘のファイルだけadd）。すべて直したらテストを実行し、通ってからpushする。テストが落ちた、またはpushに失敗したら**停止する。PRには「直した」と返信しない**。

## Step 6: PRに返信し、対応済みの印を付ける

次の順で進める。投稿・操作に失敗したら、同じ操作を2回までリトライする — 通信の瞬断やAPIの一時的なエラーなら、これで通るため。それでも失敗した場合（認証切れ、権限不足、PRが閉じられた、など）は、Step 7へ進まず停止し、どこまで済んだか（返信・印を付けたもの）と、対応報告の下書きをユーザーに渡す — 印を付けた後に止まると、次の回は拾う指摘が無く、対応報告を出せないため。

本文はどれもバッククォートや引用符を含みうるので、シェルに埋め込まず一時ファイル（リポジトリ外の一時ディレクトリ）に書き出し、`-F body=@<一時ファイル>`（`gh pr comment`では`--body-file`）で渡す。

**1. 行コメントへの個別の返信:** 未対応として拾ったスレッドには、そのスレッドに直接返信する。本文の1行目は目印`<!-- fix-review:reply -->`にし、直したならそのコミットのSHA、答えるならその回答、見送った・別issueに切り出したならその旨と理由（issueのリンク）、分割で別のPRへ移ったなら「該当コードは PR #<番号> に移った」を書く:

```bash
gh api graphql -F threadId=<スレッドのid> -F body=@<一時ファイル> -f query='
mutation($threadId:ID!,$body:String!){
  addPullRequestReviewThreadReply(input:{pullRequestReviewThreadId:$threadId,body:$body}){comment{url}}
}'
```

応答の`comment.url`を控えておく（対応報告から返信へリンクするため）。

**2. 対応済みの印を付ける:** 拾った指摘・質問すべてに印を付ける — 直したものだけでなく、答えたもの・見送ったもの・別issueに切り出したもの・分割したもの・分割済みだったもの・分割で別のPRへ移ったものも。Step 4で全件の扱いを決めているので、ここで印を付けられないものは無い。スレッドはresolveし、PR全体へのコメントとレビュー本文は「解決済み」として非表示にする:

```bash
gh api graphql -F threadId=<スレッドのid> -f query='
mutation($threadId:ID!){resolveReviewThread(input:{threadId:$threadId}){thread{isResolved}}}'
gh api graphql -F id=<コメントまたはレビューのid> -f query='
mutation($id:ID!){minimizeComment(input:{subjectId:$id,classifier:RESOLVED}){minimizedComment{isMinimized}}}'
```

指摘として拾わなかったコメント（お礼など）には印を付けない。

**3. 対応報告:** 最後に、今回の対応全体をまとめたコメントをPRに投稿する。本文の1行目は目印`<!-- fix-review -->`にする。Step 7で再レビューを頼む場合（今回分割した、またはCritical・Importantを直した回で、かつ再レビューの回数が2回未満のとき）は、2行目を`<!-- fix-review:rereview -->`にする。見出しは次のとおりで、該当するものが無い見出しは省く:

- `## レビュー対応（<n>回目）` — `<n>`はStep 2で数えた対応の回数 + 1
- `### 直したもの` — 指摘ごとに、場所・直した内容・コミットのSHA
- `### 見送ったもの` — 指摘ごとに、理由
- `### 別issueに切り出したもの` — 指摘ごとに、issueのリンク
- `### 分割したもの` — 「PRを分割する」の指摘への返答。分割した新しいPRの番号とリンクを並べる。再レビューの回数が2回未満ならこのPRを`review-pr`で再レビューする旨を、2回に達していればまだ再レビューを通っていない旨を添える。レビュー結果はPR全体へのコメントで、スレッドへの返信ができないため、ここで返す
- `### 分割済みだったもの` — 「分割済み」とした「PRを分割する」の指摘。上に積んだPRの番号とリンクを並べる。再レビューの一文は付けない
- `### 分割で別のPRへ移ったもの` — 指摘ごとに、移った先のPRのリンク
- `### 質問への回答` — PR全体へのコメントやレビュー本文に書かれた質問への回答。行コメントの質問はスレッドで答えたので、ここには1で控えた返信のURLだけを並べる

```bash
gh pr comment <N> --body-file <一時ファイル>
```

## Step 7: 次に進む

今回このPRにpushし（Step 3のrebaseを含む）、このPRの上にstackで積んだPR（このPRのheadブランチをbaseにする、開いているPR）があれば、先に上のPRをrebaseする — 下のPRにpushすると、上のPRをrebaseするまでstackをマージできないため（出典: https://docs.github.com/en/pull-requests/reference/stacked-pull-requests ）。`--no-trunk`を付けて、このPR自体をtrunkの上に積み直さないようにする（`--no-trunk`はfetchもしないので、先にfetchする）。分割した直後は手元にstackの情報が無いので、`gh stack checkout`で取ってくる:

```bash
git fetch origin
gh stack checkout <N>
（stackの各ブランチをoriginに揃える）
gh stack rebase --upstack --no-trunk
gh stack push
```

checkoutの後、rebaseの前に、Step 3の「stackの各ブランチをoriginに揃える」と同じ手順で、上のPRのブランチ（今いるブランチより上で、`isMerged`が`false`のもの）をoriginに揃える。揃えられなかったら、そこでやめる。rebaseがコンフリクトした、または別のworktreeの変更などで止まった場合は、`gh stack rebase --abort`で元に戻す。`gh stack checkout`が失敗した、または入力を求めた場合も、そこでやめる。pushが失敗した場合も含め、上のPRのrebaseが済んでいないことをユーザーに伝え、rebaseは人に任せる。rebaseとpushのあと、`git branch --show-current`が`headRefName`と違えば、`git switch <headRefName>`で戻す。この後の再レビューやreadyへの切り替えは、そのまま進める。

今回直したものに、Critical・Importantの指摘が含まれるかで分ける。「PRを分割する」の指摘を分割したときは、Importantを直したものとして扱う — 分割した後の差分が上限内に収まったかを、`review-pr`に測り直させるため。重さの付いていない指摘（人のコメントなど）はMinorとして扱う。

- **Critical・Importantを直した場合:** 直した結果を確かめるため、再レビューする。
  - Step 2で数えた再レビューの回数が2回未満なら、`development:review-pr`をPR番号`<N>`で呼び出す。
  - 2回に達していれば（Step 4でユーザーが3回目の修正を選んだ場合）、再レビューせずに停止する。対応報告のURLと、まだ再レビューを通っていない旨を伝える。
- **Minorだけを直した、または直したものが無い場合:** 再レビューはしない。PRがDraftなら、ready for reviewに切り替える:

```bash
gh pr view <N> --json isDraft -q .isDraft
gh pr ready <N>
```

  すでにDraftでなければ切り替えは不要。直していないCritical・Importantが残っていてもreadyにする — 残っているのは、見送る・別issueに切り出す・3回目を直さないのいずれかをStep 4でユーザーが決めたもの、または分割で別のPRへ移ったものだけだから。最後に、対応報告のURLをユーザーに伝える。