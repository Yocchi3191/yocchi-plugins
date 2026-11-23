# 独自観点レビュアーへの入力の用意（PRレビュー用）

`--fix` が作業ツリーを書き換える前（独自観点レビュアーの起動前）に行う。

## 差分の大きさ（PR品質の観点）

PRの品質基準は、プラグインのルートの `review-rules.md` に従う。

1. BASE_SHAとHEAD_SHAを決める。

```bash
gh pr view <PR番号> --json baseRefName
git fetch origin <baseRefName>
git merge-base origin/<baseRefName> HEAD   # BASE_SHA
git rev-parse HEAD                         # HEAD_SHA
```

2. 数えないテストのファイルを決める。

```bash
git -c core.quotepath=false diff --name-status -M <BASE_SHA>..<HEAD_SHA>
```

- `core.quotepath=false` を付ける（日本語のパスが引用符つきになり、除外が効かなくなるため）。
- リネーム（`R` で始まる行）をテストとして数えないときは、新旧両方のパスを渡す。

3. 測る。プラグインのルート（`skills/` の1つ上）の `scripts/diff-size.sh` を使う。パスは引用符で囲む。

```bash
bash "<プラグインのルート>/scripts/diff-size.sh" <BASE_SHA> <HEAD_SHA> [<数えないテストのファイル>...]
```

出力は `lines=<行数> chars=<文字数>`。合計値は参考値で、最終判断はレビュアーが行う（`review-rules.md`）。

測れなかったら、その旨を添えて続行する。目安を超えていても停止しない。

## レビュアーに渡すもの

PR番号、`review-rules.md` のパス、差分の大きさ（行数・文字数・目安超過か。数えなかったテストがあれば、その件数も）。差分は、レビュアーがPR番号から読む。
