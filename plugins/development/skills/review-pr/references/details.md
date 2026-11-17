# review-pr 細則

## Step 2: 差分の範囲

```bash
gh pr view <N> --json baseRefName,headRefName,title,body
git fetch origin <baseRefName> <headRefName>
git merge-base origin/<baseRefName> origin/<headRefName>   # BASE_SHA
git rev-parse origin/<headRefName>                         # HEAD_SHA
```

headブランチが `origin` にあることが前提。フォーク由来のPRは対象外。

