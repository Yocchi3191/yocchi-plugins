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

## Step 5: 結果の反映

**分割の指摘**（差分が上限を超えたとき。`<規約の…>` は、プラグインルートの `review-rules.md` の「PRの大きさの上限」から埋める。重さはImportant固定。`fix-review` はCritical・Importantを直したときだけ再レビューを頼むので、分割後に上限内かを測り直させるため）:

```
**Important** PRを分割する
- 場所: PR全体
- 何が問題か: 見るべき差分が上限を超えている（<行数>行・<バイト数>バイト。上限は<規約の行数>行・<規約のバイト数>バイト。`linguist-generated`のファイルと、`review`がテストとして数えなかったファイルは数えていない）
- なぜ問題か: <規約の「根拠」を1〜2文に要約。出典URLを添える>
- 修正案: 単体で動く単位か、レビューしやすい単位で分ける。全体を同時にマージしないと動かないならstacked PRに分けてまとめてマージする。分け方に設計判断が要る場合や、分けると動かなくなる場合は、ユーザーが判断する
```

**コメントの中身:** `review` が報告した Strengths / Issues / Assessment（分割の指摘を足したもの）と、差分の大きさの1行。`review` が「数えなかったテスト」の行を添えていればその行も載せる。テストかどうか判断できなかったファイルが並ぶ行は、PR上でユーザーが答えられるようそのまま載せる。`review` が添える「このままPRにすると分割を求めます」という警告文は、PRが既にあるので載せない。

**測れなかった場合:** 大きさの1行の代わりに、その旨をコメントに載せる。

```bash
gh pr comment <N> --body "$(cat <<'EOF'
<レビュー結果>
EOF
)"
```
