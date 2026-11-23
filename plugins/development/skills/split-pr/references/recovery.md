# 失敗時の戻し方と、stackの途中のPR

## すでにstackの途中のPRの場合（Step 2）

分割してできたBがさらに目安を超えた場合などである。上下のPRをたどる。

```bash
gh pr list --base <headRefName> --state open --json number,headRefName   # 上のPR
gh pr list --head <baseRefName> --state open --json number,baseRefName   # 下のPR
```

下のPRがあれば、その `baseRefName` で同じように下へたどり、無くなるまで繰り返す（一番下のPRの `baseRefName` がstackのtrunk）。上のPRも同様に上へたどる。どれかで2件以上返ったら、stackが枝分かれしているので、停止して伝える。

分割後は A ← B1 ← B2 ← C の形にする（B1 = 分割した後のB）。次の2つは別々に判定する。

- **下のPRがあるか:** あれば、このPRはBで、本文はB・C…の形に書き直す。無ければ、このPRがAで、本文は全体の説明として残す
- **上のPRがあるか:** あれば、Cのbaseを、このPRから作った一番上の新しいブランチに付け替え、stack全体をlinkし直す。Cのコミットは分割前のBの上に積まれているので、Cをrebaseする必要はない

上のPRがある場合、`gh stack link` の前に付け替える。`--base` にはstackのtrunkを渡す。

```bash
gh pr edit <上のPRの番号> --base <一番上の新しいブランチ>
gh stack link --base <trunk> <下のPRたち> <N> <新しいブランチたち> <上のPRたち>
```

## Step 4でpushが失敗したら

Step 5へ進まず停止して伝える。Aはまだ書き換えていないことと、作ったブランチの消し方（originにあるものは `git push origin --delete <ブランチ>`、手元は `git branch -D <ブランチ>`）を添える。一部だけ残ると、呼び直したときに「同じ名前のブランチがある」で止まるため。

## Step 5でpushが失敗した・止められたら

停止して伝える。B・C…はpush済みでPRは無い。Aは手元だけ戻してあり、originは元のまま。

- 続けるなら、ユーザーが上の `git push` を実行した後に「続けて」と伝えれば、この回のStep 6から進める（最初から呼び直すと、Step 2で手元とPRのheadが一致せず止まる）
- やめるなら、`git reset --hard <headRefOid>` で手元を戻し、B・C…のブランチを削除する

## Step 6で `gh stack link` が失敗したら

同じコマンドを2回までリトライし、駄目なら停止して伝える。このときAはforce push済みで、上のコミットはPRの無いブランチにしか無い。

- 伝えること: AのPRからB・C…の分の変更が消えていること。B・C…はpush済みでPRは無い（一部だけ作られていれば、その番号）
- 続けるなら、失敗の原因（`gh stack` のエラー出力）を解決した後に「続けて」と伝えれば、この回のStep 6から進める
- やめるなら、`git reset --hard <headRefOid>` で手元を戻し、`git push --force-with-lease=<headRefName>:<Aの区切りの終わりのコミット> origin <headRefName>` でAを元に戻す。上のPRのbaseを付け替えていれば `gh pr edit <上のPRの番号> --base <headRefName>` で戻す。stackが作られていれば `gh stack unstack <stackの番号>` で解除し（PRは閉じられない）、作られたPRは閉じ、B・C…のブランチを削除する
