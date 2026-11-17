# review-pr 細則

## Step 2: 差分の範囲

```bash
gh pr view <N> --json baseRefName,headRefName,title,body
git fetch origin <baseRefName> <headRefName>
git merge-base origin/<baseRefName> origin/<headRefName>   # BASE_SHA
git rev-parse origin/<headRefName>                         # HEAD_SHA
```

headブランチが `origin` にあることが前提。フォーク由来のPRは対象外。

## Step 3: 要件

issue参照は `/(?:Closes|Part of) #(\d+)/i` で探す。両方あれば `Closes` を優先する。`gh issue view <N> --json body -q .body` で本文を取り、失敗したら（削除済み、非公開など）PR自身のタイトルと本文にフォールバックし、最終報告にその旨を書く。参照が無いPRは正常で、他の方法でissueを探しに行かない。

PR本文に `## 分割` の節があり「このPRで対応しているREQ:」の行があれば、`split-pr` で分割したstackの1つである。issue本文に加えて `## 分割` の節を要件に添え、「このPRの要件は、この行のREQだけ。ほかのREQはstackのほかのPRで満たす」と書き添える。

