#!/usr/bin/env bash
# 見るべき差分の大きさを測り、PRの上限を超えているかを判定する。
# review（Step 6）と split-pr が同じ測り方を使うための、唯一の定義。
#
# 使い方: diff-size.sh <BASE> <HEAD>
#   <BASE>..<HEAD> の差分を測る。カレントディレクトリはリポジトリ内のどこでもよい。
# 出力: lines=<行数> bytes=<バイト数> over=<yes|no>
#   gitが失敗した場合は、何も出力せず0以外で終わる。
#
# 測り方:
# - 行数: 追加と削除の行の合計。上限は400行。
# - バイト数: 追加と削除の行の中身（先頭の+/-を除く）の合計。上限は32,000バイト（1行80桁 × 400行）。
# - どちらかが上限を超えたら over=yes。
# - .gitattributes で linguist-generated が指定されたファイルは数えない。
#   .gitattributes はチェックアウト中のものが読まれる。
# - リネームしただけのファイルは -M で0行になる。削除したファイルは数に入る。
# - --no-color・--no-ext-diff は省かない。色付けや外部のdiffツールが有効だと、
#   @@ の行を見分けられず、エラーにならないまま0行・0バイトと数えてしまうため。
# - pathspecはリポジトリのルート基準（:/・top）で書く。サブディレクトリで実行しても、
#   リポジトリ全体を数えるため。
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: diff-size.sh <BASE> <HEAD>" >&2
  exit 2
fi

max_lines=400
max_bytes=32000

# 先に差分を取り切る。パイプでつなぐと、gitが失敗してもawkが0行・0バイトを出力してしまうため。
diff="$(git diff --no-color --no-ext-diff -M "$1..$2" -- ':/' ':(top,exclude,attr:linguist-generated)' ':(top,exclude,attr:linguist-generated=true)')"

printf '%s\n' "$diff" \
  | LC_ALL=C awk -v ml="$max_lines" -v mb="$max_bytes" '
      /^diff --git /{h=0}
      /^@@/{h=1; next}
      h && /^[-+]/{n++; b+=length($0)-1}
      END{printf "lines=%d bytes=%d over=%s\n", n, b, (n>ml || b>mb) ? "yes" : "no"}'
